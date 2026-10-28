import AVFoundation
import Foundation
import Speech

/// On-device speech-to-text using Apple's Speech framework + the mic.
/// Locale is en-GB to match the rest of the demo.
@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false

    /// Called once Apple marks the utterance as final (a pause in speech).
    var onFinal: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var isAvailable: Bool { recognizer?.isAvailable == true }

    func requestPermissions() async -> Bool {
        let speechOK = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechOK else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        stopListening(sendFinal: false)
        transcript = ""

        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.unavailable
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        // Prefer on-device so audio never leaves the phone. The Simulator
        // often does not support it — fall back to Apple's servers there.
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            throw SpeechError.noMicrophone
        }

        // Capture the request locally — the tap runs off the main thread.
        let liveRequest = request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            liveRequest.append(buffer)
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.task != nil else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.stopListening(sendFinal: true)
                    }
                } else if error != nil {
                    self.stopListening(sendFinal: true)
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
    }

    /// Stop the mic. If `sendFinal` is true and we heard something, fire `onFinal`.
    @discardableResult
    func stopListening(sendFinal: Bool) -> String {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        let runningTask = task
        task = nil
        runningTask?.cancel()
        isListening = false

        if sendFinal, !text.isEmpty {
            onFinal?(text)
        }
        return text
    }
}

enum SpeechError: LocalizedError {
    case unavailable
    case noMicrophone

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Speech recognition is not available. Type your question instead."
        case .noMicrophone:
            return "No microphone format available. On a Simulator, check System Settings → Privacy → Microphone for Simulator."
        }
    }
}
