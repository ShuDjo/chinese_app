import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'utils/input_type.dart';

class ApiClient {
  static const String _base = 'https://chinese-app-a96d.onrender.com';

  // POST audio file to /transcribe
  Future<(TranscriptionResult?, String?)> transcribeAudio(String filePath) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_base/transcribe'));
      request.files.add(await http.MultipartFile.fromPath('file', filePath,
          filename: 'recording.m4a'));
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        return (null, 'Server error ${streamed.statusCode}: $body');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (TranscriptionResult.fromJson(json), null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  // POST text + words to /translate (saves to DB)
  Future<(String?, String?)> translateText(String text, List<WordResult> words) async {
    try {
      final resp = await http.post(
        Uri.parse('$_base/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'words': words.map((w) => w.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return (null, 'Server error ${resp.statusCode}');
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return (json['sentence_translation'] as String?, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  // POST /character/lookup — local DB only
  Future<(CharacterLookupResult?, String?)> lookupCharacter(String query,
      {InputType inputType = InputType.english}) async {
    try {
      final resp = await http.post(
        Uri.parse('$_base/character/lookup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'input_type': inputType.name}),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 404) return (null, 'not_in_dictionary');
      if (resp.statusCode != 200) return (null, 'Server error ${resp.statusCode}');
      return (CharacterLookupResult.fromJson(jsonDecode(resp.body) as Map<String, dynamic>), null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  // POST /character/ai-lookup — LLM fallback when not in DB
  Future<(CharacterLookupResult?, String?)> aiLookupCharacter(String query,
      {InputType inputType = InputType.english}) async {
    try {
      final resp = await http.post(
        Uri.parse('$_base/character/ai-lookup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query, 'input_type': inputType.name}),
      ).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return (null, 'Server error ${resp.statusCode}');
      return (CharacterLookupResult.fromJson(jsonDecode(resp.body) as Map<String, dynamic>), null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  // GET /character/random
  Future<(CharacterLookupResult?, String?)> fetchRandomFlashcard() async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/character/random'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return (null, 'Server error ${resp.statusCode}');
      return (CharacterLookupResult.fromJson(jsonDecode(resp.body) as Map<String, dynamic>), null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  // GET /quiz/lessons
  Future<(List<LessonInfo>, String?)> fetchLessons() async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/quiz/lessons'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return (<LessonInfo>[], 'Server error ${resp.statusCode}');
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final lessons = (json['lessons'] as List<dynamic>)
          .map((e) => LessonInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      return (lessons, null);
    } catch (e) {
      return (<LessonInfo>[], e.toString());
    }
  }

  // POST /quiz/start
  Future<(String?, String?)> startQuiz({
    required String topic,
    List<String>? sources,
  }) async {
    try {
      final body = <String, dynamic>{'topic': topic};
      if (sources != null) body['sources'] = sources;
      final resp = await http.post(
        Uri.parse('$_base/quiz/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        return (null, 'Server error ${resp.statusCode}: ${resp.body}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return (json['question'] as String?, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  // POST /quiz/next
  Future<(String?, String?)> nextQuestion({
    required String topic,
    required List<Map<String, String>> history,
    List<String>? sources,
  }) async {
    try {
      final body = <String, dynamic>{'topic': topic, 'history': history};
      if (sources != null) body['sources'] = sources;
      final resp = await http.post(
        Uri.parse('$_base/quiz/next'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) return (null, 'Server error ${resp.statusCode}');
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return (json['question'] as String?, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  // POST /quiz/finish
  Future<(SessionEvaluation?, String?)> finishQuiz({
    required String topic,
    required List<Map<String, String>> history,
    List<String>? sources,
    String language = 'en',
  }) async {
    try {
      final body = <String, dynamic>{
        'topic': topic,
        'history': history,
        'language': language,
      };
      if (sources != null) body['sources'] = sources;
      final resp = await http.post(
        Uri.parse('$_base/quiz/finish'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) return (null, 'Server error ${resp.statusCode}: ${resp.body}');
      return (SessionEvaluation.fromJson(jsonDecode(resp.body) as Map<String, dynamic>), null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  // POST audio to /quiz/transcribe
  Future<(String?, String?)> transcribeAnswer(String filePath) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$_base/quiz/transcribe'));
      request.files.add(await http.MultipartFile.fromPath('file', filePath,
          filename: 'answer.m4a'));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) return (null, 'Server error ${streamed.statusCode}');
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['text'] as String?, null);
    } catch (e) {
      return (null, e.toString());
    }
  }

  // POST /exam/hint
  Future<(String?, String?)> translateHint(String text) async {
    try {
      final resp = await http.post(
        Uri.parse('$_base/exam/hint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return (null, 'Server error ${resp.statusCode}');
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return (json['translation'] as String?, null);
    } catch (e) {
      return (null, e.toString());
    }
  }
}
