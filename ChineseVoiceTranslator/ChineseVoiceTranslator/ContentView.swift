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
            body { background: #fff; display: flex; flex-direction: column; align-items: center; padding: 24px 16px; gap: 24px; }
            #chars { display: flex; flex-wrap: wrap; justify-content: center; gap: 24px; }
            .char-box { text-align: center; }
            .label { margin-top: 8px; font-size: 16px; font-family: -apple-system, sans-serif; color: #444; }
            .outline { fill: none; stroke: #ddd; stroke-width: 40; stroke-linecap: round; stroke-linejoin: round; }
            .stroke  { fill: none; stroke: #e74c3c; stroke-width: 40; stroke-linecap: round; stroke-linejoin: round;
                       stroke-dasharray: 3000; stroke-dashoffset: 3000; }
            @keyframes draw { from { stroke-dashoffset: 3000; } to { stroke-dashoffset: 0; } }
            #repeat-btn {
              padding: 10px 32px; font-size: 16px;
              font-family: -apple-system, sans-serif;
              background: #007AFF; color: #fff;
              border: none; border-radius: 20px; cursor: pointer;
            }
          </style>
        </head>
        <body>
          <div id="chars">
          \(svgBoxes)
          </div>
          <button id="repeat-btn" onclick="repeatAll()">Repeat</button>
          <script>
            var allGroups = [];
            var allTimers = [];

            function animateStrokes(els, n) {
              els.forEach(function(el) {
                el.style.animation = 'none';
                el.style.strokeDashoffset = '3000';
              });
              requestAnimationFrame(function() {
                requestAnimationFrame(function() {
                  els.forEach(function(el, i) {
                    el.style.strokeDashoffset = '';
                    el.style.animation = 'draw 0.8s ease ' + (i * 1.2) + 's forwards';
                  });
                  var t = setTimeout(function() { animateStrokes(els, n); }, n * 1200 + 1500);
                  allTimers.push(t);
                });
              });
            }

            function repeatAll() {
              allTimers.forEach(function(t) { clearTimeout(t); });
              allTimers = [];
              allGroups.forEach(function(g) { animateStrokes(g.els, g.n); });
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
                  allGroups.push({ els: strokeEls, n: data.strokes.length });
                  animateStrokes(strokeEls, data.strokes.length, false);
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

// MARK: - Word Sheet Item

struct WordSheetItem: Identifiable {
    let word: String
    let pinyin: String?
    let english: String?
    var id: String { word }
}

// MARK: - Content View

struct ContentView: View {
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var isTranslating = false
    @State private var transcription: TranscriptionResult?
    @State private var result: TranslationResult?
    @State private var errorMessage: String?
    @State private var selectedWord: WordSheetItem?

    private let recorder = AudioRecorder()
    private let api = APIClient()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Chinese Voice Translator")
                    .font(.title2)
                    .padding()

                // Record button
                Button(isRecording ? "Stop Recording" : "Start Recording") {
                    if isRecording {
                        if let url = recorder.stopRecording() {
                            isRecording = false
                            isTranscribing = true
                            transcription = nil
                            result = nil
                            errorMessage = nil
                            api.transcribeAudio(url: url) { res, err in
                                DispatchQueue.main.async {
                                    isTranscribing = false
                                    if let err = err { errorMessage = err }
                                    transcription = res
                                }
                            }
                        }
                    } else {
                        errorMessage = nil
                        transcription = nil
                        result = nil
                        recorder.startRecording()
                        isRecording = true
                    }
                }
                .padding()
                .background(isRecording ? Color.red : Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())

                if isTranscribing {
                    ProgressView("Transcribing...")
                }

                // ── Transcribed, awaiting Accept ──────────────────────────
                if let trans = transcription, result == nil {
                    VStack(alignment: .leading, spacing: 16) {
                        Divider()

                        Text(trans.chinese_transcription)
                            .font(.title3)

                        if !trans.words.isEmpty {
                            Text("Tap a word to see strokes")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(trans.words, id: \.self) { word in
                                Text(word)
                                    .font(.callout)
                                    .bold()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedWord = WordSheetItem(word: word, pinyin: nil, english: nil)
                                    }
                            }
                        }

                        Divider()

                        if isTranslating {
                            ProgressView("Saving...")
                        } else {
                            Button("Accept") {
                                isTranslating = true
                                api.translateText(trans.chinese_transcription) { res, err in
                                    DispatchQueue.main.async {
                                        isTranslating = false
                                        if let err = err { errorMessage = err }
                                        result = res
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                    }
                    .padding()
                }

                // ── Accepted: full translation result ─────────────────────
                if let result = result {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()

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
                                .onTapGesture {
                                    selectedWord = WordSheetItem(
                                        word: wordResult.word,
                                        pinyin: wordResult.pinyin,
                                        english: wordResult.english
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                }

                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer()
            }
        }
        .sheet(item: $selectedWord) { item in
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.word)
                            .font(.largeTitle)
                            .bold()
                        if let pinyin = item.pinyin {
                            Text(pinyin)
                                .foregroundColor(.secondary)
                        }
                        if let english = item.english {
                            Text(english)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button("Done") { selectedWord = nil }
                        .padding(.leading)
                }
                .padding()

                Divider()

                StrokeOrderView(word: item.word)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
