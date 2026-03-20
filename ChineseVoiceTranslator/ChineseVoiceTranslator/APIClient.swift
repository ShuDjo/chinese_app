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
}

// Returned by /translate (Accept) — just the sentence
struct SentenceResult: Decodable {
    let sentence_translation: String
}

// Quiz models
struct QuizQuestion: Decodable {
    let question: String
    let type: String
}

struct QuizEvaluation: Decodable {
    let score: Int
    let correct: Bool
    let feedback: String
    let correct_answer: String
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

    // Quiz: get a question based on optional topic
    func fetchQuestion(topic: String?, completion: @escaping (QuizQuestion?, String?) -> Void) {
        var request = URLRequest(url: URL(string: "\(base)/quiz/question")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = [:]
        if let topic = topic, !topic.isEmpty { payload["topic"] = topic }
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let err = error { completion(nil, err.localizedDescription); return }
            guard let data = data else { completion(nil, "No data"); return }
            do {
                completion(try JSONDecoder().decode(QuizQuestion.self, from: data), nil)
            } catch {
                completion(nil, "Decode error: \(String(data: data, encoding: .utf8) ?? "")")
            }
        }.resume()
    }

    // Quiz: evaluate the student's answer
    func evaluateAnswer(question: String, answer: String, completion: @escaping (QuizEvaluation?, String?) -> Void) {
        var request = URLRequest(url: URL(string: "\(base)/quiz/evaluate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["question": question, "answer": answer])

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let err = error { completion(nil, err.localizedDescription); return }
            guard let data = data else { completion(nil, "No data"); return }
            do {
                completion(try JSONDecoder().decode(QuizEvaluation.self, from: data), nil)
            } catch {
                completion(nil, "Decode error: \(String(data: data, encoding: .utf8) ?? "")")
            }
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
