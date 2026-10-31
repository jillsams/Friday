# Demo mode badge

The header shows whether Friday is answering without API keys. On a fresh load with both keys absent, the badge reads `Demo mode — no API keys`.

## Sub-features

- `badge-both-missing` shows `Demo mode — no API keys` when xAI and ElevenLabs keys are both absent.
- `badge-partial` is the badge copy when only one key is absent. This launcher does not produce that state.
- `badge-hidden` hides the badge when both keys are present. This launcher does not produce that state.

## How to get to it (user POV)

- Open the Friday page and look under the tagline `Ask out loud. Get a spoken answer.`

## Driving it with verify-friday

Preconditions:

- `verify-friday doctor` reports `"ok": true` and `apiStatus.xai` false and `apiStatus.elevenlabs` false.
- Launch was this skill's launch, which sets both key variables to empty strings.

- **Load the page.** Run `verify-friday browser open`. The returned `page.badge` is `Demo mode — no API keys` and `page.badgeHidden` is false. `page.title` is `Friday Voice Helper` and `page.heading` is `Friday`.
- **Read it again.** Run `verify-friday browser read`. The same badge fields are still set. `page.statusText` is `Ready`.
- **Proof.** Run `verify-friday browser snapshot --aria --path .cursor/skills/verify-friday/artifacts/$FRIDAY_VERIFY_RUN/badge.aria.txt --feature demo-mode-badge --entry "page load"` and `verify-friday browser screenshot --path .cursor/skills/verify-friday/artifacts/$FRIDAY_VERIFY_RUN/badge.png --feature demo-mode-badge --entry "page load"`. The snapshot includes the static text `Demo mode — no API keys` and the heading `Friday`.

## Gotchas

- The badge starts hidden in the HTML and is filled only after `GET /api/status`. `browser open` already waits for the both-missing copy. A read taken before that fetch can look like a hidden badge.
- `applyModeBadge` in `public/app.js` uses `Demo mode — demo answers` when only the xAI key is missing, and `Demo mode — browser voice` when only the ElevenLabs key is missing. Those strings were not shown by this launcher. Do not report them as verified.
- When both keys are present the badge element stays hidden and its text is empty. That state was not reached. Doctor failing `xai: false` means this instance is not the demo-mode badge journey.
- The em dash in `Demo mode — no API keys` is the character in the page, not a hyphen.
