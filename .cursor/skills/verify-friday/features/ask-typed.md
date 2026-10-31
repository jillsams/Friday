# Ask a typed question

Typing a question and choosing Ask, or pressing Enter in the box, shows that question as a You bubble and a Friday demo answer, then returns the status line to Ready.

## Sub-features

- `ask-blank` ignores a whitespace-only question and leaves the empty transcript in place.
- `ask-enter` submits the focused textbox with Enter.
- `ask-button` submits the same form with the Ask button.
- `ask-demo` shows a Friday · demo bubble whose text starts with `[DEMO MODE]` and includes the question, and clears the box.

## How to get to it (user POV)

- Open the Friday page.
- Type in the box labelled `Type a question`.
- Press Enter, or choose the `Ask` button.

## Driving it with verify-friday

Preconditions:

- `verify-friday doctor` reports `"ok": true` for this `FRIDAY_VERIFY_RUN`.
- `verify-friday browser open` has loaded a fresh page: badge `Demo mode — no API keys`, status text `Ready`, empty copy `Nothing yet. Ask Friday a question to start.`

- **Reject whitespace.** Type three spaces and choose Ask. Run `verify-friday browser fill --role textbox --name "Type a question" --value "   "` and `verify-friday browser click --role button --name "Ask"`. The command's `inputValue` is three spaces, `bubbles` is empty, `emptyState` is `Nothing yet. Ask Friday a question to start.`, and `statusText` stays `Ready`.
- **Submit with Enter.** Type `Hello from Enter` and press Enter. Run `verify-friday browser fill --role textbox --name "Type a question" --value "Hello from Enter"` and `verify-friday browser press --key Enter --until-status Ready`. `statusLog` includes `Thinking`, then `Speaking`, then `Ready`. The You bubble text is `Hello from Enter`. The Friday bubble `who` is `Friday · demo`, `demo` is true, and `text` is `[DEMO MODE] I don't have an XAI_API_KEY yet, so this is a sample answer. You asked: "Hello from Enter". Copy .env.example to .env, add your xAI key, and restart the server for a real Grok reply.` The input is empty. `statusText` is `Ready`.
- **Submit with Ask.** Type `What day is it today?` and choose Ask. Run `verify-friday browser fill --role textbox --name "Type a question" --value "What day is it today?"` and `verify-friday browser click --role button --name "Ask" --until-status Ready`. The new You bubble is `What day is it today?`. The new Friday · demo bubble text is `[DEMO MODE] I don't have an XAI_API_KEY yet, so this is a sample answer. You asked: "What day is it today?". Copy .env.example to .env, add your xAI key, and restart the server for a real Grok reply.` `statusLog` for this click includes `Thinking`, `Speaking`, and `Ready`. The earlier Enter turn is still in `bubbles`.
- **Proof.** Save the settled page. Run `verify-friday browser read --path .cursor/skills/verify-friday/artifacts/$FRIDAY_VERIFY_RUN/settled.json --feature ask-typed --entry "Ask button"`, `verify-friday browser snapshot --aria --path .cursor/skills/verify-friday/artifacts/$FRIDAY_VERIFY_RUN/ask.aria.txt --feature ask-typed --entry "Ask button"`, and `verify-friday browser screenshot --path .cursor/skills/verify-friday/artifacts/$FRIDAY_VERIFY_RUN/ask.png --feature ask-typed --entry "Ask button"`. The snapshot lists `Friday`, both questions, both `[DEMO MODE]` answers, and `Demo mode — no API keys`. The screenshot shows the heading `Friday`, the demo answer quoting `Hello from Enter`, the You bubble `What day is it today?`, and that question's demo answer. The transcript panel scrolls, so the first You bubble can sit above the visible panel; `settled.json` and the snapshot still include it.

## Gotchas

- A whitespace question never calls the server. The box is not cleared. Assert the three spaces are still there.
- `--until-status Ready` waits out the spoken answer. On the proof machine that demo paragraph kept the status on Speaking for about 15 seconds, then returned to Ready. A short timeout fails while speech is still in progress.
- The accessibility name of the status pill is uppercased by CSS (`READY`, `SPEAKING`). Assert `statusText` from `browser read`.
- The status log can list `Thinking` twice and `Speaking` twice, because the observer sees both the `data-state` attribute and the text node.
- Reloading loses both bubbles. Capture evidence before `browser open` again.
- This launcher never calls Grok. The `[DEMO MODE]` sentence does not contain the London date from `config.js`.
