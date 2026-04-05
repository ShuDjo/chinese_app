import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../language_manager.dart';
import '../strings.dart';
import '../theme.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets/stroke_order_view.dart';
import '../widgets/input_type_selector.dart';
import '../utils/input_type.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

enum InputMode { mic, text }

class _TranslateScreenState extends State<TranslateScreen> {
  final _api = ApiClient();
  final _recorder = AudioRecorder();
  final _tts = FlutterTts();
  final _textController = TextEditingController();

  InputMode _inputMode = InputMode.mic;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isLookingUp = false;
  bool _isSaving = false;

  TranscriptionResult? _transcription;
  String? _sentenceTranslation;
  CharacterLookupResult? _lookupResult;
  bool _lookupFromAi = false;
  bool _lookupSaved = false;

  InputType _inputType = InputType.english;
  String? _error;
  Set<String> _declinedWords = {};

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(0.35);
    await _tts.setVolume(1.0);
  }

  @override
  void dispose() {
    _recorder.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _error = context.read<LanguageManager>().s.micPermissionDenied);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/recording.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _isRecording = true;
      _error = null;
      _transcription = null;
      _sentenceTranslation = null;
      _declinedWords = {};
    });
  }

  Future<void> _stopAndTranscribe() async {
    final path = await _recorder.stop();
    setState(() { _isRecording = false; _isTranscribing = true; });
    if (path == null) { setState(() => _isTranscribing = false); return; }
    final (result, err) = await _api.transcribeAudio(path);
    final s = context.read<LanguageManager>().s;
    setState(() {
      _isTranscribing = false;
      if (err != null) {
        _error = err;
      } else if (result?.error == 'no_chinese_detected') {
        _error = s.noChineseDetected;
      } else {
        _transcription = result;
      }
    });
  }

  Future<void> _accept() async {
    final trans = _transcription;
    if (trans == null) return;
    final activeWords = trans.words.where((w) => !_declinedWords.contains(w.word)).toList();
    setState(() => _isSaving = true);
    final (translation, err) = await _api.translateText(trans.chineseTranscription, activeWords);
    setState(() {
      _isSaving = false;
      if (err != null) { _error = err; } else { _sentenceTranslation = translation; }
    });
  }

  Future<void> _performLookup() async {
    final query = _textController.text.trim();
    if (query.isEmpty) return;
    if (!InputValidator.isValid(query, _inputType)) {
      setState(() => _error = InputValidator.errorMessage(_inputType, context.read<LanguageManager>().s));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { _isLookingUp = true; _lookupResult = null; _lookupSaved = false; _lookupFromAi = false; _error = null; });

    // Step 1: Try local DB
    final (dbResult, dbErr) = await _api.lookupCharacter(query, inputType: _inputType);
    if (dbErr == null && dbResult != null) {
      setState(() { _isLookingUp = false; _lookupResult = dbResult; });
      return;
    }

    // Step 2: Not in DB — fall back to AI
    if (dbErr == 'not_in_dictionary') {
      final (aiResult, aiErr) = await _api.aiLookupCharacter(query, inputType: _inputType);
      setState(() {
        _isLookingUp = false;
        if (aiErr != null) { _error = aiErr; }
        else { _lookupResult = aiResult; _lookupFromAi = true; }
      });
      return;
    }

    setState(() { _isLookingUp = false; _error = dbErr; });
  }

  Future<void> _saveLookupResult(CharacterLookupResult result) async {
    final word = WordResult(word: result.characters, english: result.english, pinyin: result.pinyin);
    setState(() => _isSaving = true);
    final (_, err) = await _api.translateText(result.characters, [word]);
    setState(() {
      _isSaving = false;
      if (err != null) { _error = err; } else { _lookupSaved = true; }
    });
  }

  void _speak(String text) => _tts.speak(text);

  void _showStrokeSheet(String word) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Consumer<LanguageManager>(
        builder: (_, langMgr, __) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(word, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              Expanded(child: StrokeOrderView(word: word, repeatLabel: langMgr.s.repeatAnimation)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageManager>().s;
    return Scaffold(
      backgroundColor: AppTheme.warmBg,
      body: Column(
        children: [
          _buildHeader(s),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModePicker(s),
                  const SizedBox(height: 16),
                  _buildBanner(s),
                  const SizedBox(height: 16),
                  if (_inputMode == InputMode.mic) ...[
                    _buildMicSection(s),
                    if (_isTranscribing) ...[const SizedBox(height: 16), _loadingRow(s.transcribing)],
                    if (_transcription != null) ...[const SizedBox(height: 16), _buildResultsCard(s, _transcription!)],
                  ] else ...[
                    _buildTextSection(s),
                    if (_isLookingUp) ...[const SizedBox(height: 16), _loadingRow(s.lookingUp)],
                    if (_lookupResult != null) ...[const SizedBox(height: 16), _buildLookupResultCard(s, _lookupResult!)],
                  ],
                  if (_error != null) ...[const SizedBox(height: 16), _buildErrorCard(_error!)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppStrings s) {
    return Container(
      height: 140 + MediaQuery.of(context).padding.top,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.red, Color(0xFFB71010)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('☭', style: TextStyle(fontSize: 72, color: Colors.white)),
              const Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('XuéBàn',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(s.translateSubtitle,
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModePicker(AppStrings s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          _modeTab(s.modeMic, InputMode.mic, Icons.mic),
          _modeTab(s.modeType, InputMode.text, Icons.keyboard),
        ],
      ),
    );
  }

  Widget _modeTab(String label, InputMode mode, IconData icon) {
    final selected = _inputMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_inputMode == mode) return;
          setState(() {
            _inputMode = mode;
            _error = null;
            if (mode == InputMode.mic) {
              _textController.clear(); _lookupResult = null; _lookupSaved = false; _lookupFromAi = false;
            } else {
              _transcription = null; _sentenceTranslation = null; _declinedWords = {};
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppTheme.red : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(AppStrings s) {
    final body = _inputMode == InputMode.mic ? s.translateBannerBody : s.translateBannerBodyType;
    return Container(
      decoration: AppTheme.cardDecoration,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: AppTheme.red,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.translateBannerTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(body, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicSection(AppStrings s) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isTranscribing ? null : _toggleRecording,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isRecording
                      ? [const Color(0xFFE53935), const Color(0xFFB71C1C)]
                      : [AppTheme.red, const Color(0xFFB71010)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [BoxShadow(color: AppTheme.red.withAlpha(100), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Icon(_isRecording ? Icons.stop : Icons.mic, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(height: 10),
          Text(_isRecording ? s.tapToStop : s.tapToRecord,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTextSection(AppStrings s) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputTypeSelector(
            selected: _inputType,
            onChanged: (t) => setState(() { _inputType = t; _error = null; }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: s.typeEnglishOrPinyin,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    filled: true, fillColor: const Color(0xFFF2F2F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _performLookup(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isLookingUp ? null : _performLookup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.red, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(s.lookUp),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard(AppStrings s, TranscriptionResult trans) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(trans.chineseTranscription,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(s.wordsTapToSeeStrokes,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          ...trans.words.map((word) {
            final declined = _declinedWords.contains(word.word);
            return _buildWordRow(word, declined);
          }),
          const Divider(height: 1, indent: 16, endIndent: 16),
          if (_sentenceTranslation != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.check_circle, color: AppTheme.jade),
                    const SizedBox(width: 8),
                    Text(s.addedToVocabulary,
                        style: const TextStyle(color: AppTheme.jade, fontWeight: FontWeight.w600)),
                  ]),
                  if (_sentenceTranslation!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(s.sentenceTranslation,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(_sentenceTranslation!, style: const TextStyle(fontSize: 15)),
                  ],
                ],
              ),
            )
          else if (_isSaving)
            Padding(padding: const EdgeInsets.all(16), child: _loadingRow(s.saving))
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.jade, foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(s.acceptAndSave),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWordRow(WordResult word, bool declined) {
    return Opacity(
      opacity: declined ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showStrokeSheet(word.word),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(word.word,
                            style: TextStyle(
                                fontSize: 36, fontWeight: FontWeight.bold,
                                color: declined ? Colors.black26 : Colors.black,
                                decoration: declined ? TextDecoration.lineThrough : null)),
                        const SizedBox(width: 8),
                        Text(word.pinyin,
                            style: TextStyle(fontSize: 15,
                                color: declined ? Colors.grey.withAlpha(128) : AppTheme.red)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _speak(word.word),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: const Color(0x1AC71414),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.volume_up, size: 18, color: AppTheme.red),
                          ),
                        ),
                      ],
                    ),
                    Text(word.english,
                        style: TextStyle(
                            color: declined ? Colors.black26 : Colors.black54, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() {
                if (declined) { _declinedWords.remove(word.word); }
                else { _declinedWords.add(word.word); }
              }),
              child: Icon(declined ? Icons.refresh_rounded : Icons.cancel_rounded,
                  color: declined ? AppTheme.jade : const Color(0xB3FF0000), size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLookupResultCard(AppStrings s, CharacterLookupResult result) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_lookupFromAi)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF8E1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                const Icon(Icons.auto_awesome, size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                Text(s.aiTranslationBadge,
                    style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showStrokeSheet(result.characters),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(result.characters,
                        style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Icon(Icons.touch_app, size: 16, color: AppTheme.red),
                    ),
                  ]),
                ),
                Row(children: [
                  Text(result.pinyin,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.red)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _speak(result.characters),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: const Color(0x1AC71414),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.volume_up, size: 18, color: AppTheme.red),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(result.english, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                if (result.serbian?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(result.serbian!, style: const TextStyle(fontSize: 13, color: Colors.black38)),
                ],
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          if (_lookupSaved)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle, color: AppTheme.jade),
                const SizedBox(width: 8),
                Text(s.addedToVocabulary,
                    style: const TextStyle(color: AppTheme.jade, fontWeight: FontWeight.w600)),
              ]),
            )
          else if (_isSaving)
            Padding(padding: const EdgeInsets.all(16), child: _loadingRow(s.saving))
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _saveLookupResult(result),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.jade, foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_circle),
                  const SizedBox(width: 8),
                  Text(s.addToVocabulary),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0x14FF0000), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 14))),
      ]),
    );
  }

  Widget _loadingRow(String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.red)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
