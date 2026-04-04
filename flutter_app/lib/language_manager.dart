import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'strings.dart';

enum AppLanguage { english, serbianCyrillic, serbianLatin }

class LanguageManager extends ChangeNotifier {
  static const _key = 'app_language';

  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;

  AppStrings get s => AppStrings(_language);

  // Returns the raw value sent to the backend for quiz evaluation language
  String get languageCode {
    switch (_language) {
      case AppLanguage.serbianCyrillic:
        return 'sr-Cyrl';
      case AppLanguage.serbianLatin:
        return 'sr-Latn';
      default:
        return 'en';
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key);
    if (val != null) {
      _language = AppLanguage.values.firstWhere(
        (e) => e.name == val,
        orElse: () => AppLanguage.english,
      );
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang.name);
  }
}
