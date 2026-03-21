//
//  FlashcardView.swift
//  ChineseVoiceTranslator
//

import SwiftUI

struct FlashcardView: View {
    private let api = APIClient()

    @State private var card: CharacterLookupResult? = nil
    @State private var answer = ""
    @State private var result: AnswerResult? = nil
    @State private var answerRevealed = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @FocusState private var fieldFocused: Bool

    enum AnswerResult {
        case correct, incorrect
    }

    var body: some View {
        ZStack {
            Theme.warmBg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                ZStack {
                    LinearGradient(
                        colors: [Theme.red, Theme.red.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text("卡")
                        .font(.system(size: 110, weight: .black))
                        .foregroundColor(Color.white.opacity(0.08))
                        .offset(x: 60, y: 10)

                    HStack {
                        Text("☭")
                            .font(.system(size: 100))
                            .foregroundColor(.white)
                            .padding(.leading, 12)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("XuéBàn")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Text("Test what you've learned")
                                .font(.subheadline)
                                .foregroundColor(Color.white.opacity(0.75))
                        }
                        .padding(.trailing, 20)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)

                ScrollView {
                    VStack(spacing: 24) {
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.red)
                                .frame(width: 4)
                            HStack(spacing: 12) {
                                Image(systemName: "rectangle.stack.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(Theme.red)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Quiz yourself on your saved vocabulary")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("A random character from your vocabulary is shown — type its English meaning or pinyin to test your memory. Use Show Answer if you're stuck, then move on to keep the streak going.")
                                        .font(.footnote)
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle(cornerRadius: 14)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        if isLoading {
                            ProgressView()
                                .padding(.top, 80)
                        } else if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 60)
                            Button("Try Again") { loadCard() }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.red)
                        } else if let card = card {
                            cardContent(card)
                        } else {
                            // Initial state
                            Button("Start") { loadCard() }
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.red)
                                .cornerRadius(14)
                                .padding(.horizontal, 32)
                                .padding(.top, 80)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .onAppear { loadCard() }
    }

    @ViewBuilder
    private func cardContent(_ card: CharacterLookupResult) -> some View {
        VStack(spacing: 24) {
            // Character display
            VStack(spacing: 8) {
                Text(card.characters)
                    .font(.system(size: 100, weight: .light))
                    .foregroundColor(Theme.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .cardStyle(cornerRadius: 20)

                Text("What does this mean?")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // Answer input
            VStack(alignment: .leading, spacing: 8) {
                Text("English or Pinyin")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("Type your answer...", text: $answer)
                    .font(.system(size: 18))
                    .foregroundColor(.black)
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 2)
                    )
                    .focused($fieldFocused)
                    .disabled(result == .correct)
                    .submitLabel(.done)
                    .onSubmit { checkAnswer(card) }
            }

            // Feedback banner
            if let res = result {
                feedbackBanner(res, card: card)
            }

            // Buttons
            if result == .correct || answerRevealed {
                Button("Next Card") { nextCard() }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.jade)
                    .cornerRadius(14)
            } else {
                Button("Submit") { checkAnswer(card) }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(answer.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.4) : Theme.red)
                    .cornerRadius(14)
                    .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Show Answer") { showAnswer(card) }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.red.opacity(0.08))
                    .cornerRadius(14)

                if result == .incorrect {
                    Button("Next Card") { nextCard() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Theme.jade)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.jade.opacity(0.08))
                        .cornerRadius(14)
                }
            }
        }
    }

    @ViewBuilder
    private func feedbackBanner(_ res: AnswerResult, card: CharacterLookupResult) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: res == .correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 22))
                Text(res == .correct ? "Correct!" : "Incorrect")
                    .font(.system(size: 20, weight: .bold))
            }
            .foregroundColor(res == .correct ? Theme.jade : Theme.red)

            if res == .incorrect {
                VStack(spacing: 2) {
                    Text("English: \(card.english)")
                        .font(.system(size: 15))
                    Text("Pinyin: \(card.pinyin)")
                        .font(.system(size: 15))
                }
                .foregroundColor(.black)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(res == .correct ? Theme.jade.opacity(0.1) : Theme.red.opacity(0.08))
        .cornerRadius(14)
    }

    private var borderColor: Color {
        guard let res = result else { return Color.gray.opacity(0.25) }
        return res == .correct ? Theme.jade : Theme.red
    }

    private func checkAnswer(_ card: CharacterLookupResult) {
        let trimmed = answer.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return }
        fieldFocused = false

        // Check english: any meaning in the english field matches
        let englishWords = card.english.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: "/,;"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let matchesEnglish = englishWords.contains(where: { $0 == trimmed })

        // Check pinyin: strip tones for flexible matching
        let pinyinBase = card.pinyin.lowercased()
            .components(separatedBy: " ").joined()
            .folding(options: .diacriticInsensitive, locale: .current)
        let answerBase = trimmed
            .components(separatedBy: " ").joined()
            .folding(options: .diacriticInsensitive, locale: .current)
        let matchesPinyin = pinyinBase == answerBase || card.pinyin.lowercased() == trimmed

        if matchesEnglish || matchesPinyin {
            result = .correct
        } else {
            result = .incorrect
            answer = ""
            fieldFocused = true
        }
    }

    private func showAnswer(_ card: CharacterLookupResult) {
        fieldFocused = false
        result = .incorrect
        answerRevealed = true
        answer = ""
    }

    private func loadCard() {
        isLoading = true
        errorMessage = nil
        card = nil
        result = nil
        answerRevealed = false
        answer = ""
        api.fetchRandomFlashcard { fetched, err in
            DispatchQueue.main.async {
                isLoading = false
                if let err = err {
                    errorMessage = err
                } else {
                    card = fetched
                    fieldFocused = true
                }
            }
        }
    }

    private func nextCard() {
        loadCard()
    }
}

#Preview {
    FlashcardView()
}
