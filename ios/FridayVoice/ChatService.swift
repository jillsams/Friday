import Foundation

/// Talks to the xAI (SpaceXAI) chat completions API.
/// If `XAI_API_KEY` is missing, returns a labelled demo answer instead.
struct ChatService {
    struct Answer {
        let text: String
        let isDemo: Bool
    }

    /// `webResults` nil = Grok alone (Live search off, or Tavily unavailable).
    /// Non-nil = answer only from those hits; today's London date is in the system prompt.
    func ask(_ question: String, webResults: [TavilyService.Hit]? = nil) async throws -> Answer {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Answer(text: "Please ask a question.", isDemo: false)
        }

        guard Secrets.hasXAIKey else {
            return Answer(
                text: """
                [DEMO MODE] I don't have an XAI_API_KEY yet, so this is a sample answer. \
                You asked: "\(trimmed)". Copy Secrets.example.xcconfig to Secrets.xcconfig, \
                add your xAI key, and rebuild for a real Grok reply.
                """,
                isDemo: true
            )
        }

        var request = URLRequest(url: URL(string: "https://api.x.ai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.xaiAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let system: String
        let user: String
        if let hits = webResults {
            system = SystemPrompt.buildLiveSearch()
            user = Self.userMessage(question: trimmed, hits: hits)
        } else {
            system = SystemPrompt.build()
            user = trimmed
        }

        let body: [String: Any] = [
            "model": Secrets.xaiModel,
            "max_tokens": 300,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]

        try Task.checkCancellation()
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                let detail = String(data: data, encoding: .utf8) ?? ""
                print("xAI error \(status) \(detail)")
                return Answer(text: "xAI request failed (\(status)). Check XAI_API_KEY and XAI_MODEL.", isDemo: false)
            }

            let decoded = try JSONDecoder().decode(XAIResponse.self, from: data)
            let text = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                return Answer(text: "xAI returned an empty answer.", isDemo: false)
            }
            return Answer(text: text, isDemo: false)
        } catch {
            try Cancel.rethrow(error)
            print("xAI request threw \(error.localizedDescription)")
            return Answer(text: "Could not reach the xAI API. Check your network and try again.", isDemo: false)
        }
    }

    private static func userMessage(question: String, hits: [TavilyService.Hit]) -> String {
        if hits.isEmpty {
            return "Question: \(question)\n\nWeb search results: none."
        }
        let block = hits.enumerated().map { index, hit in
            "[\(index + 1)] \(hit.title)\n\(hit.url.absoluteString)\n\(hit.snippet)"
        }.joined(separator: "\n\n")
        return "Question: \(question)\n\nWeb search results:\n\(block)"
    }
}

private struct XAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}
