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

    // Results
    @State private var evaluation: SessionEvaluation?

    @State private var errorMessage: String?

    @StateObject private var speaker = QuizSpeaker()
    private let recorder = AudioRecorder()
    private let api = APIClient()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if evaluation != nil {
                    resultsSection
                } else if sessionActive {
                    sessionSection
                } else {
                    startSection
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                        .padding(.horizontal)
                }
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
    }

    // MARK: - Start

    var startSection: some View {
        VStack(spacing: 20) {
            Text("Quiz").font(.title2)

            VStack(alignment: .leading, spacing: 6) {
                Text("Topic").font(.caption).foregroundColor(.secondary)
                TextField("e.g. greetings, measure words, tones", text: $topic)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            if isLoadingQuestion {
                ProgressView("Loading first question...")
            } else {
                Button("Start Quiz") { beginSession() }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(topic.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .disabled(topic.isEmpty)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Session

    var sessionSection: some View {
        VStack(spacing: 20) {
            Text(topic).font(.title3).bold().padding(.horizontal)

            // History (previous exchanges, collapsed)
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(history.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Q\(i + 1): \(history[i].question)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("A: \(history[i].answer)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                Divider()
            }

            // Current question
            if isLoadingQuestion {
                ProgressView("Loading question...")
                    .padding()
            } else if !currentQuestion.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Q\(history.count + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            speaker.speak(currentQuestion)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    Text(currentQuestion)
                        .font(.title3)
                        .bold()
                }
                .padding(.horizontal)
            }

            // Transcribed answer preview
            if !pendingAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your answer").font(.caption).foregroundColor(.secondary)
                    Text(pendingAnswer).font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.08))
                .cornerRadius(10)
                .padding(.horizontal)
            }

            if isTranscribing {
                ProgressView("Transcribing...")
            }

            // Record button
            if !isLoadingQuestion && !isTranscribing && !currentQuestion.isEmpty {
                Button {
                    isRecording ? stopRecording() : startRecording()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                        Text(isRecording ? "Stop Answer" : "Record Answer")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .padding(.horizontal)
            }

            Divider()

            // Stop button
            if isEvaluating {
                ProgressView("Evaluating session...")
                    .padding()
            } else {
                Button {
                    endSession()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("Stop & Evaluate")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Results

    var resultsSection: some View {
        VStack(spacing: 24) {
            Text("Session Complete").font(.title2)

            if let eval = evaluation {
                // Score
                ZStack {
                    Circle()
                        .fill(scoreColor(eval.overall_score).opacity(0.15))
                        .frame(width: 110, height: 110)
                    VStack(spacing: 2) {
                        Text("\(eval.overall_score)")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(scoreColor(eval.overall_score))
                        Text("/ 100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(eval.summary)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Strengths
                VStack(alignment: .leading, spacing: 8) {
                    Text("Strengths").font(.headline).foregroundColor(.green)
                    ForEach(eval.strengths, id: \.self) { s in
                        Label(s, systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.green.opacity(0.08))
                .cornerRadius(12)
                .padding(.horizontal)

                // Improvements
                VStack(alignment: .leading, spacing: 8) {
                    Text("To Improve").font(.headline).foregroundColor(.orange)
                    ForEach(eval.improvements, id: \.self) { s in
                        Label(s, systemImage: "arrow.right.circle.fill")
                            .foregroundColor(.orange)
                            .font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.08))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            Button("New Session") { resetSession() }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .padding(.horizontal)
        }
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
                if let err = err { errorMessage = err; return }
                if let q = question {
                    currentQuestion = q
                    speaker.speak(q)
                }
            }
        }
    }

    func endSession() {
        if isRecording {
            _ = recorder.stopRecording()
            isRecording = false
        }
        speaker.stop()
        guard !history.isEmpty else {
            sessionActive = false
            return
        }
        isEvaluating = true
        currentQuestion = ""
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
