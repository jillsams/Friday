# Friday Voice Helper

A small hackathon demo: tap a microphone, ask a question out loud, and Friday answers on screen **and** out loud.

You do **not** need API keys to try it. With no keys it still runs end to end:

1. You type (or speak) a question.
2. The server returns a clearly labelled **demo answer**.
3. The browser reads that answer with built-in speech.

Add keys later for a real Grok reply and ElevenLabs voice.

```bash
npm install
npm start
```

Then open [http://localhost:3000](http://localhost:3000) in **Chrome** (speech-to-text works there). Other browsers can still use the text box.

---

## What each file does

| File | Purpose |
| --- | --- |
| `package.json` | Project name and dependencies (`express`, `dotenv`). `npm start` runs `node server.js`. |
| `server.js` | Tiny Node/Express server. Serves the web page and exposes `/api/ask` and `/api/speak`. |
| `config.js` | **The system prompt.** Edit this one file on demo day to match the problem statement. |
| `.env.example` | Template for API keys and optional settings. Copy it to `.env`. |
| `.env` | Your real keys. Never commit this (it is in `.gitignore`). |
| `.gitignore` | Keeps `.env` and `node_modules/` out of git. |
| `public/index.html` | The single page: title, status line, mic button, transcript, text box. |
| `public/styles.css` | Layout and the listening animation. |
| `public/app.js` | Browser logic: speech-to-text, calling the APIs, speaking the answer. |
| `Friday/` + `Friday.xcodeproj/` | Original Xcode stub from the first commit. Not used by the web or iOS demos. |
| `ios/FridayVoice.xcodeproj` | Native iOS app (SwiftUI). Open this one for the iPhone/iPad demo. |
| `ios/FridayVoice/SystemPrompt.swift` | **iOS system prompt** — same idea as `config.js`. |

---

## How to run locally

1. **Install Node.js 18+** if you don't have it: [https://nodejs.org](https://nodejs.org).
2. Open a terminal in this folder (the one that contains `package.json`).
3. Install dependencies and start the server:

   ```bash
   npm install
   npm start
   ```

4. Visit [http://localhost:3000](http://localhost:3000).
5. Type a question in the box and press **Ask**. You should see a `[DEMO MODE]` answer and hear the browser speak it.
6. In Chrome, click the gold mic, allow the microphone, and ask out loud.

Stop the server with `Ctrl+C`.

### Optional: add API keys

```bash
cp .env.example .env
```

Open `.env` in any editor, paste your keys, save, then stop and `npm start` again.

---

## How to get the two API keys

Both are optional. The app labels what is missing.

### xAI (SpaceXAI) — for the answer

1. Create an account at [https://console.x.ai](https://console.x.ai).
2. Create an API key.
3. Put it in `.env` as `XAI_API_KEY=...`
4. The model name defaults to `grok-4.7`. If the docs list a newer chat model, set `XAI_MODEL` in `.env` (no code change needed).

If this key is missing, `/api/ask` still returns a **demo answer** that starts with `[DEMO MODE]`.

### ElevenLabs — for a nicer spoken voice

1. Create an account at [https://elevenlabs.io](https://elevenlabs.io) (the free plan is enough).
2. Open **Settings → API keys** and create a key.
3. Put it in `.env` as `ELEVENLABS_API_KEY=...`
4. Restart `npm start`. The header badge should **disappear** once both keys are loaded (it reads `/api/status`, not a hardcoded label).

The default model is **`eleven_flash_v2_5`** (the model ElevenLabs documents for free-plan API calls). The default voice is **Eldrin** (`6WwXjDDEMyNmFG95zycZ`), a premade voice for current accounts.

#### How to pick a different voice id

1. Sign in at [https://elevenlabs.io](https://elevenlabs.io).
2. Open **My Voices** (Voices in the sidebar).
3. Find a **premade** voice that is already in your account. Do **not** pick a Voice Library / community voice on the free plan — those are blocked on the API.
4. Click the **three dots** next to the voice → **Copy voice ID**.
5. Paste it in `.env`:

   ```
   ELEVENLABS_VOICE_ID=the_id_you_copied
   ```

6. Restart the server.

You can also change the model with `ELEVENLABS_MODEL_ID` (for example `eleven_multilingual_v2`). Stick with `eleven_flash_v2_5` unless you have a reason to switch.

**Do not use the old "George" id** `JBFqnCBsd6RMkjVDRZzb` unless your ElevenLabs account was created **before March 2026**. Those legacy Default voices are hidden from newer accounts and the API returns an error — Friday then falls back to the browser voice.

If this key is missing **or** the request fails, the page falls back to the browser's `speechSynthesis` voice and shows a small note. The **server terminal** prints `[ElevenLabs] HTTP …` plus the error body (never the key).

---

## How to change the system prompt

Open **`config.js`**. The prompt is the string named `SYSTEM_PROMPT` at the top, with a big comment around it.

Change that text to fit the hackathon problem, for example:

```js
const SYSTEM_PROMPT = `You are Friday, helping judges try a campus-events app.
Answer in 2–4 short sentences. Stay on that product.`;
```

Restart the server (`Ctrl+C`, then `npm start`) so the new prompt is loaded.

The prompt is **not** in the HTML. Keeping it in `config.js` means you can retune Friday without touching the UI.

Every Grok request also gets **today's date and time in Europe/London** appended automatically (see `buildSystemPrompt()` in `config.js`). You do not type the date yourself. That is why "what day is it today?" works.

---

## How the flow works (3-minute demo)

Walk through this list out loud:

1. **Mic** — the user clicks the gold button. The status line says **Listening** and the button pulses.
2. **Speech → text** — Chrome's Web Speech API (`SpeechRecognition`) turns the question into text. If the browser can't do that, a banner says so and the text box is the fallback.
3. **Ask the helper** — the page `POST`s `{ question }` to `/api/ask` on our Express server. Status: **Thinking**.
4. **Grok (or demo)** — the server sends the system prompt from `config.js` plus the question to `https://api.x.ai/v1/chat/completions`. No key? It returns a labelled demo answer instead. The answer appears as a chat bubble.
5. **Speak** — the page `POST`s the answer to `/api/speak`. The server calls ElevenLabs and returns audio. No key or a failed call? The browser reads the text with `speechSynthesis`. Status: **Speaking**.

That's the whole product: one page, one server, two optional APIs, and fallbacks so the demo never goes silent.

---

## Troubleshooting

| What you see | What to try |
| --- | --- |
| Mic does nothing / banner about speech-to-text | Use Chrome, or type in the box. Firefox and Safari often don't support `SpeechRecognition`. |
| Mic error / "Mic blocked" | Click the padlock in the address bar and allow the microphone. |
| Always `[DEMO MODE]` answers | Add `XAI_API_KEY` to `.env` and restart. |
| Header still says "Demo mode — no API keys" with keys set | Restart the server after saving `.env`. Hard-refresh the page. The badge is filled from `GET /api/status`. |
| Grok answers, but the voice is still the browser | Look at the **terminal running `npm start`**. `[ElevenLabs] HTTP 404` usually means the voice id is not in your account (legacy George, or a Voice Library voice on the free plan). Copy a premade id from My Voices. |
| Small note: "using the browser voice" | Expected when ElevenLabs is missing or failed. The note is not a crash — the demo keeps talking. |
| Port already in use | Set `PORT=3001` in `.env` and restart. |
| Changed `config.js` but answers feel the same | Restart `npm start`. Node only reads that file at boot. |
| "What day is it?" is wrong | The London clock is injected in `config.js` on each request. Restart if you changed that helper. |

---

## iOS app (`ios/`)

A standalone SwiftUI app that does the same flow on device, calling xAI and ElevenLabs **directly** (no Node server). The web app is unchanged.

### Open in Xcode

1. On a Mac, open **`ios/FridayVoice.xcodeproj`** (double-click it, or File → Open in Xcode).
2. Wait for Xcode to index. You should see the **FridayVoice** scheme in the toolbar.
3. Pick a simulator (iPhone 15 / 16, iOS 17+) or a plugged-in iPhone.
4. Press **Run** (▶) or `Cmd+R`.

The app runs with **no keys**: type a question, get a `[DEMO MODE]` answer, and hear it with `AVSpeechSynthesizer`.

### Add API keys

```bash
cd ios/FridayVoice
cp Secrets.example.xcconfig Secrets.xcconfig
```

Open `Secrets.xcconfig` and paste `XAI_API_KEY` and `ELEVENLABS_API_KEY`. Leave a key blank to keep that fallback.

`Secrets.xcconfig` is gitignored. Xcode reads it through `Config.xcconfig` and writes the values into Info.plist at **build** time — rebuild (`Cmd+R`) after you edit keys.

Optional in the same file:

- `XAI_MODEL` (default `grok-4.7`)
- `ELEVENLABS_VOICE_ID` (default Eldrin `6WwXjDDEMyNmFG95zycZ`, a premade voice on the free plan)
- `ELEVENLABS_MODEL_ID` (default `eleven_flash_v2_5`)

To pick another ElevenLabs voice: My Voices → three dots → **Copy voice ID**. Voice Library voices are not available on the free-plan API.

### How to change the iOS system prompt

Edit **`ios/FridayVoice/SystemPrompt.swift`**. The string `SystemPrompt.text` is the prompt. Rebuild. Today's Europe/London date is appended automatically in `build()`.

### What each iOS file does

| File | Purpose |
| --- | --- |
| `FridayVoiceApp.swift` | App entry (`@main`). |
| `ContentView.swift` | The single screen (mic, transcript, text field). |
| `FridayViewModel.swift` | Wires mic → Grok → spoken answer. |
| `SystemPrompt.swift` | **Edit this on demo day.** |
| `Secrets.swift` | Reads keys from Info.plist (never logs them). |
| `SpeechRecognizer.swift` | `SFSpeechRecognizer` + `AVAudioEngine`, locale `en-GB`. |
| `ChatService.swift` | xAI `https://api.x.ai/v1/chat/completions`. |
| `VoiceService.swift` | ElevenLabs mp3 via `AVAudioPlayer`, or `AVSpeechSynthesizer`. |
| `Config.xcconfig` | Defaults + optional include of `Secrets.xcconfig`. |
| `Secrets.example.xcconfig` | Template to copy. |
| `Info.plist` | Mic and speech-recognition usage strings, plus `$(XAI_API_KEY)` placeholders. |

### Notes

- **Microphone in the Simulator** uses your Mac's mic. Allow it when macOS/Simulator asks. On-device recognition is not always available in Simulator; the app then uses Apple's speech servers. A real iPhone can stay on-device.
- The first mic tap shows two system prompts: **Speech Recognition** and **Microphone**. Both must be Allow.
- If ElevenLabs fails, a small note appears and the device voice speaks. Check the Xcode console for `[ElevenLabs] HTTP …` (the key is never printed).
- Signing: the project uses Automatic signing and team `8882DX3GU4` (same as the original stub). If Xcode asks you to select a team, pick yours in the target's **Signing & Capabilities** tab.
- No CocoaPods or Swift Package Manager — only Apple frameworks (`SwiftUI`, `Speech`, `AVFoundation`).
