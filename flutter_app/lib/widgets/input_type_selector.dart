import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../language_manager.dart';
import '../theme.dart';
import '../utils/input_type.dart';

class InputTypeSelector extends StatelessWidget {
  final InputType selected;
  final ValueChanged<InputType> onChanged;

  const InputTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  // The non-pinyin type valid for the current language
  static InputType languageType(AppLanguage lang) =>
      (lang == AppLanguage.english) ? InputType.english : InputType.serbian;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageManager>().language;
    final s = context.watch<LanguageManager>().s;
    final validType = languageType(lang);

    // If the current selection doesn't match the language, reset after frame
    if (selected != InputType.pinyin && selected != validType) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(validType));
    }

    final effectiveSelected =
        (selected == InputType.pinyin) ? InputType.pinyin : validType;

    final langLabel =
        (lang == AppLanguage.english) ? s.inputTypeEnglish : s.inputTypeSerbian;

    return Row(
      children: [
        _Pill(
          label: langLabel,
          type: validType,
          selected: effectiveSelected,
          onTap: onChanged,
        ),
        const SizedBox(width: 8),
        _Pill(
          label: s.inputTypePinyin,
          type: InputType.pinyin,
          selected: effectiveSelected,
          onTap: onChanged,
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final InputType type;
  final InputType selected;
  final ValueChanged<InputType> onTap;

  const _Pill({
    required this.label,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == type;
    return GestureDetector(
      onTap: () => onTap(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.red : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.red : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
