import AVFoundation
import Foundation

/// Speaks an answer: ElevenLabs mp3 first, AVSpeechSynthesizer if that fails.
@MainActor
final class VoiceService: NSObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    struct Result {
        /// Non-nil when we fell back to the built-in device voice.
        let note: String?
    }

    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private var finish: (@Sendable () -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks `text` and returns after playback finishes (or immediately on failure to start).
    /// Throws `CancellationError` if Stop cancelled the work — caller must not treat that as a failure.
    func speak(_ text: String) async throws -> Result {
        stop()
        try Task.checkCancellation()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Result(note: nil)
        }

        if !Secrets.hasElevenLabsKey {
            try await speakOnDevice(text)
            return Result(note: "No ElevenLabs key — using the device voice.")
        }

        do {
            let audio = try await fetchElevenLabs(text)
            try Task.checkCancellation()
            try playMP3(audio)
            await waitUntilFinished()
            try Task.checkCancellation()
            releasePlayer()
            AppAudioSession.deactivate()
            return Result(note: nil)
        } catch {
            do {
                try Cancel.rethrow(error)
            } catch {
                stop()
                AppAudioSession.deactivate()
                throw CancellationError()
            }
            // Never log the API key — status + body only, like the web app.
            print("[ElevenLabs] speak failed: \(error.localizedDescription)")
            try Task.checkCancellation()
            try await speakOnDevice(text)
            return Result(note: "ElevenLabs failed — using the device voice. See the Xcode console for the HTTP status.")
        }
    }

    func stop() {
        releasePlayer()
        synthesizer.stopSpeaking(at: .immediate)
        complete()
    }

    /// Drop the mp3 buffer. `AVAudioPlayer` keeps decoded audio until released.
    private func releasePlayer() {
        player?.stop()
        player?.delegate = nil
        player = nil
    }

    private func fetchElevenLabs(_ text: String) async throws -> Data {
        let voice = Secrets.elevenLabsVoiceID
        let model = Secrets.elevenLabsModelID
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voice)") else {
            throw VoiceError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Secrets.elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text,
            "model_id": model,
            "output_format": "mp3_44100_128",
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        guard status == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "(empty)"
            print("[ElevenLabs] HTTP \(status) \(http?.statusText ?? "")")
            print("[ElevenLabs] voice=\(voice) model=\(model)")
            print("[ElevenLabs] error body: \(body)")
            throw VoiceError.http(status)
        }
        return data
    }

    private func playMP3(_ data: Data) throws {
        try AppAudioSession.startPlayback()
        releasePlayer()

        let player = try AVAudioPlayer(data: data)
        player.delegate = self
        player.prepareToPlay()
        self.player = player
        guard player.play() else {
            releasePlayer()
            throw VoiceError.playFailed
        }
    }

    private func speakOnDevice(_ text: String) async throws {
        try Task.checkCancellation()
        try? AppAudioSession.startPlayback()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
        await waitUntilFinished()
        try Task.checkCancellation()
        releasePlayer()
        AppAudioSession.deactivate()
    }

    private func waitUntilFinished() async {
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                // Body runs synchronously on the caller (main actor) before we suspend.
                MainActor.assumeIsolated {
                    self.finish = { continuation.resume() }
                }
            }
        } onCancel: { [weak self] in
            Task { @MainActor in self?.stop() }
        }
    }

    /// Resume the waiter at most once (stop + delegate can both fire).
    private func complete() {
        let callback = finish
        finish = nil
        callback?()
    }

    // MARK: - Delegates (audio/speech callbacks are not on the main actor)

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.complete() }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[ElevenLabs] AVAudioPlayer decode error: \(error?.localizedDescription ?? "unknown")")
        Task { @MainActor [weak self] in self?.complete() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.complete() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.complete() }
    }
}

private enum VoiceError: LocalizedError {
    case badURL, playFailed, http(Int)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad ElevenLabs URL"
        case .playFailed: return "Could not start audio playback"
        case .http(let code): return "ElevenLabs HTTP \(code)"
        }
    }
}

private extension HTTPURLResponse {
    var statusText: String { HTTPURLResponse.localizedString(forStatusCode: statusCode) }
}
