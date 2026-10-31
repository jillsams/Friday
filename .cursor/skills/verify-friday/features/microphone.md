# Microphone

The gold microphone button starts speech-to-text. A granted microphone shows Listening. This headless Chrome exposes the Web Speech API and then denies the microphone, so the observed result is Mic blocked.

## Sub-features

- `mic-arm` shows an enabled button named `Start listening` when the browser has the Web Speech API.
- `mic-blocked` reports a denied microphone as status `Mic blocked` and a Friday bubble telling the user to allow the mic or type.
- `mic-listen` would show status `Listening` after a granted microphone. That grant was not available here.

## How to get to it (user POV)

- Open the Friday page.
- Choose the round button named `Start listening`. The hint under it reads `Tap the mic and speak, or type below`.

## Driving it with verify-friday

Preconditions:

- `verify-friday doctor` reports `"ok": true`.
- `verify-friday browser open` has loaded a fresh page.
- The fresh page's `micDisabled` is false, `micLabel` is `Start listening`, and `unsupportedHidden` is true. If `unsupportedHidden` is false, the browser has no Web Speech API and this journey stops: the button is disabled and the banner tells the user to type. That banner was hidden in Chrome 156 headless.

- **Tap the mic.** Run `verify-friday browser click --role button --name "Start listening" --until-status "Mic blocked"`. `statusText` is `Mic blocked` and `statusState` is `error`. A bubble with `who` `Friday` and `demo` false has text `The browser blocked the microphone. Allow mic access, or type your question below.`
- **Do not call that a successful listen.** `statusText` is not `Listening`. The button does not stay in the listening state. Report `mic-listen` as not verified: this environment has no ALSA capture device, and the page took the `not-allowed` path.

## Gotchas

- `mic-listen` needs a microphone the browser will allow. Headless Chrome on the proof machine produced `Mic blocked` instead. Do not rewrite this journey so that `Mic blocked` counts as listening.
- The page treats a `no-speech` error as a return to Ready with no new bubble. That error was not observed from this click.
- While a question is in flight the button is disabled (`micDisabled` true during `Thinking`). Click after `statusText` is `Ready` or `Speaking`. `speakWithBrowser` returns before the utterance ends, so the button is enabled again during Speaking.
- The unsupported banner's copy, when it is shown, is `This browser doesn't support speech-to-text (Web Speech API). Chrome works best. Use the text box below — the rest of the demo still runs.`
