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

struct TranslationResult: Decodable {
    let chinese_transcription: String
    let sentence_translation: String?
    let words: [WordResult]
}

class APIClient {
    let backendURL = URL(string: "https://chinese-app-a96d.onrender.com/translate")!  // change later to Fly.io

    func uploadAudio(url: URL, completion: @escaping (TranslationResult?, String?) -> Void) {
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let filename = url.lastPathComponent
        let fileData = try? Data(contentsOf: url)

        // Build multipart
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData ?? Data())
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let err = error {
                completion(nil, err.localizedDescription)
                return
            }

            guard let data = data else {
                completion(nil, "No data received")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(TranslationResult.self, from: data)
                completion(decoded, nil)
            } catch {
                completion(nil, "Decode error: \(error.localizedDescription)\nRaw: \(String(data: data, encoding: .utf8) ?? "")")
            }
        }.resume()
    }
}
