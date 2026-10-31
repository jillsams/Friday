# Friday Voice Helper verification map

This directory is the maintained source for verifying the user-facing behavior of the Friday web page. Read this index, then follow one feature file. The helper is `.cursor/skills/verify-friday/bin/verify-friday`.

## Baseline preconditions

- The repo root contains `package.json` (`friday-voice-helper`) and `server.js`. `npm install` has been run so `node_modules/express` exists.
- `FRIDAY_VERIFY_RUN` is set. `FRIDAY_VERIFY_PORT` is `4173` unless that port is taken.
- Launch with `.cursor/skills/verify-friday/bin/verify-friday launch`. That process sets `XAI_API_KEY` and `ELEVENLABS_API_KEY` to empty strings, so the run is demo mode even if a `.env` file exists.
- The page URL is `http://127.0.0.1:$FRIDAY_VERIFY_PORT/`.
- `.cursor/skills/verify-friday/bin/verify-friday doctor` prints `"ok": true` before any drive command.
- Never drive a port this run did not launch. Two runs need two `FRIDAY_VERIFY_RUN` values and two ports.

## Driving conventions

- Start every recipe from `browser open` unless its preconditions say the transcript already has a turn.
- Use `browser fill`, `browser click`, and `browser press` with the accessible names in the feature file. Do not invent selectors.
- `browser press` only supports `--key Enter`.
- Save proof files under `.cursor/skills/verify-friday/artifacts/$FRIDAY_VERIFY_RUN/`. Cleanup does not remove them.
- The transcript is not stored on disk. Reloading loses it.

## Proof and skip reporting

- Capture the command JSON (the action and the status log) and a later `browser read` of the settled page.
- UI proof includes an accessibility snapshot and a screenshot that show the heading `Friday`.
- There is no separate CLI product. The typed question and the Ask button are both on this page.
- Record `--feature` and `--entry` on every snapshot, screenshot, and saved read.
- If a path needs a microphone grant, an xAI key, or an ElevenLabs key, report it as not verified and say which precondition failed. Do not substitute a different path and call this one done.

## Feature entry contract

Each feature file starts with an H1 and one paragraph, then exactly these H2 sections, in order:

1. `Sub-features`
2. `How to get to it (user POV)`
3. `Driving it with verify-friday`
4. `Gotchas`

## Features

- [Ask a typed question](./ask-typed.md) covers the text box, a blank submit, Enter, the Ask button, and the demo answer.
- [Demo mode badge](./demo-mode-badge.md) covers the header badge loaded from `GET /api/status` when both keys are absent.
- [Microphone](./microphone.md) covers the mic button. A granted microphone was not available in the headless proof environment.
- [Spoken answer](./voice-fallback.md) covers the browser-voice note and the status line while the demo answer is spoken.
- [Empty transcript](./empty-transcript.md) covers the first-load empty copy and its removal after a real question.
