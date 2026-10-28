import SwiftUI

/// Single screen: title, status, gold mic, chat transcript, typed fallback.
struct ContentView: View {
    @StateObject private var model = FridayViewModel()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            Color.fridayBg.ignoresSafeArea()
            VStack(spacing: 18) {
                header
                liveSearchToggle
                statusPill
                if let note = model.searchNote {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Color.fridayMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                if let note = model.voiceNote {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(Color.fridayMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                micButton
                Text(model.speech.isListening ? "Listening… tap again when you are done" : "Tap the mic and speak, or type below")
                    .font(.subheadline)
                    .foregroundStyle(Color.fridayMuted)
                transcript
                askRow
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
        case .listening: return Color(red: 1, green: 0.42, blue: 0.42)
        case .searching, .thinking: return Color.fridayGold
        case .speaking: return Color.fridayOk
        case .error: return Color.fridayDanger
        case .ready: return Color.fridayMuted
        }
    }

    private var micButton: some View {
        Button {
            Task { await model.toggleMic() }
        } label: {
            ZStack {
                if model.speech.isListening {
                    PulseRings()
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.95, green: 0.82, blue: 0.60),
                                Color.fridayGold,
                                Color.fridayGoldDeep,
                            ],
                            center: UnitPoint(x: 0.35, y: 0.30),
                            startRadius: 4,
                            endRadius: 80
                        )
                    )
                    .frame(width: 132, height: 132)
                    .shadow(color: Color.fridayGold.opacity(0.28), radius: 16, y: 8)
                Image(systemName: "mic.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.03))
            }
            .frame(width: 132, height: 132)
        }
        .buttonStyle(.plain)
        .disabled(model.isBusy && !model.speech.isListening)
        .accessibilityLabel(model.speech.isListening ? "Stop listening" : "Start listening")
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
            Text(message.role == .you ? "YOU" : (message.isDemo ? "FRIDAY · DEMO" : "FRIDAY"))
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
            TextField("Type a question as a fallback…", text: $model.draft)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .padding(12)
                .background(Color.fridayCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(fieldFocused ? Color.fridayGold : Color.fridayLine, lineWidth: fieldFocused ? 2 : 1)
                )
                .focused($fieldFocused)
                .onSubmit { Task { await model.submitTyped() } }
            Button("Ask") { Task { await model.submitTyped() } }
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
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .stroke(Color.fridayGold.opacity(0.45), lineWidth: 2)
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
    static let fridayOk = Color(red: 143 / 255, green: 212 / 255, blue: 168 / 255)
}

#Preview {
    ContentView()
}
