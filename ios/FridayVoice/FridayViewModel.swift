import Combine
import Foundation
import SwiftUI

enum AppStatus: String {
    case ready = "Ready"
    case listening = "Listening"
    case searching = "Searching the web…"
    case thinking = "Thinking"
    case speaking = "Speaking"
    case error = "Error"
}

struct ChatMessage: Identifiable {
    enum Role { case you, friday }
    let id = UUID()
    let role: Role
    let text: String
    var isDemo = false
    var sources: [TavilyService.Hit] = []
}

/// Ties the mic, Grok, and spoken answers together for the single screen.
@MainActor
final class FridayViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var status: AppStatus = .ready
    @Published var draft = ""
    @Published var voiceNote: String?
    @Published var searchNote: String?
    @Published var isBusy = false
    /// Default on so the "what's on near me" demo is live until someone toggles it off.
    @AppStorage("liveSearch") var liveSearch = true

    let speech = SpeechRecognizer()
    private let chat = ChatService()
    private let tavily = TavilyService()
    private let voice = VoiceService()
    private var bag = Set<AnyCancellable>()

    var modeBadge: String? { Secrets.modeBadge }

    init() {
        // Nested ObservableObject does not refresh the screen on its own.
        speech.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)

        speech.onFinal = { [weak self] text in
            Task { await self?.handle(question: text) }
        }
    }

    func toggleMic() async {
        if speech.isListening {
            let text = speech.stopListening(sendFinal: false)
            if text.isEmpty {
                AppAudioSession.deactivate()
                status = .ready
            } else {
                await handle(question: text)
            }
            return
        }

        guard !isBusy else { return }

        switch await speech.requestPermissions() {
        case .allowed:
            break
        case .microphoneOff:
            status = .ready
            messages.append(ChatMessage(
                role: .friday,
                text: "Microphone is off for Friday. Turn it on in Settings > Friday."
            ))
            return
        case .speechOff:
            status = .ready
            messages.append(ChatMessage(
                role: .friday,
                text: "Speech Recognition is off for Friday. Turn it on in Settings > Friday."
            ))
            return
        }

        do {
            try speech.start()
            status = .listening
            voiceNote = nil
        } catch {
            // Don't crash; don't stick on Error — the text field must still work.
            speech.stopListening(sendFinal: false)
            AppAudioSession.deactivate()
            status = .ready
            messages.append(ChatMessage(role: .friday, text: error.localizedDescription))
        }
    }

    func submitTyped() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isBusy else { return }
        draft = ""
        await handle(question: text)
    }

    private func handle(question: String) async {
        guard !isBusy else { return }
        isBusy = true
        voiceNote = nil
        searchNote = nil
        messages.append(ChatMessage(role: .you, text: question))

        var webResults: [TavilyService.Hit]?
        if liveSearch {
            status = .searching
            switch await tavily.search(question) {
            case .success(let hits):
                webResults = hits
            case .unavailable(let note):
                searchNote = note
                webResults = nil
            }
        }

        status = .thinking
        let answer = await chat.ask(question, webResults: webResults)
        let sources = Array((webResults ?? []).prefix(3))
        messages.append(ChatMessage(role: .friday, text: answer.text, isDemo: answer.isDemo, sources: sources))

        status = .speaking
        let spoken = await voice.speak(answer.text)
        voiceNote = spoken.note
        status = .ready
        isBusy = false
    }
}
