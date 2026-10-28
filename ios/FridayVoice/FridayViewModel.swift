import Combine
import Foundation

enum AppStatus: String {
    case ready = "Ready"
    case listening = "Listening"
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
}

/// Ties the mic, Grok, and spoken answers together for the single screen.
@MainActor
final class FridayViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var status: AppStatus = .ready
    @Published var draft = ""
    @Published var voiceNote: String?
    @Published var isBusy = false

    let speech = SpeechRecognizer()
    private let chat = ChatService()
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

        let allowed = await speech.requestPermissions()
        guard allowed else {
            status = .error
            messages.append(ChatMessage(
                role: .friday,
                text: "Microphone or speech recognition is blocked. Allow both in Settings, or type your question below."
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
        messages.append(ChatMessage(role: .you, text: question))
        status = .thinking

        let answer = await chat.ask(question)
        messages.append(ChatMessage(role: .friday, text: answer.text, isDemo: answer.isDemo))

        status = .speaking
        let spoken = await voice.speak(answer.text)
        voiceNote = spoken.note
        status = .ready
        isBusy = false
    }
}
