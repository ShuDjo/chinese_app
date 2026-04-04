import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
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

enum ExamPhase { setup, quiz, evaluating, result }
enum SetupMode { random, lesson, topic }

class _ExamScreenState extends State<ExamScreen> {
  final _api = ApiClient();
  final _topicController = TextEditingController();
  final _answerController = TextEditingController();
  final _tts = FlutterTts();
  final _recorder = AudioRecorder();

  ExamPhase _phase = ExamPhase.setup;
  SetupMode _setupMode = SetupMode.random;

  List<LessonInfo> _lessons = [];
  LessonInfo? _selectedLesson;
  bool _loadingLessons = false;

  String _currentQuestion = '';
  String _activeTopic = '';
  List<String>? _activeSources;
  List<Map<String, String>> _history = [];
  bool _loadingQuestion = false;
  bool _submitting = false;

  bool _isRecording = false;
  bool _transcribing = false;
  String? _transcribedAnswer;

  SessionEvaluation? _evaluation;
  String? _error;
  String? _hintTranslation;
  bool _loadingHint = false;

  @override
  void initState() {
    super.initState();
    _fetchLessons();
    _tts.setLanguage('zh-CN');
    _tts.setSpeechRate(0.45);
  }

  @override
  void dispose() {
    _topicController.dispose();
    _answerController.dispose();
    _tts.stop();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _speakQuestion() async {
    if (_currentQuestion.isNotEmpty) {
      await _tts.stop();
      await _tts.speak(_currentQuestion);
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/exam_answer_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() { _isRecording = true; _transcribedAnswer = null; _error = null; });
  }

  Future<void> _stopAndTranscribe() async {
    final path = await _recorder.stop();
    setState(() { _isRecording = false; _transcribing = true; });
    if (path == null) { setState(() => _transcribing = false); return; }
    final (text, err) = await _api.transcribeAnswer(path);
    setState(() {
      _transcribing = false;
      if (err != null) _error = err;
      else _transcribedAnswer = text ?? '';
    });
  }

  Future<void> _fetchLessons() async {
    setState(() => _loadingLessons = true);
    final (lessons, err) = await _api.fetchLessons();
    setState(() {
      _loadingLessons = false;
      _lessons = lessons;
      if (err != null) _error = err;
    });
  }

  Future<void> _beginExam() async {
    String topic;
    List<String>? sources;

    switch (_setupMode) {
      case SetupMode.random:
        if (_lessons.isEmpty) {
          topic = 'general Chinese'; // internal backend value, not displayed
        } else {
          final pick = _lessons[Random().nextInt(_lessons.length)];
          sources = [pick.source];
          topic = pick.source;
        }
      case SetupMode.lesson:
        if (_selectedLesson == null) {
          setState(() => _error = context.read<LanguageManager>().s.examErrorSelectLesson);
          return;
        }
        sources = [_selectedLesson!.source];
        topic = _selectedLesson!.source;
      case SetupMode.topic:
        final t = _topicController.text.trim();
        if (t.isEmpty) {
          setState(() => _error = context.read<LanguageManager>().s.examErrorEnterTopic);
          return;
        }
        topic = t;
    }

    FocusScope.of(context).unfocus();
    _activeTopic = topic;
    _activeSources = sources;

    setState(() {
      _phase = ExamPhase.quiz;
      _loadingQuestion = true;
      _history = [];
      _currentQuestion = '';
      _error = null;
      _hintTranslation = null;
    });

    final (question, err) =
        await _api.startQuiz(topic: topic, sources: sources);
    setState(() {
      _loadingQuestion = false;
      if (err != null) {
        _error = err;
        _phase = ExamPhase.setup;
      } else {
        _currentQuestion = question ?? '';
      }
    });
    if (err == null) _speakQuestion();
  }

  Future<void> _submitAnswer() async {
    final answer = (_transcribedAnswer?.isNotEmpty == true)
        ? _transcribedAnswer!
        : _answerController.text.trim();
    if (answer.isEmpty) return;
    FocusScope.of(context).unfocus();
    _history.add({'question': _currentQuestion, 'answer': answer});
    _answerController.clear();
    setState(() { _submitting = true; _hintTranslation = null; _transcribedAnswer = null; });

    final (question, err) = await _api.nextQuestion(
        topic: _activeTopic, history: _history, sources: _activeSources);
    setState(() {
      _submitting = false;
      if (err != null) {
        _error = err;
      } else if (question == null || question.isEmpty) {
        _endSession();
        return;
      } else {
        _currentQuestion = question;
      }
    });
    if (err == null && (question?.isNotEmpty ?? false)) _speakQuestion();
  }

  Future<void> _endSession() async {
    setState(() => _phase = ExamPhase.evaluating);
    final lang = context.read<LanguageManager>();
    final (eval, err) = await _api.finishQuiz(
        topic: _activeTopic,
        history: _history,
        sources: _activeSources,
        language: lang.languageCode);
    setState(() {
      if (err != null) {
        _error = err;
        _phase = ExamPhase.quiz;
      } else {
        _evaluation = eval;
        _phase = ExamPhase.result;
      }
    });
  }

  Future<void> _loadHint() async {
    setState(() => _loadingHint = true);
    final (translation, _) = await _api.translateHint(_currentQuestion);
    setState(() { _loadingHint = false; _hintTranslation = translation; });
  }

  void _startOver() {
    setState(() {
      _phase = ExamPhase.setup;
      _history = [];
      _currentQuestion = '';
      _evaluation = null;
      _error = null;
      _hintTranslation = null;
      _activeTopic = '';
      _activeSources = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageManager>().s;
    return Scaffold(
      backgroundColor: AppTheme.warmBg,
      body: switch (_phase) {
        ExamPhase.setup     => _buildSetup(s),
        ExamPhase.quiz      => _buildQuiz(s),
        ExamPhase.evaluating => _buildEvaluating(s),
        ExamPhase.result    => _buildResult(s),
      },
    );
  }

  // ── Setup ────────────────────────────────────────────────────────────────────

  Widget _buildSetup(AppStrings s) {
    return Column(
      children: [
        ScreenHeader(subtitle: s.examSubtitle),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Option 1: Random ──────────────────────────────────────
                _OptionCard(
                  selected: _setupMode == SetupMode.random,
                  onTap: () => setState(() { _setupMode = SetupMode.random; _error = null; }),
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

                // ── Option 2: Choose lesson ───────────────────────────────
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
                                  : DropdownButtonFormField<LessonInfo>(
                                      value: _selectedLesson,
                                      hint: Text(s.examSelectLesson, style: const TextStyle(fontSize: 14)),
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: BorderSide.none),
                                        filled: true,
                                        fillColor: const Color(0xFFF2F2F7),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                      ),
                                      items: _lessons.map((l) => DropdownMenuItem(
                                        value: l,
                                        child: Text(l.source,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 14)),
                                      )).toList(),
                                      onChanged: (v) => setState(() => _selectedLesson = v),
                                    ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),

                // ── Option 3: Enter topic ─────────────────────────────────
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

                // ── Begin button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _beginExam,
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

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorCard(_error!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Quiz ─────────────────────────────────────────────────────────────────────

  Widget _buildQuiz(AppStrings s) {
    final busy = _loadingQuestion || _submitting;
    return Scaffold(
      backgroundColor: AppTheme.warmBg,
      appBar: AppBar(
        title: Text(_activeTopic,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.warmBg,
        actions: [
          TextButton(
            onPressed: _endSession,
            child: Text(s.endSession, style: const TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Question card ─────────────────────────────────────────────
          Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Q${_history.length + 1}',
                        style: const TextStyle(color: AppTheme.red, fontWeight: FontWeight.w700, fontSize: 12)),
                    if (!busy && _currentQuestion.isNotEmpty)
                      GestureDetector(
                        onTap: _speakQuestion,
                        child: const Icon(Icons.volume_up_rounded, color: AppTheme.red, size: 22),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (busy)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.red)),
                    const SizedBox(width: 10),
                    Text(s.loadingQuestion, style: const TextStyle(color: Colors.grey)),
                  ])
                else
                  Text(_currentQuestion,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, height: 1.4)),
                if (!busy) ...[
                  const SizedBox(height: 16),
                  if (_loadingHint)
                    const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey))
                  else if (_hintTranslation != null)
                    Text(_hintTranslation!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic))
                  else
                    GestureDetector(
                      onTap: _loadHint,
                      child: Text(s.hint,
                          style: const TextStyle(
                              color: AppTheme.red, decoration: TextDecoration.underline, fontSize: 13)),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Record button ─────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: busy ? null : (_isRecording ? _stopAndTranscribe : _startRecording),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red.shade700 : AppTheme.red,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.red.withAlpha(_isRecording ? 100 : 50),
                          blurRadius: _isRecording ? 20 : 10,
                          spreadRadius: _isRecording ? 4 : 0,
                        ),
                      ],
                    ),
                    child: _transcribing
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isRecording
                      ? s.tapToStop
                      : _transcribing
                          ? s.transcribing
                          : s.tapToRecord,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Answer area ───────────────────────────────────────────────
          Container(
            decoration: AppTheme.cardDecoration,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_transcribedAnswer != null && _transcribedAnswer!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.red.withAlpha(60)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.transcribed, style: const TextStyle(fontSize: 11, color: AppTheme.red, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(_transcribedAnswer!, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => setState(() => _transcribedAnswer = null),
                          child: Text(s.clearAndType,
                              style: const TextStyle(fontSize: 12, color: Colors.grey,
                                  decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  TextField(
                    controller: _answerController,
                    decoration: InputDecoration(
                      hintText: s.typeYourAnswer,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      filled: true, fillColor: const Color(0xFFF2F2F7),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    maxLines: 3, minLines: 1,
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (busy || _isRecording || _transcribing) ? null : _submitAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.red, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(s.submit),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[const SizedBox(height: 16), _buildErrorCard(_error!)],

          // ── History ───────────────────────────────────────────────────
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 24),
            ..._history.reversed.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: AppTheme.cardDecoration,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['question'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(item['answer'] ?? '',
                        style: const TextStyle(color: Colors.black54, fontSize: 14)),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  // ── Evaluating ───────────────────────────────────────────────────────────────

  Widget _buildEvaluating(AppStrings s) {
    return Scaffold(
      backgroundColor: AppTheme.warmBg,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: AppTheme.red),
          const SizedBox(height: 24),
          Text(s.evaluating, style: const TextStyle(fontSize: 18, color: Colors.grey)),
        ]),
      ),
    );
  }

  // ── Result ───────────────────────────────────────────────────────────────────

  Widget _buildResult(AppStrings s) {
    final eval = _evaluation;
    if (eval == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppTheme.warmBg,
      appBar: AppBar(
        title: Text(_activeTopic,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.warmBg,
        actions: [
          TextButton(
            onPressed: _startOver,
            child: Text(s.startOver, style: const TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _scoreColor(eval.overallScore), width: 10),
              ),
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${eval.overallScore}',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                          color: _scoreColor(eval.overallScore))),
                  const Text('/ 100', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(s.overallScore, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const SizedBox(height: 20),
          _resultSection(icon: Icons.summarize, title: s.examSummary,
              child: Text(eval.summary, style: const TextStyle(fontSize: 14, height: 1.5))),
          const SizedBox(height: 12),
          if (eval.strengths.isNotEmpty)
            _resultSection(
              icon: Icons.thumb_up, title: s.strengths,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: eval.strengths.map((str) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('• ', style: TextStyle(color: AppTheme.jade)),
                    Expanded(child: Text(str, style: const TextStyle(fontSize: 14))),
                  ]),
                )).toList()),
            ),
          const SizedBox(height: 12),
          if (eval.improvements.isNotEmpty)
            _resultSection(
              icon: Icons.trending_up, title: s.improvements,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: eval.improvements.map((imp) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('• ', style: TextStyle(color: AppTheme.red)),
                    Expanded(child: Text(imp, style: const TextStyle(fontSize: 14))),
                  ]),
                )).toList()),
            ),
          const SizedBox(height: 12),
          ...eval.exchanges.asMap().entries.map((entry) {
            final ex = entry.value;
            final i = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: AppTheme.cardDecoration,
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('Q${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.red, fontSize: 12)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: _scoreColor(ex.score).withAlpha(25),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${ex.score}/100',
                          style: TextStyle(color: _scoreColor(ex.score),
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(ex.question, style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(ex.answer, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  if (ex.mistake != null && ex.mistake!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(ex.mistake!,
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontStyle: FontStyle.italic)),
                  ],
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _startOver,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red, foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(s.startOver),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppTheme.jade;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _resultSection({required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: AppTheme.red),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
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

// ── Option Card widget ────────────────────────────────────────────────────────

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
            color: selected ? AppTheme.red : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? AppTheme.red.withAlpha(40)
                  : const Color(0x11000000),
              blurRadius: selected ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: selected ? AppTheme.red : Colors.black87)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? AppTheme.red : Colors.grey.shade300,
                ),
              ],
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}
