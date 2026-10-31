# Empty transcript

Before the first question, the transcript tells the user to ask something. The first real question removes that line. A blank submit leaves it up.

## Sub-features

- `empty-load` shows `Nothing yet. Ask Friday a question to start.` on a fresh page.
- `empty-blank` keeps that line when the user submits whitespace.
- `empty-cleared` removes the line after the first You bubble. There is no control that brings it back except loading the page again.

## How to get to it (user POV)

- Open the Friday page and look at the transcript panel under the microphone.
- Submit an empty question, or ask a real one, and look again.

## Driving it with verify-friday

Preconditions:

- `verify-friday doctor` reports `"ok": true`.
- No earlier turn is on the page. Run `verify-friday browser open` first.

- **Fresh page.** Run `verify-friday browser read`. `emptyState` is `Nothing yet. Ask Friday a question to start.` and `bubbles` is empty. `statusText` is `Ready`.
- **Blank submit.** Run `verify-friday browser fill --role textbox --name "Type a question" --value "   "` and `verify-friday browser click --role button --name "Ask"`. `emptyState` is unchanged, `bubbles` is still empty, and `inputValue` is three spaces.
- **First question removes it.** Run `verify-friday browser fill --role textbox --name "Type a question" --value "What day is it today?"` and `verify-friday browser click --role button --name "Ask" --until-status Ready`. `emptyState` is null. `bubbles` has the You question and the Friday · demo answer.
- **Proof.** On the fresh page, before the real question, run `verify-friday browser screenshot --path .cursor/skills/verify-friday/artifacts/$FRIDAY_VERIFY_RUN/empty.png --feature empty-transcript --entry "page load"` and `verify-friday browser snapshot --aria --path .cursor/skills/verify-friday/artifacts/$FRIDAY_VERIFY_RUN/empty.aria.txt --feature empty-transcript --entry "page load"`. The snapshot includes `Nothing yet. Ask Friday a question to start.`

## Gotchas

- The empty node is removed, not hidden. After the first bubble, `emptyState` is null rather than a hidden string.
- There is no "clear conversation" button. `browser open` is the way back to the empty copy, and it discards the bubbles.
- Submitting spaces is not a question. Do not wait for `Ready` as a new status; the line never leaves Ready.
