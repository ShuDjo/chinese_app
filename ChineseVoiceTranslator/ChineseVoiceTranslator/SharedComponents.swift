import SwiftUI

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

// MARK: - WordRowView

struct WordRowView: View {
    let word: WordResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Chinese character + pinyin
                VStack(alignment: .leading, spacing: 3) {
                    Text(word.word)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    Text(word.pinyin)
                        .font(.caption)
                        .foregroundColor(Theme.red)
                }
                .frame(minWidth: 60, alignment: .leading)

                // English
                Text(word.english)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)

                // Cache badge
                if word.from_cache {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.jade)
                        .font(.system(size: 16))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
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
