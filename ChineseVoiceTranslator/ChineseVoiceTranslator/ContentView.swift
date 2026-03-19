import SwiftUI

struct ContentView: View {
    @State private var isRecording = false
    @State private var result: TranslationResult?
    @State private var errorMessage: String?

    private let recorder = AudioRecorder()
    private let api = APIClient()

    var body: some View {
        VStack(spacing: 20) {
            Text("Chinese Voice Translator")
                .font(.title2)
                .padding()

            Button(isRecording ? "Stop Recording" : "Start Recording") {
                if isRecording {
                    if let url = recorder.stopRecording() {
                        isRecording = false
                        api.uploadAudio(url: url) { res, err in
                            DispatchQueue.main.async {
                                if let err = err { errorMessage = err }
                                result = res
                            }
                        }
                    }
                } else {
                    errorMessage = nil
                    result = nil
                    recorder.startRecording()
                    isRecording = true
                }
            }
            .padding()
            .background(isRecording ? Color.red : Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())

            if let result = result {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    Text("Result")
                        .font(.headline)

                    Text(result.chinese_transcription)
                        .font(.title3)

                    if let sentence = result.sentence_translation {
                        Text(sentence)
                            .foregroundColor(.secondary)
                    }

                    if !result.words.isEmpty {
                        Divider()
                        Text("Words")
                            .font(.headline)

                        ForEach(result.words, id: \.word) { wordResult in
                            HStack(spacing: 12) {
                                Text(wordResult.word)
                                    .frame(minWidth: 48, alignment: .leading)
                                    .bold()
                                Text(wordResult.pinyin)
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 64, alignment: .leading)
                                Text(wordResult.english)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if wordResult.from_cache {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .font(.callout)
                        }
                    }
                }
                .padding()
            }

            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            }

            Spacer()
        }
        .padding()
    }
}
