import Foundation

// ============================================================
//  FRIDAY VOICE HELPER — SYSTEM PROMPT  (iOS)
// ============================================================
//
//  THIS is the file to edit on demo day.
//
//  The system prompt is sent to Grok before every user question.
//  Swap the text below to match the hackathon problem statement.
//
//  Keep it short. Friday's answers are spoken out loud.
//  Today's Europe/London date and time is appended automatically
//  in buildSystemPrompt() — you do not type the date here.
// ============================================================

enum SystemPrompt {
    static let text = """
    You are Friday, a friendly and concise voice assistant.
    Answer in 2–4 short sentences so the reply is easy to speak aloud.
    Be warm, clear, and practical. If you are unsure, say so briefly
    and suggest one next step. Do not use markdown or bullet lists.
    """

    /// Full prompt sent to Grok: the text above + the London clock.
    static func build() -> String {
        "\(text)\n\nThe current date and time is \(londonDateTime()) (Europe/London). Use this if the user asks what day, date, or time it is."
    }

    /// Prompt when Live search is on and Tavily returned results (or an empty list).
    static func buildLiveSearch() -> String {
        """
        You are Friday, a friendly and concise voice assistant.
        Answer ONLY from the web search results provided with the question.
        Use the current date to interpret phrases like "this weekend", "Saturday", or "this half term".
        Answer in 2–4 short sentences so the reply is easy to speak aloud.
        Do not include URLs, markdown, or bullet lists in the spoken text.
        If the results do not cover the question, say so briefly and suggest one next step.

        The current date and time is \(londonDateTime()) (Europe/London).
        """
    }

    /// Example: "Wednesday, 28 October 2026 at 16:45 GMT"
    private static func londonDateTime() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "EEEE, d MMMM yyyy 'at' HH:mm zzz"
        return formatter.string(from: Date())
    }
}
