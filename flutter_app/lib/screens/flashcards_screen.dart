import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../language_manager.dart';
import '../strings.dart';
import '../theme.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets/screen_header.dart';
import '../widgets/input_type_selector.dart';
import '../utils/input_type.dart';
import '../utils/serbian_utils.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final _api = ApiClient();
  final _answerController = TextEditingController();
  final _focusNode = FocusNode();

  CharacterLookupResult? _card;
  bool _isLoading = false;
  bool _checked = false;
  bool _isCorrect = false;
  String? _error;
  InputType _inputType = InputType.english;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCard() async {
    setState(() { _isLoading = true; _card = null; _error = null; _checked = false; _answerController.clear(); });
    final (result, err) = await _api.fetchRandomFlashcard();
    setState(() {
      _isLoading = false;
      if (err != null) { _error = err; } else { _card = result; }
    });
  }

  void _check() {
    final card = _card;
    if (card == null) return;
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;
    if (!InputValidator.isValid(answer, _inputType)) {
      setState(() => _error = InputValidator.errorMessage(_inputType, context.read<LanguageManager>().s));
      return;
    }
    setState(() => _error = null);
    final answerLower = answer.toLowerCase();
    final pinyin = card.pinyin.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f ]'), '');
    final english = card.english.toLowerCase();
    final bool correct;
    if (_inputType == InputType.serbian && (card.serbian ?? '').isNotEmpty) {
      // Normalize both to Latin so Cyrillic and Latin answers both match
      final serbianLatin = cyrillicToLatin(card.serbian!).toLowerCase();
      final answerLatin = cyrillicToLatin(answer).toLowerCase();
      correct = answerLatin == serbianLatin || serbianLatin.contains(answerLatin);
    } else {
      // Fallback for English/Pinyin mode, or Serbian mode when no Serbian translation exists
      correct = answerLower == pinyin || answerLower == english ||
          english.contains(answerLower) || pinyin.replaceAll(' ', '').contains(answerLower.replaceAll(' ', ''));
    }
    setState(() { _checked = true; _isCorrect = correct; });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageManager>().s;
    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.warmBg,
        body: Column(
          children: [
            const ScreenHeader(subtitle: '闪卡'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: Column(
                  children: [
                    _buildBanner(s),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: AppTheme.red),
                      ))
                    else if (_error != null)
                      _buildErrorState(s, _error!)
                    else if (_card != null)
                      _buildCardContent(s, _card!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(AppStrings s) {
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
                    Text(s.flashcardBannerTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(s.flashcardBannerBody,
                        style: const TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(AppStrings s, CharacterLookupResult card) {
    return Column(
      children: [
        Container(
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          width: double.infinity,
          child: Center(
            child: Text(card.characters,
                style: const TextStyle(fontSize: 100, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        Container(
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
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0x14FF0000),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
                controller: _answerController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _checked ? null : _check(),
                decoration: InputDecoration(
                  hintText: _inputType == InputType.pinyin
                      ? s.typeAnswerPinyin
                      : _inputType == InputType.serbian
                          ? s.typeAnswerSerbian
                          : s.typeAnswerEnglish,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: _checked
                            ? (_isCorrect ? AppTheme.jade : Colors.red)
                            : Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: _checked ? (_isCorrect ? AppTheme.jade : Colors.red) : AppTheme.red),
                  ),
                  filled: !_checked,
                  fillColor: const Color(0xFFF2F2F7),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                enabled: !_checked,
              ),
              const SizedBox(height: 12),
              if (!_checked) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _check,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.red, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(s.check),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      _focusNode.unfocus();
                      setState(() { _checked = true; _isCorrect = false; });
                    },
                    child: Text(s.showAnswer,
                        style: const TextStyle(color: Colors.black45)),
                  ),
                ),
              ]
              else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isCorrect ? const Color(0x1A2E7D5E) : const Color(0x14FF0000),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(_isCorrect ? Icons.check_circle : Icons.cancel,
                            color: _isCorrect ? AppTheme.jade : Colors.red),
                        const SizedBox(width: 8),
                        Text(_isCorrect ? s.correct : s.incorrect,
                            style: TextStyle(
                                color: _isCorrect ? AppTheme.jade : Colors.red,
                                fontWeight: FontWeight.w600, fontSize: 16)),
                      ]),
                      const SizedBox(height: 8),
                      Text('${card.pinyin}  ·  ${card.english}',
                          style: const TextStyle(fontSize: 14, color: Colors.black54)),
                      if ((card.serbian ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(card.serbian!,
                            style: const TextStyle(fontSize: 14, color: Colors.black54)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loadCard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.red, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(s.next),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(AppStrings s, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(s.noWordsYet, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCard,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.red, foregroundColor: Colors.white),
            child: Text(s.retry),
          ),
        ]),
      ),
    );
  }
}
