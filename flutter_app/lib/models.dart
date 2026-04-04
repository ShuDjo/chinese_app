class WordResult {
  final String word;
  final String english;
  final String pinyin;
  final bool fromCache;

  WordResult({
    required this.word,
    required this.english,
    required this.pinyin,
    this.fromCache = false,
  });

  factory WordResult.fromJson(Map<String, dynamic> json) => WordResult(
        word: json['word'] as String,
        english: json['english'] as String? ?? '',
        pinyin: json['pinyin'] as String? ?? '',
        fromCache: json['from_cache'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'english': english,
        'pinyin': pinyin,
      };
}

class TranscriptionResult {
  final String chineseTranscription;
  final List<WordResult> words;
  final String? error;

  TranscriptionResult({
    required this.chineseTranscription,
    required this.words,
    this.error,
  });

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) =>
      TranscriptionResult(
        chineseTranscription: json['chinese_transcription'] as String? ?? '',
        words: (json['words'] as List<dynamic>? ?? [])
            .map((e) => WordResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        error: json['error'] as String?,
      );
}

class CharacterLookupResult {
  final String characters;
  final String pinyin;
  final String english;
  final String? serbian;

  CharacterLookupResult({
    required this.characters,
    required this.pinyin,
    required this.english,
    this.serbian,
  });

  factory CharacterLookupResult.fromJson(Map<String, dynamic> json) =>
      CharacterLookupResult(
        characters: json['characters'] as String,
        pinyin: json['pinyin'] as String? ?? '',
        english: json['english'] as String? ?? '',
        serbian: json['serbian'] as String?,
      );
}

class LessonInfo {
  final String source;
  final String addedAt;

  LessonInfo({required this.source, required this.addedAt});

  factory LessonInfo.fromJson(Map<String, dynamic> json) => LessonInfo(
        source: json['source'] as String,
        addedAt: json['added_at'] as String? ?? '',
      );
}

class ExchangeFeedback {
  final String question;
  final String answer;
  final int score;
  final String? mistake;

  ExchangeFeedback({
    required this.question,
    required this.answer,
    required this.score,
    this.mistake,
  });

  factory ExchangeFeedback.fromJson(Map<String, dynamic> json) =>
      ExchangeFeedback(
        question: json['question'] as String,
        answer: json['answer'] as String,
        score: json['score'] as int? ?? 0,
        mistake: json['mistake'] as String?,
      );
}

class SessionEvaluation {
  final int overallScore;
  final String summary;
  final List<String> strengths;
  final List<String> improvements;
  final List<ExchangeFeedback> exchanges;

  SessionEvaluation({
    required this.overallScore,
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.exchanges,
  });

  factory SessionEvaluation.fromJson(Map<String, dynamic> json) =>
      SessionEvaluation(
        overallScore: json['overall_score'] as int? ?? 0,
        summary: json['summary'] as String? ?? '',
        strengths: (json['strengths'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        improvements: (json['improvements'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        exchanges: (json['exchanges'] as List<dynamic>? ?? [])
            .map((e) => ExchangeFeedback.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
