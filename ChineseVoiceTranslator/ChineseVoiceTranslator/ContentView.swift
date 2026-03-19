import SwiftUI
import WebKit

// MARK: - Stroke Order View

struct StrokeOrderView: UIViewRepresentable {
    let word: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.backgroundColor = UIColor.systemBackground
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(makeHTML(), baseURL: URL(string: "https://cdn.jsdelivr.net")!)
    }

    private func makeHTML() -> String {
        let chars = cjkChars()
        var svgBoxes = ""
        var fetchCalls = ""
        for (i, char) in chars.enumerated() {
            svgBoxes += "<div class='char-box'><svg id='s\(i)' viewBox='0 0 1024 1024' width='140' height='140'></svg><p class='label'>\(char)</p></div>\n"
            fetchCalls += "drawChar('\(char)', 's\(i)');\n"
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body { background: #fff; display: flex; flex-wrap: wrap; justify-content: center; padding: 24px 16px; gap: 24px; }
            .char-box { text-align: center; }
            .label { margin-top: 8px; font-size: 16px; font-family: -apple-system, sans-serif; color: #444; }
            .outline { fill: none; stroke: #ddd; stroke-width: 40; stroke-linecap: round; stroke-linejoin: round; }
            .stroke  { fill: none; stroke: #e74c3c; stroke-width: 40; stroke-linecap: round; stroke-linejoin: round;
                       stroke-dasharray: 3000; stroke-dashoffset: 3000; }
            @keyframes draw { from { stroke-dashoffset: 3000; } to { stroke-dashoffset: 0; } }
          </style>
        </head>
        <body>
          \(svgBoxes)
          <script>
            function animateStrokes(els, n) {
              els.forEach(function(el) { el.style.animation = 'none'; });
              void els[0].offsetWidth;
              els.forEach(function(el, i) {
                el.style.animation = 'draw 0.8s ease ' + (i * 1.2) + 's forwards';
              });
              setTimeout(function() { animateStrokes(els, n); }, n * 1200 + 1500);
            }

            function drawChar(char, svgId) {
              fetch('https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/' + encodeURIComponent(char) + '.json')
                .then(function(r) { return r.json(); })
                .then(function(data) {
                  var svg = document.getElementById(svgId);
                  var g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
                  g.setAttribute('transform', 'scale(1,-1) translate(0,-900)');

                  data.strokes.forEach(function(path) {
                    var el = document.createElementNS('http://www.w3.org/2000/svg', 'path');
                    el.setAttribute('d', path);
                    el.setAttribute('class', 'outline');
                    g.appendChild(el);
                  });

                  var strokeEls = [];
                  data.strokes.forEach(function(path, i) {
                    var el = document.createElementNS('http://www.w3.org/2000/svg', 'path');
                    el.setAttribute('d', path);
                    el.setAttribute('class', 'stroke');
                    g.appendChild(el);
                    strokeEls.push(el);
                  });

                  svg.appendChild(g);
                  animateStrokes(strokeEls, data.strokes.length);
                });
            }

            \(fetchCalls)
          </script>
        </body>
        </html>
        """
    }

    private func cjkChars() -> [Character] {
        word.filter { c in
            let cp = c.unicodeScalars.first!.value
            return (0x4E00...0x9FFF).contains(cp) || (0x3400...0x4DBF).contains(cp)
        }
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
