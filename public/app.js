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

// Chrome uses webkitSpeechRecognition; some browsers use the standard name.
const SpeechRecognition =
  window.SpeechRecognition || window.webkitSpeechRecognition;

let recognition = null;
let listening = false;
let busy = false;
let currentAudio = null;

showApiMode();
setupSpeech();

micButton.addEventListener("click", toggleListen);
askForm.addEventListener("submit", (event) => {
  event.preventDefault();
  const question = questionInput.value.trim();
  if (!question || busy) return;
  questionInput.value = "";
  handleQuestion(question);
});

/** Ask the server which keys are present so we can label demo mode. */
async function showApiMode() {
  try {
    const res = await fetch("/api/status");
    const data = await res.json();
    if (!data.xai || !data.elevenlabs) {
      modeBadge.hidden = false;
      const parts = [];
      if (!data.xai) parts.push("demo answers");
      if (!data.elevenlabs) parts.push("browser voice");
      modeBadge.textContent = `Demo mode — ${parts.join(" · ")}`;
    }
  } catch {
    // Status is optional; the rest of the app still works.
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
      currentAudio = new Audio(url);
      currentAudio.onended = () => {
        URL.revokeObjectURL(url);
        setStatus("ready", "Ready");
      };
      currentAudio.onerror = () => {
        URL.revokeObjectURL(url);
        speakWithBrowser(text);
      };
      await currentAudio.play();
      return;
    }
  } catch {
    // Network blip — browser voice still works.
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

function stopSpeaking() {
  if (currentAudio) {
    currentAudio.pause();
    currentAudio = null;
  }
  if (window.speechSynthesis) {
    window.speechSynthesis.cancel();
  }
}

function setStatus(state, label) {
  statusEl.dataset.state = state;
  statusText.textContent = label;
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
