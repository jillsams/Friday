import AVFoundation

/// Shared AVAudioSession helpers so recording and playback don't fight.
enum AppAudioSession {
    /// Call this *before* reading `inputNode` or installing a tap.
    static func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers]
        )
        // Hint a real format before activation. Simulator still sometimes
        // reports 0 Hz — start() will refuse to install a tap in that case.
        try? session.setPreferredSampleRate(44_100)
        try session.setActive(true)
    }

    static func startPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
    }

    /// Lets the next mic tap reconfigure the session from scratch.
    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Turns ObjC exceptions from Core Audio into Swift errors.
enum AudioException {
    static func run(_ work: () -> Void) throws {
        var nsError: NSError?
        let ok = FVTry(work, &nsError)
        if !ok {
            throw SpeechError.audioSetup(nsError?.localizedDescription ?? "Audio setup failed.")
        }
    }

    /// For `removeTap` when we are not sure a tap exists.
    static func runIgnoring(_ work: () -> Void) {
        _ = FVTry(work, nil)
    }
}
