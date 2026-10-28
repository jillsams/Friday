import Foundation

/// Live web search via Tavily. The user says the town — we never ask for location.
struct TavilyService: Sendable {
    struct Hit: Identifiable, Sendable {
        let id: UUID
        let title: String
        let url: URL
        let snippet: String

        var domain: String {
            url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
        }
    }

    /// `success` even when Tavily returned zero hits (Grok should say the results don't cover it).
    /// `unavailable` means fall back to Grok-only.
    enum Outcome: Sendable {
        case success([Hit])
        case unavailable(String)
    }

    func search(_ query: String) async -> Outcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .unavailable("Nothing to search for.")
        }
        guard Secrets.hasTavilyKey else {
            return .unavailable("No Tavily key — answering without live search.")
        }

        guard let url = URL(string: "https://api.tavily.com/search") else {
            return .unavailable("Live search failed — answering without web results.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.tavilyAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body = SearchBody(
            query: trimmed,
            search_depth: "basic",
            max_results: 5,
            include_answer: false,
            topic: "general"
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                let detail = String(data: data, encoding: .utf8) ?? "(empty)"
                print("[Tavily] HTTP \(status)")
                print("[Tavily] error body: \(detail)")
                return .unavailable("Live search failed — answering without web results.")
            }

            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            let hits = (decoded.results ?? []).compactMap { row -> Hit? in
                guard let href = row.url, let page = URL(string: href) else { return nil }
                let title = (row.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let snippet = (row.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                return Hit(id: UUID(), title: title, url: page, snippet: snippet)
            }
            return .success(hits)
        } catch {
            print("[Tavily] request threw \(error.localizedDescription)")
            return .unavailable("Live search failed — answering without web results.")
        }
    }
}

private struct SearchBody: Encodable {
    let query: String
    let search_depth: String
    let max_results: Int
    let include_answer: Bool
    let topic: String
}

private struct SearchResponse: Decodable {
    struct Result: Decodable {
        let title: String?
        let url: String?
        let content: String?
    }

    let results: [Result]?
}
