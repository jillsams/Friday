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
    /// Recognised question, shown immediately so a mishearing is obvious before the answer.
    @Published var heardQuestion: String?
    @Published var isBusy = false
    /// Default on so the "what's on near me" demo is live until someone toggles it off.
    @AppStorage("liveSearch") var liveSearch = true

    let speech = SpeechRecognizer()
    private let chat = ChatService()
    private let tavily = TavilyService()
    private let voice = VoiceService()
    private var bag = Set<AnyCancellable>()
    private var workTask: Task<Void, Never>?

    var modeBadge: String? { Secrets.modeBadge }

    var canStop: Bool {
        switch status {
        case .searching, .thinking, .speaking: return true
        default: return false
        }
    }

    init() {
        // Nested ObservableObject does not refresh the screen on its own.
        speech.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)

        speech.onFinal = { [weak self] text in
            self?.handle(question: text)
        }
    }

    func toggleMic() async {
        if speech.isListening {
            let text = speech.stopListening(sendFinal: false)
            if text.isEmpty {
                AppAudioSession.deactivate()
                status = .ready
            } else {
                handle(question: text)
            }
            return
        }

        // Processing: tap cancels in-flight work and returns to Ready.
        if status == .searching || status == .thinking {
            stopAnswer()
            return
        }

        // Speaking: tap stops her and starts listening again.
        if status == .speaking {
            haltWork()
            isBusy = false
        } else {
            guard !isBusy else { return }
        }

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
            searchNote = nil
            heardQuestion = nil
        } catch {
            // Don't crash; don't stick on Error — the text field must still work.
            speech.stopListening(sendFinal: false)
            AppAudioSession.deactivate()
            status = .ready
            messages.append(ChatMessage(role: .friday, text: error.localizedDescription))
        }
    }

    func submitTyped() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isBusy else { return }
        draft = ""
        handle(question: text)
    }

    /// Immediate stop: silence playback, cancel in-flight requests, back to Ready.
    func stopAnswer() {
        haltWork()
        isBusy = false
        status = .ready
    }

    private func haltWork() {
        speech.stopListening(sendFinal: false)
        voice.stop()
        AppAudioSession.deactivate()
        workTask?.cancel()
        workTask = nil
    }

    private func handle(question: String) {
        guard !isBusy else { return }
        isBusy = true
        voiceNote = nil
        searchNote = nil
        heardQuestion = question
        messages.append(ChatMessage(role: .you, text: question))

        workTask?.cancel()
        workTask = nil
        workTask = Task { @MainActor [weak self] in
            await self?.runPipeline(question: question)
        }
    }

    private func runPipeline(question: String) async {
        do {
            var webResults: [TavilyService.Hit]?
            if liveSearch {
                status = .searching
                try Task.checkCancellation()
                switch try await tavily.search(question) {
                case .success(let hits):
                    webResults = hits
                case .unavailable(let note):
                    searchNote = note
                    webResults = nil
                }
            }

            try Task.checkCancellation()
            status = .thinking
            let answer = try await chat.ask(question, webResults: webResults)
            try Task.checkCancellation()
            let sources = Array((webResults ?? []).prefix(3))
            messages.append(ChatMessage(role: .friday, text: answer.text, isDemo: answer.isDemo, sources: sources))

            status = .speaking
            let spoken = try await voice.speak(answer.text)
            try Task.checkCancellation()
            voiceNote = spoken.note
            status = .ready
            isBusy = false
            workTask = nil
        } catch {
            let wasCancelled: Bool
            do {
                try Cancel.rethrow(error)
                wasCancelled = false
            } catch {
                wasCancelled = true
            }
            voice.stop()
            AppAudioSession.deactivate()
            isBusy = false
            // Stop / mic-interrupt already niled workTask and may have moved to Listening.
            if workTask != nil {
                workTask = nil
                status = .ready
            }
            if !wasCancelled {
                status = .ready
            }
        }
    }
}
