# Spoken answer

After a demo answer is on screen, Friday speaks it with the browser voice and shows `No ElevenLabs key — using the browser voice.` The status line moves through Thinking and Speaking and lands on Ready when the utterance ends.

## Sub-features

- `voice-note` shows the missing-ElevenLabs note after a typed question.
- `voice-status` records Thinking, then Speaking, then Ready on the status line.
- `voice-elevenlabs` would play server audio and leave the note hidden. This launcher has no ElevenLabs key, so that path is not verified.

## How to get to it (user POV)

- Open the Friday page.
- Type a question and choose Ask, or press Enter.
- Watch the status line and the note under it while the answer is read aloud.

## Driving it with verify-friday

Preconditions:

- `verify-friday doctor` reports `apiStatus.elevenlabs` false and `"ok": true`.
- `verify-friday browser open` has loaded a fresh page, so no earlier utterance is still speaking.

- **Ask.** Run `verify-friday browser fill --role textbox --name "Type a question" --value "What day is it today?"` and `verify-friday browser click --role button --name "Ask" --until-status Ready`.
- **Note and status.** The command JSON `statusLog` includes `Thinking`, then `Speaking`, then `Ready`, in that order. When the command returns, `statusText` is `Ready`, `statusState` is `ready`, and `speechSpeaking` is false. `voiceNoteHidden` is false and `voiceNote` is `No ElevenLabs key — using the browser voice.`
- **Answer is the thing that was spoken.** The Friday · demo bubble is the `[DEMO MODE]` sentence that quotes `What day is it today?`. The note stays visible after Ready. It is cleared only when another question starts.
- **Proof.** Run `verify-friday browser read --path .cursor/skills/verify-friday/artifacts/$FRIDAY_VERIFY_RUN/voice.json --feature voice-fallback --entry "Ask button"` and `verify-friday browser screenshot --path .cursor/skills/verify-friday/artifacts/$FRIDAY_VERIFY_RUN/voice.png --feature voice-fallback --entry "Ask button"`. The screenshot shows the note, the status pill, and the demo bubble.

## Gotchas

- `--until-answer` returns while the status is still Speaking. Use `--until-status Ready` when the journey needs the utterance to finish. The proof machine took about 15 seconds for this paragraph.
- `GET` is the wrong check. The note is rendered by the page after `POST /api/speak` returns 503 with `reason` `missing_key`. Assert the note text, not only the HTTP status.
- A live ElevenLabs key would hide the note and play audio in `#tts-player`. Launch sets `ELEVENLABS_API_KEY` to empty, so `voice-elevenlabs` cannot be verified on this instance. Doctor would also fail closed if a key were present.
- The em dash in the note is the character the page sets, not a hyphen.
