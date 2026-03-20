import SwiftUI
import AVFoundation
import Combine

// MARK: - Speaker

class QuizSpeaker: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.4
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

// MARK: - Quiz View

struct QuizView: View {
    // Setup
    @State private var topic = ""

    // Session
    @State private var sessionActive = false
    @State private var currentQuestion = ""
    @State private var history: [HistoryItem] = []

    // Recording
    @State private var isRecording = false
    @State private var pendingAnswer = ""   // transcribed, shown before adding to history

    // Loading states
    @State private var isLoadingQuestion = false
    @State private var isTranscribing = false
    @State private var isEvaluating = false
    @State private var sessionEnded = false

    // Results
    @State private var evaluation: SessionEvaluation?

    @State private var errorMessage: String?

    @StateObject private var speaker = QuizSpeaker()
    private let recorder = AudioRecorder()
    private let api = APIClient()

    var body: some View {
        ZStack(alignment: .top) {
            Theme.warmBg.ignoresSafeArea()

            if evaluation != nil {
                resultsSection
            } else if sessionActive {
                sessionView
            } else {
                startView
            }
        }
    }

    // MARK: - Start View

    private var startView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                ZStack {
                    LinearGradient(
                        colors: [Theme.red, Theme.red.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    // Watermark
                    Text("问")
                        .font(.system(size: 130, weight: .black))
                        .foregroundColor(Color.white.opacity(0.08))
                        .offset(x: 70, y: 8)

                    VStack(spacing: 4) {
                        Text("Quiz")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Text("Test your Chinese skills")
                            .font(.subheadline)
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 24) {
                    // Topic input card
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Choose a topic", systemImage: "text.book.closed.fill")
                            .font(.headline)
                            .foregroundColor(Theme.red)

                        TextField("e.g. greetings, measure words, tones", text: $topic)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .font(.callout)
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 16)

                    if isLoadingQuestion {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading first question…")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        Button {
                            beginSession()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Start Quiz")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                topic.isEmpty
                                    ? LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)],
                                                     startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Theme.red, Theme.red.opacity(0.78)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(topic.isEmpty)
                        .padding(.horizontal, 16)
                    }

                    if let error = errorMessage {
                        errorBanner(error)
                    }
                }
                .padding(.top, 28)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Session View

    private var sessionView: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    // Topic banner
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Topic")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(topic)
                                .font(.headline)
                                .foregroundColor(Theme.red)
                        }
                        Spacer()
                        Text("Q\(history.count + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.red.opacity(0.1))
                            .foregroundColor(Theme.red)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // History items
                    if !history.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(history.indices, id: \.self) { i in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("Q\(i + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(history[i].question)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(history[i].answer)
                                            .font(.caption)
                                            .italic()
                                            .foregroundColor(Color.primary.opacity(0.6))
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Current question card
                    if isLoadingQuestion {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading question…")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 3)
                        .padding(.horizontal, 16)
                    } else if !currentQuestion.isEmpty {
                        ZStack(alignment: .bottomTrailing) {
                            // Card background
                            Color.white
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.09), radius: 10, x: 0, y: 4)

                            // Watermark
                            Text("文")
                                .font(.system(size: 90, weight: .black))
                                .foregroundColor(Theme.gold.opacity(0.10))
                                .padding(8)

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label("Question", systemImage: "questionmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button {
                                        speaker.speak(currentQuestion)
                                    } label: {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(Theme.red)
                                            .padding(8)
                                            .background(Theme.red.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                                Text(currentQuestion)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(18)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }

                    // Pending answer preview
                    if !pendingAnswer.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your answer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(pendingAnswer)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(red: 0.20, green: 0.50, blue: 1.00).opacity(0.08))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }

                    if isTranscribing {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Transcribing…")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .transition(.opacity)
                    }

                    // Record button
                    if !isLoadingQuestion && !isTranscribing && !currentQuestion.isEmpty {
                        PulsingRecordButton(
                            isRecording: isRecording,
                            isLoading: isTranscribing
                        ) {
                            isRecording ? stopRecording() : startRecording()
                        }
                        .padding(.top, 8)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }

                    if let error = errorMessage {
                        errorBanner(error)
                            .padding(.horizontal, 16)
                    }

                    // Bottom padding so content clears the sticky stop button
                    Spacer(minLength: 100)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentQuestion)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoadingQuestion)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: pendingAnswer)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isTranscribing)
            }
            .scrollIndicators(.hidden)

            // Stop & Evaluate sticky button
            VStack(spacing: 0) {
                if isEvaluating {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Evaluating session…")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                } else {
                    Button {
                        endSession()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                            Text("Stop & Evaluate")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color(red: 0.88, green: 0.46, blue: 0.00)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Theme.warmBg
                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -4)
                    )
                }
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Results header
                ZStack {
                    LinearGradient(
                        colors: [Theme.red, Theme.red.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text("Session Complete")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .ignoresSafeArea(edges: .top)

                if let eval = evaluation {
                    // Score ring
                    ScoreRing(score: eval.overall_score)
                        .padding(.top, 8)

                    // Summary
                    Text(eval.summary)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    // Strengths
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Strengths", systemImage: "star.fill")
                            .font(.headline)
                            .foregroundColor(Theme.jade)
                        ForEach(eval.strengths, id: \.self) { s in
                            Label(s, systemImage: "checkmark.circle.fill")
                                .foregroundColor(Theme.jade)
                                .font(.callout)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.jade.opacity(0.08))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    // Improvements
                    VStack(alignment: .leading, spacing: 10) {
                        Label("To Improve", systemImage: "arrow.up.circle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        ForEach(eval.improvements, id: \.self) { s in
                            Label(s, systemImage: "arrow.right.circle.fill")
                                .foregroundColor(.orange)
                                .font(.callout)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)

                    // Mistakes
                    let mistakes = eval.exchanges.filter { $0.mistake != nil }
                    if !mistakes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Mistakes", systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundColor(.red)

                            ForEach(mistakes.indices, id: \.self) { i in
                                let ex = mistakes[i]
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top) {
                                        Text("Q: \(ex.question)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                        Text("\(ex.score)/100")
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(scoreColor(ex.score))
                                    }
                                    Text("Your answer: \(ex.answer)")
                                        .font(.caption)
                                        .italic()
                                        .foregroundColor(.secondary)
                                    if let mistake = ex.mistake {
                                        Label(mistake, systemImage: "exclamationmark.circle.fill")
                                            .font(.callout)
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(12)
                                .background(Color.red.opacity(0.06))
                                .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                    }
                }

                Button {
                    resetSession()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("New Session")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.20, green: 0.50, blue: 1.00), Color(red: 0.08, green: 0.30, blue: 0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.callout)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Actions

    func beginSession() {
        isLoadingQuestion = true
        errorMessage = nil
        api.startQuiz(topic: topic) { question, err in
            DispatchQueue.main.async {
                isLoadingQuestion = false
                if let err = err { errorMessage = err; return }
                if let q = question {
                    currentQuestion = q
                    sessionActive = true
                    speaker.speak(q)
                }
            }
        }
    }

    func startRecording() {
        speaker.stop()
        pendingAnswer = ""
        recorder.startRecording()
        isRecording = true
    }

    func stopRecording() {
        guard let url = recorder.stopRecording() else { return }
        isRecording = false
        isTranscribing = true

        api.transcribeAnswer(url: url) { text, err in
            DispatchQueue.main.async {
                isTranscribing = false
                if let err = err { errorMessage = err; return }
                guard let text = text, !text.isEmpty else { return }

                pendingAnswer = text
                let answered = currentQuestion
                history.append(HistoryItem(question: answered, answer: text))
                pendingAnswer = ""
                currentQuestion = ""
                loadNextQuestion()
            }
        }
    }

    func loadNextQuestion() {
        isLoadingQuestion = true
        errorMessage = nil
        api.nextQuestion(topic: topic, history: history) { question, err in
            DispatchQueue.main.async {
                isLoadingQuestion = false
                guard !sessionEnded else { return }
                if let err = err { errorMessage = err; return }
                if let q = question {
                    currentQuestion = q
                    speaker.speak(q)
                }
            }
        }
    }

    func endSession() {
        sessionEnded = true
        if isRecording {
            _ = recorder.stopRecording()
            isRecording = false
        }
        speaker.stop()
        isLoadingQuestion = false
        currentQuestion = ""
        guard !history.isEmpty else {
            sessionActive = false
            return
        }
        isEvaluating = true
        api.finishQuiz(topic: topic, history: history) { eval, err in
            DispatchQueue.main.async {
                isEvaluating = false
                if let err = err { errorMessage = err; return }
                evaluation = eval
            }
        }
    }

    func resetSession() {
        topic = ""
        sessionActive = false
        sessionEnded = false
        currentQuestion = ""
        history = []
        pendingAnswer = ""
        evaluation = nil
        errorMessage = nil
    }

    func scoreColor(_ score: Int) -> Color {
        score >= 80 ? .green : score >= 50 ? .orange : .red
    }
}
