import SwiftUI
import WebKit

// MARK: - Stroke Order View

struct StrokeOrderView: UIViewRepresentable {
    let word: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor.systemBackground
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(makeHTML(), baseURL: nil)
    }

    private func makeHTML() -> String {
        let chars = word.filter { c in
            let cp = c.unicodeScalars.first!.value
            return (0x4E00...0x9FFF).contains(cp) ||
                   (0x3400...0x4DBF).contains(cp)
        }

        var containers = ""
        var writers = ""
        for (i, char) in chars.enumerated() {
            let escaped = String(char)
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            containers += "<div class='char-box'><div id='c\(i)'></div><p class='label'>\(char)</p></div>\n"
            writers += """
            HanziWriter.create('c\(i)', '\(escaped)', {
              width: 140, height: 140, padding: 5,
              showOutline: true,
              strokeColor: '#1a1a2e',
              outlineColor: '#d0d0d0',
              strokeAnimationSpeed: 0.8,
              delayBetweenStrokes: 250,
              delayBetweenLoops: 2000,
              loopAnimate: true
            });
            """
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body {
              background: #ffffff;
              display: flex;
              flex-wrap: wrap;
              justify-content: center;
              align-items: flex-start;
              padding: 24px 16px;
              gap: 24px;
            }
            .char-box { text-align: center; }
            .label {
              margin-top: 8px;
              font-size: 16px;
              font-family: -apple-system, sans-serif;
              color: #444;
            }
          </style>
        </head>
        <body>
          \(containers)
          <script src="https://cdn.jsdelivr.net/npm/hanzi-writer@3.5/dist/hanzi-writer.min.js"></script>
          <script>\(writers)</script>
        </body>
        </html>
        """
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var isRecording = false
    @State private var result: TranslationResult?
    @State private var errorMessage: String?
    @State private var selectedWord: WordResult?

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
                        Text("Words — tap to see strokes")
                            .font(.headline)

                        ForEach(result.words) { wordResult in
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
                            .contentShape(Rectangle())
                            .onTapGesture { selectedWord = wordResult }
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
        .sheet(item: $selectedWord) { word in
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.word)
                            .font(.largeTitle)
                            .bold()
                        Text(word.pinyin)
                            .foregroundColor(.secondary)
                        Text(word.english)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Done") { selectedWord = nil }
                        .padding(.leading)
                }
                .padding()

                Divider()

                StrokeOrderView(word: word.word)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
