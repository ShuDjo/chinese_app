import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../language_manager.dart';
import '../strings.dart';
import '../theme.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets/screen_header.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

enum SetupMode { random, lesson, topic }

class _ExamScreenState extends State<ExamScreen> {
  final _api = ApiClient();
  final _topicController = TextEditingController();
  final _tts = FlutterTts();
  final _recorder = AudioRecorder();

  // Setup
  SetupMode _setupMode = SetupMode.random;
  List<LessonInfo> _lessons = [];
  LessonInfo? _selectedLesson;
  bool _loadingLessons = false;

  // Session
  bool _sessionActive = false;
  bool _sessionEnded = false;
  String _topic = '';
  List<String>? _sources;
  String _currentQuestion = '';
  List<Map<String, String>> _history = [];
  String _pendingAnswer = '';

  // Loading
  bool _loadingQuestion = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isEvaluating = false;

  // Reaction (examiner acknowledgment before next question)
  String _reaction = '';

  // Hint
  bool _hintVisible = false;
  String _hintTranslation = '';
  bool _loadingHint = false;

  // Results
  SessionEvaluation? _evaluation;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLessons();
    _tts.setLanguage('zh-CN');
    _tts.setSpeechRate(0.35);
    _tts.setVolume(1.0);
  }

  @override
  void dispose() {
    _topicController.dispose();
    _tts.stop();
    _recorder.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatLessonName(String source) {
    return source
        .replaceAll('.pdf', '')
        .replaceAllMapped(RegExp(r'course(\d+)', caseSensitive: false),
            (m) => 'Course ${m[1]}')
        .replaceAll('_', ' · Lesson ');
  }

  void _speak(String text) {
    _tts.stop();
    _tts.speak(text);
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _fetchLessons() async {
    if (_lessons.isNotEmpty) return;
    setState(() => _loadingLessons = true);
    final (lessons, _) = await _api.fetchLessons();
    setState(() {
      _loadingLessons = false;
      _lessons = lessons;
    });
  }

  void _pickRandom() {
    if (_lessons.isEmpty) return;
    final lesson = _lessons[Random().nextInt(_lessons.length)];
    setState(() {
      _setupMode = SetupMode.random;
      _selectedLesson = null;
      _topicController.text = _formatLessonName(lesson.source);
      _sources = [lesson.source];
    });
  }

  void _pickLesson(LessonInfo lesson) {
    setState(() {
      _selectedLesson = lesson;
      _sources = [lesson.source];
      _topicController.text = _formatLessonName(lesson.source);
    });
  }

  // ── Session lifecycle ──────────────────────────────────────────────────────

  Future<void> _beginSession() async {
    final s = context.read<LanguageManager>().s;
    String topic;
    List<String>? sources;

    switch (_setupMode) {
      case SetupMode.random:
        if (_lessons.isEmpty) {
          topic = 'general Chinese';
        } else {
          final pick = _lessons[Random().nextInt(_lessons.length)];
          sources = [pick.source];
          topic = _formatLessonName(pick.source);
        }
      case SetupMode.lesson:
        if (_selectedLesson == null) {
          setState(() => _error = s.examErrorSelectLesson);
          return;
        }
        sources = [_selectedLesson!.source];
        topic = _formatLessonName(_selectedLesson!.source);
      case SetupMode.topic:
        final t = _topicController.text.trim();
        if (t.isEmpty) {
          setState(() => _error = s.examErrorEnterTopic);
          return;
        }
        topic = t;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _topic = topic;
      _sources = sources;
      _loadingQuestion = true;
      _history = [];
      _currentQuestion = '';
      _error = null;
      _sessionEnded = false;
    });

    final (question, err) = await _api.startQuiz(topic: topic, sources: sources);
    if (!mounted) return;
    setState(() {
      _loadingQuestion = false;
      if (err != null) {
        _error = err;
      } else {
        _currentQuestion = question ?? '';
        _sessionActive = true;
      }
    });
    if (err == null && _currentQuestion.isNotEmpty) _speak(_currentQuestion);
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _error = context.read<LanguageManager>().s.micPermissionDenied);
      return;
    }
    await _tts.stop();
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/exam_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() { _isRecording = true; _pendingAnswer = ''; _error = null; });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() { _isRecording = false; _isTranscribing = true; });
    if (path == null) { setState(() => _isTranscribing = false); return; }

    final (text, err) = await _api.transcribeAnswer(path);
    if (!mounted) return;
    setState(() { _isTranscribing = false; });

    if (err != null || text == null || text.isEmpty) {
      setState(() => _error = err ?? context.read<LanguageManager>().s.noAnswerTranscribed);
      return;
    }

    // Auto-submit: save to history, clear question, load next
    final answeredQ = _currentQuestion;
    setState(() {
      _pendingAnswer = text;
      _history.add({'question': answeredQ, 'answer': text});
      _currentQuestion = '';
      _hintVisible = false;
      _hintTranslation = '';
      _loadingQuestion = true;
    });

    final (nextQ, reaction, nextErr) = await _api.nextQuestion(
        topic: _topic, history: _history, sources: _sources);
    if (!mounted || _sessionEnded) return;

    setState(() {
      _loadingQuestion = false;
      _pendingAnswer = '';
      if (nextErr != null) {
        _error = nextErr;
        _reaction = '';
      } else if (nextQ == null || nextQ.isEmpty) {
        _endSession();
        return;
      } else {
        _currentQuestion = nextQ;
        _reaction = reaction ?? '';
      }
    });
    if (nextErr == null && _currentQuestion.isNotEmpty) {
      if (_reaction.isNotEmpty) {
        await _tts.speak(_reaction);
        await Future.delayed(const Duration(milliseconds: 900));
      }
      _speak(_currentQuestion);
    }
  }

  Future<void> _loadHint() async {
    if (_currentQuestion.isEmpty || _loadingHint) return;
    if (_hintTranslation.isNotEmpty) { setState(() => _hintVisible = true); return; }
    setState(() => _loadingHint = true);
    final (translation, _) = await _api.translateHint(_currentQuestion);
    setState(() {
      _loadingHint = false;
      if (translation != null) { _hintTranslation = translation; _hintVisible = true; }
    });
  }

  Future<void> _endSession() async {
    setState(() { _sessionEnded = true; });
    if (_isRecording) {
      await _recorder.stop();
      setState(() => _isRecording = false);
    }
    await _tts.stop();
    setState(() { _loadingQuestion = false; _currentQuestion = ''; });
    if (_history.isEmpty) { setState(() { _sessionActive = false; _sessionEnded = false; }); return; }

    setState(() => _isEvaluating = true);
    final lang = context.read<LanguageManager>();
    final (eval, err) = await _api.finishQuiz(
        topic: _topic, history: _history, sources: _sources, language: lang.languageCode);
    setState(() {
      _isEvaluating = false;
      if (err != null) { _error = err; _sessionEnded = false; }
      else { _evaluation = eval; }
    });
  }

  void _resetSession() {
    setState(() {
      _setupMode = SetupMode.random;
      _selectedLesson = null;
      _sources = null;
      _topic = '';
      _topicController.clear();
      _sessionActive = false;
      _sessionEnded = false;
      _currentQuestion = '';
      _history = [];
      _pendingAnswer = '';
      _evaluation = null;
      _error = null;
      _hintVisible = false;
      _hintTranslation = '';
      _reaction = '';
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageManager>().s;
    if (_evaluation != null) return _buildResults(s);
    if (_sessionActive || _loadingQuestion) return _buildSession(s);
    return _buildSetup(s);
  }

  // ── Setup ──────────────────────────────────────────────────────────────────

  Widget _buildSetup(AppStrings s) {
    return Column(
      children: [
        ScreenHeader(subtitle: s.tabExam),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Option 1: Random
                _OptionCard(
                  selected: _setupMode == SetupMode.random,
                  onTap: () {
                    setState(() { _setupMode = SetupMode.random; _error = null; });
                    _pickRandom();
                  },
                  icon: Icons.shuffle_rounded,
                  title: s.examRandomLesson,
                  subtitle: _lessons.isEmpty && !_loadingLessons
                      ? s.examRandomSubtitleEmpty
                      : s.examRandomSubtitle,
                  child: _loadingLessons
                      ? const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(color: AppTheme.red),
                        )
                      : null,
                ),
                const SizedBox(height: 12),

                // Option 2: Choose lesson
                _OptionCard(
                  selected: _setupMode == SetupMode.lesson,
                  onTap: () => setState(() { _setupMode = SetupMode.lesson; _error = null; }),
                  icon: Icons.list_alt_rounded,
                  title: s.examChooseLesson,
                  subtitle: s.examChooseSubtitle,
                  child: _setupMode == SetupMode.lesson
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _loadingLessons
                              ? const LinearProgressIndicator(color: AppTheme.red)
                              : _lessons.isEmpty
                                  ? Text(s.examNoLessons,
                                        style: const TextStyle(fontSize: 13, color: Colors.grey))
                                  : Column(
                                      children: _lessons.map((l) {
                                        final selected = _selectedLesson?.source == l.source;
                                        return GestureDetector(
                                          onTap: () => _pickLesson(l),
                                          child: Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(bottom: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: selected ? AppTheme.red : const Color(0xFFF2F2F7),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(children: [
                                              Expanded(child: Text(_formatLessonName(l.source),
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      color: selected ? Colors.white : Colors.black87))),
                                              if (selected)
                                                const Icon(Icons.check, size: 16, color: Colors.white),
                                            ]),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),

                // Option 3: Custom topic
                _OptionCard(
                  selected: _setupMode == SetupMode.topic,
                  onTap: () => setState(() { _setupMode = SetupMode.topic; _error = null; }),
                  icon: Icons.edit_rounded,
                  title: s.examEnterTopic,
                  subtitle: s.examEnterTopicSubtitle,
                  child: _setupMode == SetupMode.topic
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextField(
                            controller: _topicController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: s.topicPlaceholder,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none),
                              filled: true,
                              fillColor: const Color(0xFFF2F2F7),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            textInputAction: TextInputAction.done,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 24),

                if (_error != null) ...[
                  _buildErrorCard(_error!),
                  const SizedBox(height: 16),
                ],

                SizedBox(
                  width: double.infinity,
                  child: _loadingQuestion
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                              color: AppTheme.red.withAlpha(30),
                              borderRadius: BorderRadius.circular(14)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.red)),
                            const SizedBox(width: 10),
                            Text(s.examPreparingQuestion,
                                style: const TextStyle(color: AppTheme.red)),
                          ]))
                      : ElevatedButton(
                          onPressed: _beginSession,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(s.beginExam,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Session ────────────────────────────────────────────────────────────────

  Widget _buildSession(AppStrings s) {
    return Scaffold(
      backgroundColor: AppTheme.warmBg,
      body: Column(
        children: [
          // Topic bar
          SafeArea(
            bottom: false,
            child: Container(
              color: AppTheme.warmBg,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.examTopicLabel,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(_topic,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: AppTheme.red, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Q${_history.length + 1}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.red)),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                // History
                ..._history.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Q${i + 1}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item['question'] ?? '',
                            style: const TextStyle(fontSize: 13, color: Colors.black54)),
                        const SizedBox(height: 3),
                        Text(item['answer'] ?? '',
                            style: const TextStyle(
                                fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87)),
                      ])),
                    ]),
                  );
                }),

                // Loading question
                if (_loadingQuestion)
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: AppTheme.cardDecoration,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.red)),
                      const SizedBox(width: 10),
                      Text(s.loadingQuestion, style: const TextStyle(color: Colors.grey)),
                    ]),
                  ),

                // Current question card
                if (!_loadingQuestion && _currentQuestion.isNotEmpty) ...[
                  if (_reaction.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.red.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_reaction,
                          style: const TextStyle(
                              fontSize: 15, color: AppTheme.red, fontStyle: FontStyle.italic)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: AppTheme.cardDecoration,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(s.examQuestionLabel,
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _speak(_currentQuestion),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.red.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.volume_up_rounded, size: 18, color: AppTheme.red),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text(_currentQuestion,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold, height: 1.4)),
                    ]),
                  ),

                  // Hint
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (_loadingHint)
                      const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                    else if (_hintVisible && _hintTranslation.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _hintVisible = false),
                        child: Text(s.examHideTranslation,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.orange,
                                decoration: TextDecoration.underline)),
                      )
                    else
                      GestureDetector(
                        onTap: _loadHint,
                        child: Text(s.examRevealTranslation,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.orange,
                                decoration: TextDecoration.underline)),
                      ),
                  ]),

                  if (_hintVisible && _hintTranslation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.lightbulb_rounded, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_hintTranslation,
                            style: const TextStyle(fontSize: 14, color: Colors.black87))),
                      ]),
                    ),
                  ],
                ],

                // Pending answer
                if (_pendingAnswer.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3280FF).withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.examYourAnswer,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(_pendingAnswer, style: const TextStyle(fontSize: 15)),
                    ]),
                  ),
                ],

                // Transcribing indicator
                if (_isTranscribing) ...[
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.red)),
                    const SizedBox(width: 8),
                    Text(s.transcribing, style: const TextStyle(color: Colors.grey)),
                  ]),
                ],

                // Mic button
                if (!_loadingQuestion && !_isTranscribing && _currentQuestion.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: Column(children: [
                      GestureDetector(
                        onTap: _isRecording ? _stopRecording : _startRecording,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording ? Colors.red.shade700 : AppTheme.red,
                            boxShadow: [BoxShadow(
                              color: AppTheme.red.withAlpha(_isRecording ? 120 : 60),
                              blurRadius: _isRecording ? 24 : 12,
                              spreadRadius: _isRecording ? 4 : 0,
                            )],
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white, size: 38),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(_isRecording ? s.tapToStop : s.tapToRecord,
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ]),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorCard(_error!),
                ],
              ],
            ),
          ),
        ],
      ),

      // Sticky bottom: Stop & Evaluate
      bottomNavigationBar: Container(
        color: AppTheme.warmBg,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _isEvaluating
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                      const SizedBox(width: 10),
                      Text(s.examEvaluatingSession,
                          style: const TextStyle(color: Colors.grey)),
                    ]),
                  )
                : ElevatedButton.icon(
                    onPressed: _endSession,
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(s.examStopAndEvaluate,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Results ────────────────────────────────────────────────────────────────

  Widget _buildResults(AppStrings s) {
    final eval = _evaluation!;
    return Scaffold(
      backgroundColor: AppTheme.warmBg,
      body: ListView(
        children: [
          // Header
          Container(
            height: 110 + MediaQuery.of(context).padding.top,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.red, Color(0xFFB71010)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: SafeArea(
              bottom: false,
              child: Text(s.examComplete,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),

          // Score ring
          Padding(
            padding: const EdgeInsets.only(top: 28, bottom: 8),
            child: Center(
              child: SizedBox(
                width: 140, height: 140,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: eval.overallScore / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade200,
                    color: _scoreColor(eval.overallScore),
                  ),
                  Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${eval.overallScore}',
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                            color: _scoreColor(eval.overallScore))),
                    const Text('/ 100', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                ]),
              ),
            ),
          ),
          Center(child: Text(s.overallScore,
              style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const SizedBox(height: 20),

          // Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(eval.summary,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black54, height: 1.5)),
          ),
          const SizedBox(height: 20),

          // Strengths
          if (eval.strengths.isNotEmpty)
            _resultSection(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: AppTheme.jade.withAlpha(20),
              icon: Icons.star_rounded,
              iconColor: AppTheme.jade,
              title: s.strengths,
              children: eval.strengths.map((str) =>
                  _bulletRow(str, AppTheme.jade)).toList(),
            ),
          const SizedBox(height: 12),

          // Improvements
          if (eval.improvements.isNotEmpty)
            _resultSection(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.orange.withAlpha(20),
              icon: Icons.arrow_upward_rounded,
              iconColor: Colors.orange,
              title: s.improvements,
              children: eval.improvements.map((imp) =>
                  _bulletRow(imp, Colors.orange)).toList(),
            ),
          const SizedBox(height: 12),

          // Mistakes only
          () {
            final mistakes = eval.exchanges.where((ex) =>
                ex.mistake != null && ex.mistake!.isNotEmpty).toList();
            if (mistakes.isEmpty) return const SizedBox.shrink();
            return _resultSection(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.red.withAlpha(15),
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.red,
              title: s.examMistakes,
              children: mistakes.map((ex) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(ex.question,
                        style: const TextStyle(fontSize: 13, color: Colors.black54))),
                    Text('${ex.score}/100',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: _scoreColor(ex.score))),
                  ]),
                  const SizedBox(height: 4),
                  Text(ex.answer,
                      style: const TextStyle(
                          fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text(ex.mistake!,
                      style: const TextStyle(fontSize: 13, color: Colors.red)),
                ]),
              )).toList(),
            );
          }(),
          const SizedBox(height: 20),

          // New session button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: ElevatedButton.icon(
              onPressed: _resetSession,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(s.examNewSession,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3280FF),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Color _scoreColor(int score) {
    if (score >= 80) return AppTheme.jade;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _bulletRow(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ]),
    );
  }

  Widget _resultSection({
    required EdgeInsets padding,
    required Color color,
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: iconColor)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0x14FF0000), borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 14))),
      ]),
    );
  }
}

// ── Option Card ───────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? child;

  const _OptionCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppTheme.red : Colors.transparent, width: 2),
          boxShadow: [BoxShadow(
            color: selected ? AppTheme.red.withAlpha(40) : const Color(0x11000000),
            blurRadius: selected ? 12 : 8,
            offset: const Offset(0, 3),
          )],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.red : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: selected ? Colors.white : Colors.grey, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16,
                    color: selected ? AppTheme.red : Colors.black87)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ])),
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? AppTheme.red : Colors.grey.shade300),
            ]),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}
