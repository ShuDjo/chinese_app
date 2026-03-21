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

// MARK: - Content View

enum InputMode { case mic, text }

struct ContentView: View {
    // Shared
    @State private var inputMode: InputMode = .mic
    @State private var isTranslating = false
    @State private var errorMessage: String?
    @State private var selectedWord: WordResult?

    // Mic mode
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var transcription: TranscriptionResult?
    @State private var sentenceTranslation: String?
    @State private var declinedWords: Set<String> = []

    // Text mode
    @State private var textQuery: String = ""
    @State private var isLookingUp = false
    @State private var lookupResult: CharacterLookupResult? = nil
    @State private var lookupSaved = false

    private let recorder = AudioRecorder()
    private let api = APIClient()

    var body: some View {
        ZStack(alignment: .top) {
            Theme.warmBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerView
                        .ignoresSafeArea(edges: .top)

                    // Main content
                    VStack(spacing: 20) {
                        // Info banner
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Theme.red)
                                .frame(width: 4)
                            HStack(spacing: 12) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(Theme.red)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Record, transcribe & build your vocabulary")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("Speak any Chinese sentence and get an instant word-by-word breakdown with translations and pinyin. Tap a word to watch its stroke order animation. Hit Accept & Save to add new words to your personal vocabulary.")
                                        .font(.footnote)
                                        .foregroundColor(.black)
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

                        // Input mode toggle
                        Picker("Input Mode", selection: $inputMode) {
                            Label("Mic", systemImage: "mic.fill").tag(InputMode.mic)
                            Label("Type", systemImage: "keyboard").tag(InputMode.text)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .onChange(of: inputMode) { _, mode in
                            errorMessage = nil
                            if mode == .mic {
                                textQuery = ""
                                lookupResult = nil
                                lookupSaved = false
                            } else {
                                withAnimation { transcription = nil }
                                sentenceTranslation = nil
                                declinedWords = []
                            }
                        }

                        if inputMode == .mic {
                            // ── Mic mode ──
                            recordButtonSection
                                .padding(.top, 8)

                            if isTranscribing {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text("Transcribing…")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                .transition(.opacity)
                            }

                            if let trans = transcription {
                                resultsCard(trans: trans)
                                    .padding(.horizontal, 16)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        } else {
                            // ── Text mode ──
                            textInputSection
                                .padding(.horizontal, 16)

                            if isLookingUp {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text("Looking up…")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                .transition(.opacity)
                            }

                            if let result = lookupResult {
                                lookupResultCard(result: result)
                                    .padding(.horizontal, 16)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }

                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.callout)
                                    .foregroundColor(.red)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }

                        Spacer(minLength: 40)
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: transcription == nil)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isTranscribing)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isLookingUp)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: lookupResult == nil)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: errorMessage)
                }
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $selectedWord) { word in
            strokeSheet(word: word)
        }
    }

    // MARK: - Text Input Section

    @FocusState private var textFieldFocused: Bool

    private var textInputSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("Type English or pinyin…", text: $textQuery)
                    .font(.callout)
                    .focused($textFieldFocused)
                    .onSubmit { performLookup() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)

                Button {
                    performLookup()
                } label: {
                    Text("Look Up")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            textQuery.trimmingCharacters(in: .whitespaces).isEmpty || isLookingUp
                                ? Color.gray.opacity(0.4) : Theme.red
                        )
                        .cornerRadius(10)
                }
                .disabled(textQuery.trimmingCharacters(in: .whitespaces).isEmpty || isLookingUp)
            }
        }
    }

    private func performLookup() {
        let query = textQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        textFieldFocused = false
        isLookingUp = true
        lookupResult = nil
        lookupSaved = false
        errorMessage = nil
        api.lookupCharacter(query) { result, err in
            DispatchQueue.main.async {
                isLookingUp = false
                if let err = err { errorMessage = err }
                withAnimation { lookupResult = result }
            }
        }
    }

    // MARK: - Lookup Result Card

    @ViewBuilder
    private func lookupResultCard(result: CharacterLookupResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    selectedWord = WordResult(
                        word: result.characters,
                        english: result.english,
                        pinyin: result.pinyin,
                        from_cache: false
                    )
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(result.characters)
                            .font(.system(size: 52, weight: .bold))
                            .foregroundColor(.black)
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.red.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)

                Text(result.pinyin)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Theme.red)

                Text(result.english)
                    .font(.callout)
                    .foregroundColor(Color.black.opacity(0.6))
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            if lookupSaved {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.jade)
                    Text("Added to vocabulary")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(Theme.jade)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else if isTranslating {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Saving…")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                Button {
                    saveLookupResult(result)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add to Vocabulary")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Theme.jade, Color(red: 0.10, green: 0.42, blue: 0.26)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    private func saveLookupResult(_ result: CharacterLookupResult) {
        let word = WordResult(
            word: result.characters,
            english: result.english,
            pinyin: result.pinyin,
            from_cache: false
        )
        isTranslating = true
        api.translateText(result.characters, words: [word]) { _, err in
            DispatchQueue.main.async {
                isTranslating = false
                if let err = err {
                    errorMessage = err
                } else {
                    withAnimation { lookupSaved = true }
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.red, Theme.red.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative watermark
            Text("中文")
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
                    Text("Speak. Transcribe. Learn.")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .padding(.trailing, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Record Button Section

    private var recordButtonSection: some View {
        VStack(spacing: 16) {
            PulsingRecordButton(
                isRecording: isRecording,
                isLoading: isTranscribing
            ) {
                if isRecording {
                    if let url = recorder.stopRecording() {
                        isRecording = false
                        isTranscribing = true
                        transcription = nil
                        sentenceTranslation = nil
                        errorMessage = nil
                        api.transcribeAudio(url: url) { res, err in
                            DispatchQueue.main.async {
                                isTranscribing = false
                                if let err = err { errorMessage = err }
                                withAnimation {
                                    transcription = res
                                }
                            }
                        }
                    }
                } else {
                    errorMessage = nil
                    withAnimation { transcription = nil }
                    sentenceTranslation = nil
                    declinedWords = []
                    recorder.startRecording()
                    isRecording = true
                }
            }

            Text(isTranscribing ? "Transcribing…" : isRecording ? "Tap to stop" : "Tap to record")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Results Card

    @ViewBuilder
    private func resultsCard(trans: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Chinese sentence + English translation
            VStack(alignment: .leading, spacing: 8) {
                Text(trans.chinese_transcription)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)

                if let sentence = sentenceTranslation {
                    Text(sentence)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(16)

            if !trans.words.isEmpty {
                Divider().padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Words — tap to see strokes")
                        .font(.caption)
                        .foregroundColor(Color.black.opacity(0.5))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    VStack(spacing: 8) {
                        ForEach(trans.words) { wordResult in
                            WordRowView(
                                word: wordResult,
                                isDeclined: declinedWords.contains(wordResult.word),
                                onDecline: wordResult.from_cache ? nil : {
                                    if declinedWords.contains(wordResult.word) {
                                        declinedWords.remove(wordResult.word)
                                    } else {
                                        declinedWords.insert(wordResult.word)
                                    }
                                }
                            ) {
                                selectedWord = wordResult
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }

            // Accept / Saving button — only shown when there are new words to save
            let wordsToSave = trans.words.filter { !$0.from_cache && !declinedWords.contains($0.word) }
            if sentenceTranslation == nil && !wordsToSave.isEmpty {
                Divider().padding(.horizontal, 16)
                VStack {
                    if isTranslating {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Saving…")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 14)
                    } else {
                        Button {
                            isTranslating = true
                            api.translateText(trans.chinese_transcription, words: wordsToSave) { sentence, err in
                                DispatchQueue.main.async {
                                    isTranslating = false
                                    if let err = err { errorMessage = err }
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        sentenceTranslation = sentence
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Accept & Save")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Theme.jade, Color(red: 0.10, green: 0.42, blue: 0.26)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    // MARK: - Stroke Sheet

    @ViewBuilder
    private func strokeSheet(word: WordResult) -> some View {
        VStack(spacing: 0) {
            // Sheet header
            ZStack {
                LinearGradient(
                    colors: [Theme.red, Theme.red.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.word)
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        Text(word.pinyin)
                            .foregroundColor(Color.white.opacity(0.8))
                        Text(word.english)
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    Spacer()
                    Button {
                        selectedWord = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(height: 110)

            StrokeOrderView(word: word.word)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .top)
    }
}
