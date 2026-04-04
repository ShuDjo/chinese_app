import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StrokeOrderView extends StatefulWidget {
  final String word;
  final String repeatLabel;

  const StrokeOrderView({
    super.key,
    required this.word,
    this.repeatLabel = 'Repeat',
  });

  @override
  State<StrokeOrderView> createState() => _StrokeOrderViewState();
}

class _StrokeOrderViewState extends State<StrokeOrderView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(_buildHtml());
  }

  @override
  void didUpdateWidget(StrokeOrderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word != widget.word || oldWidget.repeatLabel != widget.repeatLabel) {
      _controller.loadHtmlString(_buildHtml());
    }
  }

  String _buildHtml() {
    // Filter to CJK characters only
    final chars = widget.word.runes
        .where((cp) =>
            (cp >= 0x4E00 && cp <= 0x9FFF) || (cp >= 0x3400 && cp <= 0x4DBF))
        .map(String.fromCharCode)
        .toList();

    var charBoxes = '';
    var writerInits = '';
    for (var i = 0; i < chars.length; i++) {
      final char = chars[i];
      charBoxes += "<div class='char-box'><div id='s$i'></div><p class='label'>$char</p></div>\n";
      writerInits += """
        writers.push(HanziWriter.create('s$i', '$char', {
          width: 150, height: 150, padding: 8,
          strokeColor: '#C71414',
          outlineColor: '#CCCCCC',
          showCharacter: false,
          showOutline: true,
          strokeAnimationSpeed: 0.8,
          delayBetweenStrokes: 350,
        }));
        writers[$i].loopCharacterAnimation();
      """;
    }

    final repeatLabel = widget.repeatLabel;

    return '''
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
  $charBoxes
  </div>
  <button id="repeat-btn" onclick="repeatAll()">$repeatLabel</button>
  <script src="https://cdn.jsdelivr.net/npm/hanzi-writer@3.7.3/dist/hanzi-writer.min.js"></script>
  <script>
    var writers = [];
    $writerInits
    function repeatAll() {
      writers.forEach(function(w) { w.loopCharacterAnimation(); });
    }
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
