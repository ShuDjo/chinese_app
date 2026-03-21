import SwiftUI
import AVFoundation
import Combine

// MARK: - PulsingRecordButton

struct PulsingRecordButton: View {
    let isRecording: Bool
    let isLoading: Bool
    let action: () -> Void

    @State private var pulse1: CGFloat = 1.0
    @State private var pulse2: CGFloat = 1.0
    @State private var pulse3: CGFloat = 1.0
    @State private var pulseOpacity1: Double = 0.6
    @State private var pulseOpacity2: Double = 0.6
    @State private var pulseOpacity3: Double = 0.6

    private let buttonSize: CGFloat = 80

    var body: some View {
        ZStack {
            // Pulsing rings — only shown while recording
            if isRecording {
                Circle()
                    .stroke(Color.red.opacity(pulseOpacity1), lineWidth: 3)
                    .frame(width: buttonSize * pulse1, height: buttonSize * pulse1)
                    .onAppear {
                        withAnimation(
                            .easeOut(duration: 1.2)
                            .repeatForever(autoreverses: false)
                            .delay(0.0)
                        ) {
                            pulse1 = 2.0
                            pulseOpacity1 = 0.0
                        }
                    }

                Circle()
                    .stroke(Color.red.opacity(pulseOpacity2), lineWidth: 3)
                    .frame(width: buttonSize * pulse2, height: buttonSize * pulse2)
                    .onAppear {
                        withAnimation(
                            .easeOut(duration: 1.2)
                            .repeatForever(autoreverses: false)
                            .delay(0.4)
                        ) {
                            pulse2 = 2.0
                            pulseOpacity2 = 0.0
                        }
                    }

                Circle()
                    .stroke(Color.red.opacity(pulseOpacity3), lineWidth: 3)
                    .frame(width: buttonSize * pulse3, height: buttonSize * pulse3)
                    .onAppear {
                        withAnimation(
                            .easeOut(duration: 1.2)
                            .repeatForever(autoreverses: false)
                            .delay(0.8)
                        ) {
                            pulse3 = 2.0
                            pulseOpacity3 = 0.0
                        }
                    }
            }

            // Main button circle
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(buttonGradient)
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(color: shadowColor.opacity(0.45), radius: 12, x: 0, y: 6)

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .frame(width: buttonSize * 2.2, height: buttonSize * 2.2)
        .onChange(of: isRecording) { _, newValue in
            if !newValue {
                pulse1 = 1.0; pulseOpacity1 = 0.6
                pulse2 = 1.0; pulseOpacity2 = 0.6
                pulse3 = 1.0; pulseOpacity3 = 0.6
            }
        }
    }

    private var buttonGradient: LinearGradient {
        if isLoading {
            return LinearGradient(
                colors: [Color.gray.opacity(0.7), Color.gray],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isRecording {
            return LinearGradient(
                colors: [Color(red: 0.95, green: 0.15, blue: 0.15), Color(red: 0.70, green: 0.05, blue: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 0.20, green: 0.50, blue: 1.00), Color(red: 0.08, green: 0.30, blue: 0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        if isLoading { return .gray }
        return isRecording ? .red : Color(red: 0.08, green: 0.30, blue: 0.85)
    }
}

// MARK: - WordSpeaker

private class WordSpeaker: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-Hans")
        utterance.rate = 0.35
        synthesizer.speak(utterance)
    }
}

// MARK: - WordRowView

struct WordRowView: View {
    let word: WordResult
    var isDeclined: Bool = false
    var onDecline: (() -> Void)? = nil
    let onTap: () -> Void

    enum PracticeMode { case pinyin, english }

    @State private var practiceMode: PracticeMode? = nil
    @State private var practiceInput = ""
    @State private var practiceResult: Bool? = nil
    @FocusState private var inputFocused: Bool
    @StateObject private var speaker = WordSpeaker()

    var body: some View {
        VStack(spacing: 0) {
            // Main word row
            HStack(spacing: 8) {
                Button(action: onTap) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(word.word)
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(isDeclined ? Color.black.opacity(0.3) : .black)
                                    .strikethrough(isDeclined, color: Color.black.opacity(0.3))
                                Text(word.pinyin)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(isDeclined ? Color.secondary.opacity(0.5) : Theme.red)
                            }
                            Text(word.english)
                                .font(.callout)
                                .foregroundColor(isDeclined ? Color.black.opacity(0.25) : Color.black.opacity(0.6))
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if word.from_cache {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.jade)
                                .font(.system(size: 18))
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.black.opacity(isDeclined ? 0.1 : 0.25))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if let onDecline = onDecline {
                    Button(action: onDecline) {
                        Image(systemName: isDeclined ? "arrow.uturn.left.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(isDeclined ? Theme.jade : Color.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                }
            }

            // Practice actions — hidden when word is declined
            if !isDeclined {
                Divider().padding(.horizontal, 16)

                HStack(spacing: 8) {
                    // Speak button
                    Button { speaker.speak(word.word) } label: {
                        Label("Speak", systemImage: "speaker.wave.2.fill")
                            .font(.caption.weight(.medium))
                            .foregroundColor(Theme.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.red.opacity(0.08))
                    .cornerRadius(8)

                    // Pinyin practice toggle
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if practiceMode == .pinyin {
                                practiceMode = nil
                            } else {
                                practiceMode = .pinyin
                                practiceInput = ""
                                practiceResult = nil
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Pinyin")
                            if practiceMode == .pinyin, let r = practiceResult {
                                Image(systemName: r ? "checkmark" : "xmark")
                                    .font(.caption2)
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(practiceMode == .pinyin ? .white : Theme.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(practiceMode == .pinyin ? Theme.red : Theme.red.opacity(0.08))
                    .cornerRadius(8)

                    // English practice toggle
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if practiceMode == .english {
                                practiceMode = nil
                            } else {
                                practiceMode = .english
                                practiceInput = ""
                                practiceResult = nil
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("English")
                            if practiceMode == .english, let r = practiceResult {
                                Image(systemName: r ? "checkmark" : "xmark")
                                    .font(.caption2)
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(practiceMode == .english ? .white : Theme.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(practiceMode == .english ? Theme.red : Theme.red.opacity(0.08))
                    .cornerRadius(8)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // Practice input area
                if let mode = practiceMode {
                    Divider().padding(.horizontal, 16)

                    HStack(spacing: 10) {
                        TextField(
                            mode == .pinyin ? "Type pinyin…" : "Type English…",
                            text: $practiceInput
                        )
                        .font(.callout)
                        .focused($inputFocused)
                        .onAppear { inputFocused = true }
                        .onSubmit { checkAnswer(mode: mode) }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(inputBorderColor, lineWidth: 1.5)
                        )

                        Button { checkAnswer(mode: mode) } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(practiceInput.isEmpty ? Color.gray.opacity(0.35) : Theme.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(practiceInput.isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, practiceResult == nil ? 12 : 4)

                    if let result = practiceResult {
                        HStack(spacing: 6) {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result ? Theme.jade : .red)
                            Text(result ? "Correct!" : "Answer: \(mode == .pinyin ? word.pinyin : word.english)")
                                .font(.caption)
                                .foregroundColor(result ? Theme.jade : .red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.opacity)
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
        .opacity(isDeclined ? 0.7 : 1.0)
    }

    private var inputBorderColor: Color {
        guard let result = practiceResult else { return Color.clear }
        return result ? Theme.jade : .red
    }

    private func checkAnswer(mode: PracticeMode) {
        let correct: Bool
        if mode == .pinyin {
            correct = normalize(practiceInput) == normalize(word.pinyin)
        } else {
            let input = practiceInput.trimmingCharacters(in: .whitespaces).lowercased()
            let options = word.english.lowercased()
                .components(separatedBy: CharacterSet(charactersIn: ",;"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
            correct = options.contains(input)
        }
        withAnimation { practiceResult = correct }
    }

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces)
         .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

// MARK: - ScoreRing

struct ScoreRing: View {
    let score: Int

    @State private var progress: CGFloat = 0

    private let diameter: CGFloat = 140
    private let lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: lineWidth)
                .frame(width: diameter, height: diameter)

            // Filled arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(-90))

            // Center label
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(ringColor)
                Text("/ 100")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                progress = CGFloat(score) / 100.0
            }
        }
    }

    private var ringColor: Color {
        score >= 80 ? .green : score >= 50 ? .orange : .red
    }
}

// MARK: - CardView

struct CardView<Content: View>: View {
    var cornerRadius: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(Color.white)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 3)
    }
}
