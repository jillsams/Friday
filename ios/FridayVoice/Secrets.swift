import Foundation

/// Keys and model names from Info.plist, which Xcode fills in from
/// `Secrets.xcconfig` at build time. Never log these values.
enum Secrets {
    static var xaiAPIKey: String { plist("XAI_API_KEY") }
    static var xaiModel: String { plist("XAI_MODEL", fallback: "grok-4.7") }

    static var elevenLabsAPIKey: String { plist("ELEVENLABS_API_KEY") }
    static var elevenLabsVoiceID: String { plist("ELEVENLABS_VOICE_ID", fallback: "EXAVITQu4vr4xnSDxMaL") }
    static var elevenLabsModelID: String { plist("ELEVENLABS_MODEL_ID", fallback: "eleven_flash_v2_5") }

    static var tavilyAPIKey: String { plist("TAVILY_API_KEY") }

    static var hasXAIKey: Bool { !xaiAPIKey.isEmpty }
    static var hasElevenLabsKey: Bool { !elevenLabsAPIKey.isEmpty }
    static var hasTavilyKey: Bool { !tavilyAPIKey.isEmpty }

    /// Header badge. Nil means both keys are present — hide the badge.
    static var modeBadge: String? {
        switch (hasXAIKey, hasElevenLabsKey) {
        case (false, false): return "Demo mode — no API keys"
        case (false, true): return "Demo mode — demo answers"
        case (true, false): return "Demo mode — device voice"
        case (true, true): return nil
        }
    }

    private static func plist(_ key: String, fallback: String = "") -> String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Unset xcconfig values are left as "$(XAI_API_KEY)" in the plist.
        if raw.isEmpty || raw.hasPrefix("$(") { return fallback }
        return raw
    }
}
