import 'package:characters/characters.dart';

/// Transliterate Serbian Cyrillic → Latin for script-agnostic comparison.
/// Latin characters pass through unchanged.
String cyrillicToLatin(String s) {
  const map = {
    'љ': 'lj', 'њ': 'nj', 'џ': 'dž', 'Љ': 'Lj', 'Њ': 'Nj', 'Џ': 'Dž',
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'ђ': 'đ',
    'е': 'e', 'ж': 'ž', 'з': 'z', 'и': 'i', 'ј': 'j', 'к': 'k',
    'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r',
    'с': 's', 'т': 't', 'ћ': 'ć', 'у': 'u', 'ф': 'f', 'х': 'h',
    'ц': 'c', 'ч': 'č', 'ш': 'š',
    'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Ђ': 'Đ',
    'Е': 'E', 'Ж': 'Ž', 'З': 'Z', 'И': 'I', 'Ј': 'J', 'К': 'K',
    'Л': 'L', 'М': 'M', 'Н': 'N', 'О': 'O', 'П': 'P', 'Р': 'R',
    'С': 'S', 'Т': 'T', 'Ћ': 'Ć', 'У': 'U', 'Ф': 'F', 'Х': 'H',
    'Ц': 'C', 'Ч': 'Č', 'Ш': 'Š',
  };
  final buf = StringBuffer();
  for (final ch in s.characters) {
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}
