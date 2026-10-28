import AVFoundation
import Combine
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
    /// `removeTap` throws if nothing is installed — only call it when this is true.
    private var tapInstalled = false

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
        transcript = ""

        guard let recognizer, recognizer.isAvailable else {
            throw SpeechError.unavailable
        }

        // 1. Session first — never touch inputNode until this has succeeded.
        try AppAudioSession.startRecording()

        // 2. Safe to talk to the graph now. Stop any previous run (idempotent).
        stopEngineAndTap()

        var input: AVAudioInputNode?
        var format: AVAudioFormat?
        do {
            try AudioException.run {
                let node = self.audioEngine.inputNode
                input = node
                format = node.outputFormat(forBus: 0)
            }
        } catch {
            AppAudioSession.deactivate()
            throw error
        }
        // Simulator often reports "2 ch, 0 Hz" — installTap then aborts the process.
        guard let input, let format, format.sampleRate > 0, format.channelCount > 0 else {
            AppAudioSession.deactivate()
            throw SpeechError.noMicrophone
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        // Prefer on-device so audio never leaves the phone. The Simulator
        // often does not support it — fall back to Apple's servers there.
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let liveRequest = request
        // 3. Always drop a leftover tap (missing tap is an NSException — ignore),
        //    then install. installTap can also raise; convert that to a Swift error.
        AudioException.runIgnoring {
            input.removeTap(onBus: 0)
        }
        tapInstalled = false

        do {
            try AudioException.run {
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    liveRequest.append(buffer)
                }
            }
            tapInstalled = true
        } catch {
            AudioException.runIgnoring { input.removeTap(onBus: 0) }
            tapInstalled = false
            stopEngineAndTap()
            AppAudioSession.deactivate()
            throw error
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
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
        var startError: Error?
        do {
            try AudioException.run {
                do {
                    try self.audioEngine.start()
                } catch {
                    startError = error
                }
            }
        } catch {
            startError = error
        }
        if let startError {
            stopEngineAndTap()
            AppAudioSession.deactivate()
            throw SpeechError.audioSetup(startError.localizedDescription)
        }
        isListening = true
    }

    /// Stop the mic. Safe to call twice. If `sendFinal` is true and we heard
    /// something, fire `onFinal`.
    @discardableResult
    func stopListening(sendFinal: Bool) -> String {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        stopEngineAndTap()
        isListening = false

        if sendFinal, !text.isEmpty {
            onFinal?(text)
        }
        return text
    }

    /// Tears down the engine/tap without touching `inputNode` unless we installed a tap.
    private func stopEngineAndTap() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if tapInstalled {
            // removeTap raises if there is no tap — swallow that.
            AudioException.runIgnoring {
                self.audioEngine.inputNode.removeTap(onBus: 0)
            }
            tapInstalled = false
        }

        request?.endAudio()
        request = nil
        let runningTask = task
        task = nil
        runningTask?.cancel()
    }
}

enum SpeechError: LocalizedError {
    case unavailable
    case noMicrophone
    case audioSetup(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Speech recognition is not available. Type your question instead."
        case .noMicrophone:
            return "No microphone found. On the Simulator, check Mac mic permission / I/O > Audio Input, or type your question below."
        case .audioSetup(let detail):
            return "Could not start the microphone (\(detail)). Type your question below."
        }
    }
}
