---
name: verify-friday
description: "Drive the Friday Voice Helper web page (the single Express page at a local port): launch demo mode, type a question, and capture the transcript, status line, and screenshot. Use when proving the Friday web UI, demo mode, or a feature in features/."
---

# Verify Friday

Friday Voice Helper's primary surface is the one web page served by `server.js` (`public/index.html`). A person types a question or taps the microphone, the page posts to `/api/ask`, and the answer is shown in the transcript and spoken. With no API keys the answer is a labelled demo reply and the voice is the browser's `speechSynthesis`.

This skill drives that page. It does not drive the SwiftUI app in `ios/FridayVoice.xcodeproj` or the unused `Friday/` Xcode stub. There is no account, no database, and no on-disk conversation: the transcript lives in the page until reload.

The feature map in `features/` is the maintained list of journeys. Run doctor before driving. Never drive a server this run did not start.

## Launch

From the repo root (the directory that contains `package.json` and `server.js`):

```bash
npm install
export FRIDAY_VERIFY_RUN=proof-ask-typed
export FRIDAY_VERIFY_PORT=4173
.cursor/skills/verify-friday/bin/verify-friday launch
```

`npm install` is required once so `node_modules/express` exists. The helper does not install it. If that directory is missing, launch exits with that instruction.

`FRIDAY_VERIFY_PORT` defaults to `4173` when unset. Use a free port. Launch refuses to start when `lsof` shows something already listening, and it does not kill that process.

Launch runs `node server.js` with `PORT` set to `FRIDAY_VERIFY_PORT` and with `XAI_API_KEY` and `ELEVENLABS_API_KEY` set to empty strings. dotenv will not override those, so a developer's `.env` cannot turn this instance into a live Grok or ElevenLabs call. The instance is demo mode.

There is no data directory, migration, or seed. A fresh page is the empty transcript.

Ready means all of the following, and launch waits for them (up to 10 seconds):

- The server log contains `Friday Voice Helper is running at http://localhost:4173` (the port you set).
- `GET http://127.0.0.1:4173/` returns 200 and the body contains `<title>Friday Voice Helper</title>` and `<h1>Friday</h1>`.
- `GET http://127.0.0.1:4173/app.js` returns 200.
- `GET http://127.0.0.1:4173/api/status` returns JSON with `"xai": false` and `"elevenlabs": false`.

Launch prints JSON with `"ready": true` and `"url": "http://127.0.0.1:4173/"`. Drive that URL, not a server already bound to port 3000.

Two instances can run side by side. The app stores nothing shared. Start a second run with a different `FRIDAY_VERIFY_RUN` and a different `FRIDAY_VERIFY_PORT` (confirmed with two `node server.js` processes on 4173 and 4174). Do not point both runs at one port. Each run's Chrome uses its own user-data directory and debugging port `FRIDAY_VERIFY_PORT + 20000`.

Teardown is `cleanup` below. Launch writes `/tmp/friday-verify/<FRIDAY_VERIFY_RUN>/state.json` as soon as the server pid exists, including when the ready wait later fails, so cleanup can still stop that pid.

## Doctor

Read-only. Run it after launch, and again any time the page looks wrong. It does not start or stop processes.

```bash
.cursor/skills/verify-friday/bin/verify-friday doctor
```

It exits 0 only when every check holds:

- The recorded server pid is alive and `ps` shows `server.js`.
- `lsof -nP -iTCP:<port> -sTCP:LISTEN` lists that pid.
- `GET /` is the Friday Voice Helper page.
- `GET /api/status` still has both `xai` and `elevenlabs` false.
- The server log still contains the ready line.
- If Chrome was started, its pid is alive and `http://127.0.0.1:<port+20000>/json/version` answers. `chrome: "not-started"` is a pass before `browser open`. A recorded Chrome pid that is dead is a failure.

The last process exit code is the result. The JSON field `ok` is true on success. `problems` lists failures. Do not drive a run whose doctor is not ok.

## Drive

Open the page in the run's Chrome, then use accessible names from the live accessibility tree. Do not click by coordinates.

```bash
.cursor/skills/verify-friday/bin/verify-friday browser open
.cursor/skills/verify-friday/bin/verify-friday browser fill --role textbox --name "Type a question" --value "What day is it today?"
.cursor/skills/verify-friday/bin/verify-friday browser click --role button --name "Ask" --until-status Ready
.cursor/skills/verify-friday/bin/verify-friday browser read
```

`browser open` starts headless Chrome if this run does not already have one, loads `http://127.0.0.1:$FRIDAY_VERIFY_PORT/`, and returns only when all of these are true: `document.title` is `Friday Voice Helper`, the heading text is `Friday`, `#status-text` is `Ready`, `#mode-badge` text is `Demo mode — no API keys`, and `#empty-state` text is `Nothing yet. Ask Friday a question to start.`

Stable handles on that page:

- Textbox name `Type a question` (`#question-input`, labelled by `Type a question`).
- Button name `Ask` (the submit button in `#ask-form`).
- Button name `Start listening` (`#mic-button`).
- Heading name `Friday`.
- Document title `Friday Voice Helper`.
- `#status-text` is `Ready`, `Listening`, `Thinking`, `Speaking`, `Mic blocked`, `Mic error`, or `Error`. `#status` `data-state` is the lowercase form (`ready`, `listening`, `thinking`, `speaking`, `error`).
- `#mode-badge`, `#voice-note`, `#empty-state`, and `#transcript .bubble`.

`browser fill` clicks that accessible node, selects the field (Ctrl+A), clears it (Backspace), inserts the value, and exits non-zero if `#question-input` does not then equal `--value`.

`browser click` and `browser press --key Enter` send trusted input events. `--until-status Ready` waits until a new status-log entry (after the click) has text `Ready`. The demo paragraph takes about 15 seconds to speak in headless Chrome; the wait allows 35 seconds. `--until-answer` returns earlier, once a Friday bubble and the voice note are both visible, without waiting for speech to finish. `browser press` only accepts `--key Enter`, which submits `#ask-form` when the textbox is focused. `browser fill` leaves it focused.

`browser read` prints the DOM the user can check: title, heading, badge, status text, voice note, empty-state copy, input value, bubbles (`who`, `text`, `demo`), and the status mutation log. CSS uppercases the status pill, so the accessibility name is `READY` or `SPEAKING` while `statusText` stays `Ready` or `Speaking`. Assert `statusText`.

Follow one file in `features/` for a full journey. A proof of a different entry point does not cover the others.

## Evidence

Write proof files under `.cursor/skills/verify-friday/artifacts/<FRIDAY_VERIFY_RUN>/`. Cleanup never deletes that directory.

For a typed question, capture the action and the settled page, not only the final pixels:

- `browser read` after `browser open` (empty transcript, badge, `Ready`).
- The click or Enter command's JSON. Its `statusLog` must include `Thinking`, then `Speaking`, then `Ready` when you passed `--until-status Ready`.
- `browser read` after the status returns to `Ready`, saved with `--path`.
- An accessibility snapshot and a screenshot that still show the heading `Friday`, the question, the `[DEMO MODE]` answer, and the badge `Demo mode — no API keys`.

```bash
ART=.cursor/skills/verify-friday/artifacts/$FRIDAY_VERIFY_RUN
.cursor/skills/verify-friday/bin/verify-friday browser read --path "$ART/settled.json" --feature ask-typed --entry "Ask button"
.cursor/skills/verify-friday/bin/verify-friday browser snapshot --aria --path "$ART/ask.aria.txt" --feature ask-typed --entry "Ask button"
.cursor/skills/verify-friday/bin/verify-friday browser screenshot --path "$ART/ask.png" --feature ask-typed --entry "Ask button"
```

Snapshot and screenshot require `--feature` and `--entry`. The snapshot's first lines record them. The screenshot writes `ask.png.meta.json` beside the PNG. `captureBeyondViewport` is on, so the PNG includes the form below the transcript.

There is no row or file to re-read. Reloading the page wipes the transcript; do that only when the journey says to open a fresh page, and do it before you need the previous bubbles. The second view is another `browser read` of the same page, plus the snapshot.

Demo mode does not call xAI or ElevenLabs. That boundary is the empty API keys, which doctor re-checks. Do not treat a `[DEMO MODE]` bubble as a Grok answer. The voice note `No ElevenLabs key — using the browser voice.` is the page's own report that `/api/speak` returned the missing-key fallback. Confirm the note on the page; do not stop at the HTTP call.

## Cleanup

Stop only the pids stored for this `FRIDAY_VERIFY_RUN`. Then delete `/tmp/friday-verify/<FRIDAY_VERIFY_RUN>/` (server log, Chrome profile, state). Leave the artifacts directory in place.

```bash
.cursor/skills/verify-friday/bin/verify-friday cleanup
```

Run cleanup after a failed launch or a failed drive too. A second cleanup prints `cleaned: false` when the state file is already gone and still reports the artifacts path when that directory exists.

Confirm the port is free afterwards with `lsof -nP -iTCP:$FRIDAY_VERIFY_PORT -sTCP:LISTEN` (no output). Confirm the evidence files are still on disk.

## Helpers

The only helper is the executable `.cursor/skills/verify-friday/bin/verify-friday` (`node`, no extra packages). Invoke it from the repo root with `FRIDAY_VERIFY_RUN` set:

```bash
.cursor/skills/verify-friday/bin/verify-friday launch
.cursor/skills/verify-friday/bin/verify-friday doctor
.cursor/skills/verify-friday/bin/verify-friday browser open
.cursor/skills/verify-friday/bin/verify-friday browser read [--path <file> --feature <id> --entry <text>]
.cursor/skills/verify-friday/bin/verify-friday browser fill --role <role> --name <name> --value <text>
.cursor/skills/verify-friday/bin/verify-friday browser click --role <role> --name <name> [--until-status <text>] [--until-answer]
.cursor/skills/verify-friday/bin/verify-friday browser press --key Enter [--until-status <text>] [--until-answer]
.cursor/skills/verify-friday/bin/verify-friday browser snapshot --aria --path <file> --feature <id> --entry <text>
.cursor/skills/verify-friday/bin/verify-friday browser screenshot --path <file> --feature <id> --entry <text>
.cursor/skills/verify-friday/bin/verify-friday browser close
.cursor/skills/verify-friday/bin/verify-friday cleanup
```

Chrome is `/usr/bin/google-chrome-stable` when that file exists (this is what the helper printed as `chromeBin` on the proof machine). The helper skips a `google-chrome` shell wrapper that hardcodes `--remote-debugging-port=`, because that wrapper shares one profile and one debugging port across runs. On this machine that wrapper is `/usr/local/bin/google-chrome`.

## Maintenance

When the page or the map drifts, update this skill with `/maintain-verification-skill`.
