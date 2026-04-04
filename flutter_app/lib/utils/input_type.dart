import '../strings.dart';

enum InputType { english, pinyin, serbian }

class InputValidator {
  static final _english = RegExp(r'^[a-zA-Z0-9\s.,!?\-]+$');

  static final _pinyin = RegExp(
    r'^[a-zA-ZāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüÜ1-5\s]+$',
    unicode: true,
  );

  static final _cyrillic = RegExp(r'[\u0400-\u04FF]');
  static final _serbianLatin = RegExp(r'[ćčšđžĆČŠĐŽ]');
  static final _cjk = RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF]');
  static final _latinOnly = RegExp(r'^[a-zA-Z\s.,!?\-]+$');

  static bool isValid(String text, InputType type) {
    final t = text.trim();
    if (t.isEmpty) return true;
    switch (type) {
      case InputType.english:
        return _english.hasMatch(t) && !_cjk.hasMatch(t) && !_cyrillic.hasMatch(t);
      case InputType.pinyin:
        return _pinyin.hasMatch(t) && !_cjk.hasMatch(t) && !_cyrillic.hasMatch(t);
      case InputType.serbian:
        if (_cjk.hasMatch(t)) return false;
        return _cyrillic.hasMatch(t) || _serbianLatin.hasMatch(t) || _latinOnly.hasMatch(t);
    }
  }

  static String errorMessage(InputType type, AppStrings s) {
    switch (type) {
      case InputType.english:
        return s.inputErrorEnglish;
      case InputType.pinyin:
        return s.inputErrorPinyin;
      case InputType.serbian:
        return s.inputErrorSerbian;
    }
  }
}
