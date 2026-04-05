import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../language_manager.dart';
import '../strings.dart';
import '../theme.dart';
import '../api_client.dart';
import '../models.dart';
import '../widgets/screen_header.dart';
import '../widgets/stroke_order_view.dart';
import '../widgets/input_type_selector.dart';
import '../utils/input_type.dart';
import '../utils/serbian_utils.dart';

class CharactersScreen extends StatefulWidget {
  const CharactersScreen({super.key});

  @override
  State<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends State<CharactersScreen> {
  final _api = ApiClient();
  final _controller = TextEditingController();
  bool _isLoading = false;
  CharacterLookupResult? _result;
  String? _error;
  InputType _inputType = InputType.english;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final rawQuery = _controller.text.trim();
    if (rawQuery.isEmpty) return;
    if (!InputValidator.isValid(rawQuery, _inputType)) {
      setState(() => _error = InputValidator.errorMessage(_inputType, context.read<LanguageManager>().s));
      return;
    }
    // DB stores Serbian in Latin script (from DeepSeek) — normalize Cyrillic input to Latin
    final query = (_inputType == InputType.serbian)
        ? cyrillicToLatin(rawQuery)
        : rawQuery;
    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _result = null; _error = null; });
    final s = context.read<LanguageManager>().s;
    final (result, err) = await _api.lookupCharacter(query, inputType: _inputType);
    setState(() {
      _isLoading = false;
      if (err == 'not_in_dictionary') { _error = s.notInDictionary; }
      else if (err != null) { _error = err; }
      else { _result = result; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageManager>().s;
    return Scaffold(
      backgroundColor: AppTheme.warmBg,
      body: Column(
        children: [
          ScreenHeader(title: s.characterTitle, subtitle: s.characterSubtitle),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                children: [
                  _buildBanner(s),
                  const SizedBox(height: 16),
                  _buildSearchCard(s),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppTheme.red),
                    )),
                  if (_result != null) _buildResultCard(s, _result!),
                  if (_error != null) _buildErrorCard(_error!),
                ],
              ),
            ),
          ),
        ],
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.search, color: AppTheme.red, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.characterBannerTitle,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(s.characterBannerBody,
                              style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard(AppStrings s) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.englishPinyinOrChinese,
              style: const TextStyle(color: AppTheme.red, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 10),
          InputTypeSelector(
            selected: _inputType,
            onChanged: (t) => setState(() { _inputType = t; _error = null; }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: s.characterPlaceholder,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    filled: true, fillColor: const Color(0xFFF2F2F7),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _lookup(),
                ),
              ),
              const SizedBox(width: 10),
              _isLoading
                  ? const SizedBox(width: 44, height: 44,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.red)))
                  : GestureDetector(
                      onTap: _lookup,
                      child: const Icon(Icons.arrow_circle_right, size: 44, color: AppTheme.red),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.characterHint, style: const TextStyle(fontSize: 12, color: Colors.black38)),
        ],
      ),
    );
  }

  Widget _buildResultCard(AppStrings s, CharacterLookupResult result) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              children: [
                Text(result.characters,
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(result.pinyin,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.red)),
                    if (result.english.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('·', style: TextStyle(color: Colors.black26)),
                      ),
                      Text(result.english, style: const TextStyle(fontSize: 18, color: Colors.black54)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SizedBox(
            height: 260,
            child: StrokeOrderView(word: result.characters, repeatLabel: s.repeatAnimation),
          ),
          if (result.english.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(result.english, style: const TextStyle(fontSize: 17, color: Colors.black54)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0x14FF0000), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 14))),
        ],
      ),
    );
  }
}
