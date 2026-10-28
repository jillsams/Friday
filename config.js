/**
 * ============================================================
 *  FRIDAY VOICE HELPER — SYSTEM PROMPT
 * ============================================================
 *
 *  THIS is the file to edit on demo day.
 *
 *  The system prompt is sent to Grok before every user question.
 *  Swap the text below to match the hackathon problem statement
 *  (for example: "You are a helpful assistant for a bakery
 *  inventory app. Answer only about that product.").
 *
 *  Keep it short. Friday's answers are spoken out loud, so
 *  tell the model to stay concise.
 *
 *  The current Europe/London date and time is appended
 *  automatically in buildSystemPrompt() so "what day is it?"
 *  works. You do not need to type the date here.
 * ============================================================
 */

const SYSTEM_PROMPT = `You are Friday, a friendly and concise voice assistant.
Answer in 2–4 short sentences so the reply is easy to speak aloud.
Be warm, clear, and practical. If you are unsure, say so briefly
and suggest one next step. Do not use markdown or bullet lists.`;

/**
 * Readable clock in Europe/London (handles GMT vs BST).
 * Example: "Wednesday, 28 October 2026, 16:45 GMT"
 */
function londonDateTime() {
  return new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/London",
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
    timeZoneName: "short",
  }).format(new Date());
}

/** Full prompt sent to Grok: your text above + today's London date/time. */
function buildSystemPrompt() {
  return `${SYSTEM_PROMPT}

The current date and time is ${londonDateTime()} (Europe/London). Use this if the user asks what day, date, or time it is.`;
}

module.exports = {
  SYSTEM_PROMPT,
  buildSystemPrompt,
};
