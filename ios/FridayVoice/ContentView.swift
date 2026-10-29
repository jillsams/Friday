import SwiftUI

/// Single screen: title, status, gold mic, chat transcript, typed fallback.
struct ContentView: View {
    @StateObject private var model = FridayViewModel()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Color.fridayBg.ignoresSafeArea()
            VStack(spacing: 14) {
                header
                statusPill
                micButton
                Text(micHint)
                    .font(.subheadline)
                    .foregroundStyle(Color.fridayMuted)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 20)
                belowMic
                transcript
                askRow
                liveSearchToggle
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("VOICE HELPER")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(Color.fridayGold)
            Text("Friday")
                .font(.system(size: 48, weight: .semibold))
                .tracking(-1.5)
                .foregroundStyle(Color.fridayInk)
            Text("Ask out loud. Get a spoken answer.")
                .font(.subheadline)
                .foregroundStyle(Color.fridayMuted)
            if let badge = model.modeBadge {
                Text(badge)
                    .font(.caption)
                    .foregroundStyle(Color.fridayGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(Capsule().stroke(Color.fridayLine, lineWidth: 1))
                    .padding(.top, 8)
            }
        }
    }

    /// Heard question and notes sit *under* the mic so they never shove it around.
    private var belowMic: some View {
        VStack(spacing: 6) {
            if let heard = model.heardQuestion {
                Text("You said: \(heard)")
                    .font(.subheadline)
                    .foregroundStyle(Color.fridayInk)
                    .multilineTextAlignment(.center)
            }
            if let note = model.searchNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Color.fridayMuted)
                    .multilineTextAlignment(.center)
            }
            if let note = model.voiceNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(Color.fridayMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .frame(minHeight: 8)
    }

    private var liveSearchToggle: some View {
        Toggle(isOn: $model.liveSearch) {
            Text("Live search")
                .font(.subheadline)
                .foregroundStyle(Color.fridayInk)
        }
        .tint(Color.fridayGold)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: 220)
        .background(Color.fridayCard)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.fridayLine, lineWidth: 1))
        .accessibilityLabel("Live search")
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(model.status.rawValue.uppercased())
                .font(.system(size: 13, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(Color.fridayInk)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.fridayCard)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.fridayLine, lineWidth: 1))
    }

    private var statusColor: Color {
        switch model.status {
        case .listening: return Color.fridayMicListen
        case .searching, .thinking: return Color.fridayGold
        case .speaking: return Color.fridayMicSpeak
        case .error: return Color.fridayDanger
        case .ready: return Color.fridayMuted
        }
    }

    private var micHint: String {
        if model.speech.isListening {
            return "Listening… tap again when you are done"
        }
        if model.status == .speaking {
            return "Tap the mic to stop"
        }
        if model.canStop {
            return "Tap the mic to cancel"
        }
        return "Tap the mic and speak, or type below"
    }

    private var micButton: some View {
        Button {
            Task { await model.toggleMic() }
        } label: {
            ZStack {
                if model.speech.isListening {
                    PulseRings(color: Color.fridayMicListen)
                }
                Circle()
                    .fill(micFill)
                    .frame(width: 132, height: 132)
                    .shadow(color: micShadow, radius: 16, y: 8)
                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(micIconColor)
            }
            .frame(width: 132, height: 132)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.28), value: model.status)
        .animation(.easeInOut(duration: 0.28), value: model.speech.isListening)
        .accessibilityLabel(micAccessibilityLabel)
        .accessibilityHint(micAccessibilityHint)
    }

    private var micFill: RadialGradient {
        let colors: [Color]
        switch model.status {
        case .listening:
            colors = [
                Color(red: 0.42, green: 0.92, blue: 0.58),
                Color.fridayMicListen,
                Color(red: 0.06, green: 0.38, blue: 0.18),
            ]
        case .searching, .thinking:
            colors = [
                Color(red: 0.78, green: 0.62, blue: 0.98),
                Color.fridayMicProcess,
                Color(red: 0.28, green: 0.12, blue: 0.52),
            ]
        case .speaking:
            colors = [
                Color(red: 1.00, green: 0.52, blue: 0.50),
                Color.fridayMicSpeak,
                Color(red: 0.52, green: 0.08, blue: 0.12),
            ]
        default:
            colors = [
                Color(red: 0.95, green: 0.82, blue: 0.60),
                Color.fridayGold,
                Color.fridayGoldDeep,
            ]
        }
        return RadialGradient(
            colors: colors,
            center: UnitPoint(x: 0.35, y: 0.30),
            startRadius: 4,
            endRadius: 80
        )
    }

    private var micShadow: Color {
        switch model.status {
        case .listening: return Color.fridayMicListen.opacity(0.40)
        case .searching, .thinking: return Color.fridayMicProcess.opacity(0.40)
        case .speaking: return Color.fridayMicSpeak.opacity(0.40)
        default: return Color.fridayGold.opacity(0.28)
        }
    }

    private var micIconColor: Color {
        switch model.status {
        case .listening, .searching, .thinking, .speaking:
            return .white
        default:
            return Color(red: 0.10, green: 0.07, blue: 0.03)
        }
    }

    private var micAccessibilityLabel: String {
        if model.speech.isListening { return "Stop listening and send" }
        switch model.status {
        case .searching, .thinking: return "Cancel"
        case .speaking: return "Stop speaking"
        default: return "Start listening"
        }
    }

    private var micAccessibilityHint: String {
        if model.speech.isListening { return "Stops the microphone and sends what you said" }
        switch model.status {
        case .searching, .thinking: return "Stops audio and cancels the current search or answer"
        case .speaking: return "Stops Friday talking and returns to ready"
        default: return "Starts listening for a question"
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if model.messages.isEmpty, model.speech.transcript.isEmpty {
                        Text("Nothing yet. Ask Friday a question to start.")
                            .foregroundStyle(Color.fridayMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                    }
                    ForEach(model.messages) { message in
                        bubble(message)
                            .id(message.id)
                    }
                    if model.speech.isListening, !model.speech.transcript.isEmpty {
                        bubble(ChatMessage(role: .you, text: model.speech.transcript))
                            .opacity(0.7)
                            .id("live")
                    }
                }
                .padding(16)
            }
            .frame(minHeight: 140)
            .frame(maxHeight: .infinity)
            .background(Color.fridayCard.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.fridayLine, lineWidth: 1)
            )
            .onChange(of: model.messages.count) { _, _ in
                if let last = model.messages.last?.id {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        VStack(alignment: message.role == .you ? .trailing : .leading, spacing: 4) {
            Text(message.role == .you ? "YOU SAID" : (message.isDemo ? "FRIDAY · DEMO" : "FRIDAY"))
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(message.role == .you ? Color.fridayMuted : Color.fridayGold)
            Text(message.text)
                .font(.body)
                .foregroundStyle(Color.fridayInk)
                .fixedSize(horizontal: false, vertical: true)
            if !message.sources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(message.sources) { source in
                        Link(destination: source.url) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.title)
                                    .font(.footnote)
                                    .foregroundStyle(Color.fridayGold)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(source.domain)
                                    .font(.caption2)
                                    .foregroundStyle(Color.fridayMuted)
                            }
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(message.role == .you ? Color.fridayYou : Color.fridayBubble)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(message.role == .friday ? Color.fridayGold.opacity(0.28) : Color.fridayLine, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: message.role == .you ? .trailing : .leading)
    }

    private var askRow: some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: $model.draft,
                prompt: Text("Type a question as a fallback…")
                    .foregroundStyle(Color.secondary)
            )
            .foregroundStyle(Color.primary)
            .textInputAutocapitalization(.sentences)
            .disableAutocorrection(false)
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(fieldFocused ? Color.fridayGold : Color.fridayLine, lineWidth: fieldFocused ? 2 : 1)
            )
            .focused($fieldFocused)
            .onSubmit { model.submitTyped() }
            .accessibilityLabel("Type a question")
            Button("Ask") { model.submitTyped() }
                .fontWeight(.semibold)
                .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.03))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.fridayGold)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// Expanding rings around the mic while listening.
private struct PulseRings: View {
    var color: Color = Color.fridayGold
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(0.45), lineWidth: 2)
                    .scaleEffect(animate ? 1.55 : 1)
                    .opacity(animate ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 1.6)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.8),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

private extension Color {
    static let fridayBg = Color(red: 12 / 255, green: 16 / 255, blue: 24 / 255)
    static let fridayCard = Color(red: 20 / 255, green: 26 / 255, blue: 38 / 255)
    static let fridayInk = Color(red: 244 / 255, green: 239 / 255, blue: 228 / 255)
    static let fridayMuted = Color(red: 154 / 255, green: 163 / 255, blue: 181 / 255)
    static let fridayGold = Color(red: 232 / 255, green: 184 / 255, blue: 109 / 255)
    static let fridayGoldDeep = Color(red: 196 / 255, green: 137 / 255, blue: 58 / 255)
    static let fridayLine = Color.fridayInk.opacity(0.1)
    static let fridayYou = Color(red: 28 / 255, green: 36 / 255, blue: 51 / 255)
    static let fridayBubble = Color(red: 26 / 255, green: 35 / 255, blue: 48 / 255)
    static let fridayDanger = Color(red: 240 / 255, green: 168 / 255, blue: 168 / 255)
    static let fridayMicListen = Color(red: 0.18, green: 0.72, blue: 0.38)
    static let fridayMicProcess = Color(red: 0.48, green: 0.28, blue: 0.78)
    static let fridayMicSpeak = Color(red: 0.86, green: 0.20, blue: 0.24)
}

#Preview("Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    ContentView()
        .preferredColorScheme(.light)
}
