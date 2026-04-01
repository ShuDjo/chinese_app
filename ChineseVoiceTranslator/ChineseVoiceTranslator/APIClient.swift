//
//  APIClient.swift
//  ChineseVoiceTranslator
//
//  Created by Djordje Petkovic on 25. 11. 2025..
//
import Foundation

struct WordResult: Decodable, Identifiable {
    var id: String { word }
    let word: String
    let english: String
    let pinyin: String
    let from_cache: Bool
}

// Returned by /transcribe — words already translated, no sentence yet
struct TranscriptionResult: Decodable {
    let chinese_transcription: String
    let words: [WordResult]
    let error: String?
}

// Returned by /translate (Accept) — just the sentence
struct SentenceResult: Decodable {
    let sentence_translation: String
}

// Character lookup
struct CharacterLookupResult: Decodable {
    let characters: String
    let pinyin: String
    let english: String
    let serbian: String?
}

// Quiz models
struct LessonInfo: Decodable {
    let source: String
    let added_at: String
}

struct LessonsResult: Decodable {
    let lessons: [LessonInfo]
}

struct QuizQuestion: Decodable {
    let question: String
}

struct ExchangeFeedback: Decodable {
    let question: String
    let answer: String
    let score: Int
    let mistake: String?
}

struct SessionEvaluation: Decodable {
    let overall_score: Int
    let summary: String
    let strengths: [String]
    let improvements: [String]
    let exchanges: [ExchangeFeedback]
}

struct HistoryItem {
    let question: String
    let answer: String
}

class APIClient {
    private let base = "https://chinese-app-a96d.onrender.com"

    // Step 1: upload audio → get transcription + per-word translations
    func transcribeAudio(url: URL, completion: @escaping (TranscriptionResult?, String?) -> Void) {
        var request = URLRequest(url: URL(string: "\(base)/transcribe")!)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let filename = url.lastPathComponent
        let fileData = try? Data(contentsOf: url)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData ?? Data())
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let err = error { completion(nil, err.localizedDescription); return }
            guard let data = data else { completion(nil, "No data received"); return }
            do {
                let decoded = try JSONDecoder().decode(TranscriptionResult.self, from: data)
                completion(decoded, nil)
            } catch {
                completion(nil, "Decode error: \(error.localizedDescription)\nRaw: \(String(data: data, encoding: .utf8) ?? "")")
            }
        }.resume()
    }

    // Character lookup by English or Chinese
    func lookupCharacter(_ query: String, completion: @escaping (CharacterLookupResult?, String?) -> Void) {
        var request = URLRequest(url: URL(string: "\(base)/character/lookup")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["query": query])
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let err = error { completion(nil, err.localizedDescription); return }
            guard let data = data else { completion(nil, "No data"); return }
            do {
                completion(try JSONDecoder().decode(CharacterLookupResult.self, from: data), nil)
            } catch {
                completion(nil, "Decode error: \(String(data: data, encoding: .utf8) ?? "")")
            }
        }.resume()
    }

    // Quiz: fetch available lesson sources
    func fetchLessons(completion: @escaping ([LessonInfo], String?) -> Void) {
        let url = URL(string: "\(base)/quiz/lessons")!
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let err = error { completion([], err.localizedDescription); return }
            guard let data = data else { completion([], "No data"); return }
            let result = try? JSONDecoder().decode(LessonsResult.self, from: data)
            completion(result?.lessons ?? [], result == nil ? "Decode error" : nil)
        }.resume()
    }

    // Quiz: start session — get first question
    func startQuiz(topic: String, sources: [String]? = nil, completion: @escaping (String?, String?) -> Void) {
        var body: [String: Any] = ["topic": topic]
        if let sources = sources { body["sources"] = sources }
        postJSON("\(base)/quiz/start", body: body) { data, err in
            guard let data = data else { completion(nil, err); return }
            let q = (try? JSONDecoder().decode(QuizQuestion.self, from: data))?.question
            completion(q, q == nil ? "Decode error" : nil)
        }
    }

    // Quiz: get next question given conversation history
    func nextQuestion(topic: String, history: [HistoryItem], sources: [String]? = nil, completion: @escaping (String?, String?) -> Void) {
        var payload: [String: Any] = [
            "topic": topic,
            "history": history.map { ["question": $0.question, "answer": $0.answer] }
        ]
        if let sources = sources { payload["sources"] = sources }
        postJSON("\(base)/quiz/next", body: payload) { data, err in
            guard let data = data else { completion(nil, err); return }
            let q = (try? JSONDecoder().decode(QuizQuestion.self, from: data))?.question
            completion(q, q == nil ? "Decode error" : nil)
        }
    }

    // Quiz: finish session and get evaluation
    func finishQuiz(topic: String, history: [HistoryItem], sources: [String]? = nil, language: String = "en", completion: @escaping (SessionEvaluation?, String?) -> Void) {
        var payload: [String: Any] = [
            "topic": topic,
            "history": history.map { ["question": $0.question, "answer": $0.answer] },
            "language": language
        ]
        if let sources = sources { payload["sources"] = sources }
        postJSON("\(base)/quiz/finish", body: payload) { data, err in
            guard let data = data else { completion(nil, err); return }
            do {
                completion(try JSONDecoder().decode(SessionEvaluation.self, from: data), nil)
            } catch {
                completion(nil, "Decode error: \(String(data: data, encoding: .utf8) ?? "")")
            }
        }
    }

    // Quiz: transcribe answer audio (auto language detection)
    func transcribeAnswer(url: URL, completion: @escaping (String?, String?) -> Void) {
        var request = URLRequest(url: URL(string: "\(base)/quiz/transcribe")!)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        let fileData = try? Data(contentsOf: url)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"answer.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData ?? Data())
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let err = error { completion(nil, err.localizedDescription); return }
            guard let data = data else { completion(nil, "No data"); return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = json["text"] as? String {
                completion(text, nil)
            } else {
                completion(nil, "Decode error: \(String(data: data, encoding: .utf8) ?? "")")
            }
        }.resume()
    }

    // Flashcard: fetch a random character from the database
    func fetchRandomFlashcard(completion: @escaping (CharacterLookupResult?, String?) -> Void) {
        let url = URL(string: "\(base)/character/random")!
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let err = error { completion(nil, err.localizedDescription); return }
            guard let data = data else { completion(nil, "No data"); return }
            do {
                completion(try JSONDecoder().decode(CharacterLookupResult.self, from: data), nil)
            } catch {
                completion(nil, "Decode error: \(String(data: data, encoding: .utf8) ?? "")")
            }
        }.resume()
    }

    // Exam: translate current question as a hint (no DB writes)
    func translateHint(text: String, completion: @escaping (String?, String?) -> Void) {
        postJSON("\(base)/exam/hint", body: ["text": text]) { data, err in
            guard let data = data else { completion(nil, err); return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let translation = json["translation"] as? String {
                completion(translation, nil)
            } else {
                completion(nil, "Decode error")
            }
        }
    }

    // Shared helper for JSON POST requests
    private func postJSON(_ urlString: String, body: [String: Any], completion: @escaping (Data?, String?) -> Void) {
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let err = error { completion(nil, err.localizedDescription); return }
            guard let data = data else { completion(nil, "No data"); return }
            completion(data, nil)
        }.resume()
    }

    // Step 2 (Accept): send text + words → save to DB, get sentence translation
    func translateText(_ text: String, words: [WordResult], completion: @escaping (String?, String?) -> Void) {
        var request = URLRequest(url: URL(string: "\(base)/translate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "text": text,
            "words": words.map { ["word": $0.word, "english": $0.english, "pinyin": $0.pinyin] }
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let err = error { completion(nil, err.localizedDescription); return }
            guard let data = data else { completion(nil, "No data received"); return }
            do {
                let decoded = try JSONDecoder().decode(SentenceResult.self, from: data)
                completion(decoded.sentence_translation, nil)
            } catch {
                completion(nil, "Decode error: \(error.localizedDescription)\nRaw: \(String(data: data, encoding: .utf8) ?? "")")
            }
        }.resume()
    }
}
