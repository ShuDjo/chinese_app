import SwiftUI

struct QuizView: View {
    @State private var topic = ""
    @State private var question: QuizQuestion?
    @State private var answer = ""
    @State private var evaluation: QuizEvaluation?
    @State private var isLoadingQuestion = false
    @State private var isLoadingEval = false
    @State private var errorMessage: String?

    private let api = APIClient()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Quiz")
                    .font(.title2)
                    .padding(.top)

                // Topic input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Topic (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        TextField("e.g. measure words, tones, greetings", text: $topic)
                            .textFieldStyle(.roundedBorder)
                        Button("Ask") {
                            loadQuestion()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .disabled(isLoadingQuestion)
                    }
                }
                .padding(.horizontal)

                if isLoadingQuestion {
                    ProgressView("Generating question...")
                }

                // Question
                if let q = question {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()

                        HStack {
                            Text(q.type.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(typeColor(q.type).opacity(0.15))
                                .foregroundColor(typeColor(q.type))
                                .clipShape(Capsule())
                            Spacer()
                        }

                        Text(q.question)
                            .font(.body)

                        // Answer input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your answer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Type your answer...", text: $answer, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                                .disabled(evaluation != nil)
                        }

                        if evaluation == nil {
                            Button("Submit") {
                                submitAnswer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(answer.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty || isLoadingEval)

                            if isLoadingEval {
                                ProgressView("Evaluating...")
                            }
                        }

                        // Evaluation result
                        if let eval = evaluation {
                            Divider()

                            // Score badge
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(scoreColor(eval.score).opacity(0.15))
                                        .frame(width: 64, height: 64)
                                    Text("\(eval.score)")
                                        .font(.title2)
                                        .bold()
                                        .foregroundColor(scoreColor(eval.score))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(eval.correct ? "Correct!" : "Not quite")
                                        .font(.headline)
                                        .foregroundColor(eval.correct ? .green : .orange)
                                    Text("out of 100")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }

                            // Feedback
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Feedback")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(eval.feedback)
                                    .font(.body)
                            }

                            // Correct answer
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Correct answer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(eval.correct_answer)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }

                            // Next question
                            Button("Next Question") {
                                nextQuestion()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }

                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
        }
    }

    private func loadQuestion() {
        isLoadingQuestion = true
        errorMessage = nil
        question = nil
        answer = ""
        evaluation = nil
        api.fetchQuestion(topic: topic.isEmpty ? nil : topic) { q, err in
            DispatchQueue.main.async {
                isLoadingQuestion = false
                if let err = err { errorMessage = err }
                question = q
            }
        }
    }

    private func submitAnswer() {
        guard let q = question else { return }
        isLoadingEval = true
        errorMessage = nil
        api.evaluateAnswer(question: q.question, answer: answer) { eval, err in
            DispatchQueue.main.async {
                isLoadingEval = false
                if let err = err { errorMessage = err }
                evaluation = eval
            }
        }
    }

    private func nextQuestion() {
        answer = ""
        evaluation = nil
        loadQuestion()
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 50 { return .orange }
        return .red
    }

    private func typeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "vocabulary":   return .blue
        case "grammar":      return .purple
        case "translation":  return .orange
        default:             return .gray
        }
    }
}
