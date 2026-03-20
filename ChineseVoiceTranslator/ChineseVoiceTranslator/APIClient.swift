//
//  APIClient.swift
//  ChineseVoiceTranslator
//
//  Created by Djordje Petkovic on 25. 11. 2025..
//
import Foundation

// Returned by /transcribe
struct TranscriptionResult: Decodable {
    let chinese_transcription: String
    let words: [String]
}

// Returned by /translate
struct WordResult: Decodable, Identifiable {
    var id: String { word }
    let word: String
    let english: String
    let pinyin: String
    let from_cache: Bool
}

struct TranslationResult: Decodable {
    let chinese_transcription: String
    let sentence_translation: String?
    let words: [WordResult]
}

class APIClient {
    private let base = "https://chinese-app-a96d.onrender.com"

    // Step 1: upload audio, get back raw transcription + segmented words
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

    // Step 2: called on Accept — translate text, write to DB
    func translateText(_ text: String, completion: @escaping (TranslationResult?, String?) -> Void) {
        var request = URLRequest(url: URL(string: "\(base)/translate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let err = error { completion(nil, err.localizedDescription); return }
            guard let data = data else { completion(nil, "No data received"); return }
            do {
                let decoded = try JSONDecoder().decode(TranslationResult.self, from: data)
                completion(decoded, nil)
            } catch {
                completion(nil, "Decode error: \(error.localizedDescription)\nRaw: \(String(data: data, encoding: .utf8) ?? "")")
            }
        }.resume()
    }
}
