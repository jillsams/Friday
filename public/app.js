/**
 * Friday Voice Helper — front-end.
 *
 * Flow:
 *   1. Click the mic (or type in the box).
 *   2. Browser speech-to-text (Web Speech API) → question text.
 *   3. POST /api/ask  → Friday's answer (Grok, or a labelled demo reply).
 *   4. Show the answer, then POST /api/speak for ElevenLabs audio.
 *      If that fails, use the browser's speechSynthesis instead.
 */

const statusEl = document.getElementById("status");
const statusText = document.getElementById("status-text");
const micButton = document.getElementById("mic-button");
const micHint = document.getElementById("mic-hint");
const unsupportedEl = document.getElementById("unsupported");
const transcriptEl = document.getElementById("transcript");
const emptyState = document.getElementById("empty-state");
const askForm = document.getElementById("ask-form");
const questionInput = document.getElementById("question-input");
const modeBadge = document.getElementById("mode-badge");
const voiceNote = document.getElementById("voice-note");
const ttsPlayer = document.getElementById("tts-player");

// Chrome uses webkitSpeechRecognition; some browsers use the standard name.
const SpeechRecognition =
  window.SpeechRecognition || window.webkitSpeechRecognition;

let recognition = null;
let listening = false;
let busy = false;

showApiMode();
setupSpeech();

micButton.addEventListener("click", () => {
  unlockAudio();
  toggleListen();
});
askForm.addEventListener("submit", (event) => {
  event.preventDefault();
  unlockAudio();
  const question = questionInput.value.trim();
  if (!question || busy) return;
  questionInput.value = "";
  handleQuestion(question);
});

/**
 * Drive the header badge from GET /api/status — never leave a hardcoded
 * "Demo mode" label on screen when keys are actually present.
 */
async function showApiMode() {
  try {
    const res = await fetch("/api/status");
    const data = await res.json();
    applyModeBadge(data);
  } catch {
    modeBadge.hidden = true;
    modeBadge.textContent = "";
  }
}

function applyModeBadge(data) {
  const parts = [];
  if (!data.xai) parts.push("demo answers");
  if (!data.elevenlabs) parts.push("browser voice");

  if (parts.length === 0) {
    modeBadge.hidden = true;
    modeBadge.textContent = "";
    return;
  }

  modeBadge.hidden = false;
  if (!data.xai && !data.elevenlabs) {
    modeBadge.textContent = "Demo mode — no API keys";
  } else {
    modeBadge.textContent = `Demo mode — ${parts.join(" · ")}`;
  }
}

/** Wire up the mic, or show a clear "not supported" message. */
function setupSpeech() {
  if (!SpeechRecognition) {
    unsupportedEl.hidden = false;
    micButton.disabled = true;
    micHint.textContent = "Speech-to-text isn't available here — type below";
    return;
  }

  recognition = new SpeechRecognition();
  recognition.lang = "en-US";
  recognition.interimResults = false;
  recognition.maxAlternatives = 1;

  recognition.onstart = () => {
    listening = true;
    micButton.classList.add("listening");
    setStatus("listening", "Listening");
  };

  recognition.onresult = (event) => {
    const transcript = event.results[0][0].transcript.trim();
    if (transcript) {
      handleQuestion(transcript);
    } else {
      setStatus("ready", "Ready");
    }
  };

  recognition.onerror = (event) => {
    // "no-speech" is common if you tap the mic and stay quiet.
    if (event.error === "no-speech") {
      setStatus("ready", "Ready");
      return;
    }
    if (event.error === "not-allowed") {
      setStatus("error", "Mic blocked");
      addBubble(
        "friday",
        "The browser blocked the microphone. Allow mic access, or type your question below."
      );
      return;
    }
    setStatus("error", "Mic error");
  };

  recognition.onend = () => {
    listening = false;
    micButton.classList.remove("listening");
    if (statusEl.dataset.state === "listening") {
      setStatus("ready", "Ready");
    }
  };
}

function toggleListen() {
  if (!recognition || busy) return;

  if (listening) {
    recognition.stop();
    return;
  }

  try {
    recognition.start();
  } catch {
    // start() throws if it is already running — ignore that.
  }
}

/**
 * Shared path for voice and typed questions:
 * show the question → ask the backend → show + speak the answer.
 */
async function handleQuestion(question) {
  if (busy) return;
  busy = true;
  micButton.disabled = true;
  hideVoiceNote();

  addBubble("you", question);
  setStatus("thinking", "Thinking");

  try {
    const res = await fetch("/api/ask", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ question }),
    });
    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.error || "The helper could not answer.");
    }

    addBubble("friday", data.answer, { demo: Boolean(data.demo) });
    await speak(data.answer);
  } catch (err) {
    setStatus("error", "Error");
    addBubble("friday", err.message || "Something went wrong.");
  } finally {
    busy = false;
    micButton.disabled = !SpeechRecognition;
    if (statusEl.dataset.state === "thinking") {
      setStatus("ready", "Ready");
    }
  }
}

/**
 * Prefer ElevenLabs audio from our backend. If the key is missing,
 * the request fails, or autoplay is blocked, fall back to speechSynthesis.
 */
async function speak(text) {
  stopSpeaking();
  setStatus("speaking", "Speaking");

  try {
    const res = await fetch("/api/speak", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text }),
    });

    if (res.ok) {
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      ttsPlayer.src = url;
      ttsPlayer.onended = () => {
        URL.revokeObjectURL(url);
        setStatus("ready", "Ready");
      };
      ttsPlayer.onerror = () => {
        URL.revokeObjectURL(url);
        showVoiceNote("Could not play ElevenLabs audio — using the browser voice.");
        speakWithBrowser(text);
      };
      try {
        await ttsPlayer.play();
        return;
      } catch (playErr) {
        console.warn("ElevenLabs audio play() was blocked:", playErr);
        URL.revokeObjectURL(url);
        showVoiceNote("Could not play ElevenLabs audio — using the browser voice.");
        speakWithBrowser(text);
        return;
      }
    }

    const info = await res.json().catch(() => ({}));
    if (info.reason === "missing_key") {
      showVoiceNote("No ElevenLabs key — using the browser voice.");
    } else {
      const statusBit = info.httpStatus ? ` (HTTP ${info.httpStatus})` : "";
      showVoiceNote(
        `ElevenLabs failed${statusBit} — using the browser voice. See the server log for details.`
      );
    }
  } catch (err) {
    console.warn("ElevenLabs request failed, using browser voice.", err);
    showVoiceNote("ElevenLabs request failed — using the browser voice.");
  }

  speakWithBrowser(text);
}

/** Built-in browser TTS. Works with no API keys. */
function speakWithBrowser(text) {
  if (!window.speechSynthesis) {
    setStatus("ready", "Ready");
    return;
  }

  window.speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.rate = 1.02;
  utterance.onend = () => setStatus("ready", "Ready");
  utterance.onerror = () => setStatus("ready", "Ready");
  window.speechSynthesis.speak(utterance);
}

/**
 * Call this during a click/submit. Chrome otherwise blocks Audio.play()
 * after the Grok + ElevenLabs fetches, and we would fall back to speechSynthesis
 * even when the mp3 downloaded fine.
 */
function unlockAudio() {
  // Tiny silent wav so the page earns "media engagement" during the click.
  ttsPlayer.src =
    "data:audio/wav;base64,UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA";
  ttsPlayer.muted = true;
  ttsPlayer.play().catch(() => {});
  ttsPlayer.muted = false;
}

function stopSpeaking() {
  ttsPlayer.pause();
  ttsPlayer.removeAttribute("src");
  ttsPlayer.load();
  if (window.speechSynthesis) {
    window.speechSynthesis.cancel();
  }
}

function setStatus(state, label) {
  statusEl.dataset.state = state;
  statusText.textContent = label;
}

function showVoiceNote(message) {
  voiceNote.textContent = message;
  voiceNote.hidden = false;
}

function hideVoiceNote() {
  voiceNote.hidden = true;
  voiceNote.textContent = "";
}

function addBubble(who, text, options = {}) {
  if (emptyState) {
    emptyState.remove();
  }

  const bubble = document.createElement("div");
  bubble.className = `bubble ${who}${options.demo ? " demo" : ""}`;

  const label = document.createElement("span");
  label.className = "who";
  label.textContent = who === "you" ? "You" : options.demo ? "Friday · demo" : "Friday";

  const body = document.createElement("span");
  body.textContent = text;

  bubble.append(label, body);
  transcriptEl.append(bubble);
  transcriptEl.scrollTop = transcriptEl.scrollHeight;
}
