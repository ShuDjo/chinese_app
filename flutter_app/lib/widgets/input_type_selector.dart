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

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageManager>().s;
    return Row(
      children: [
        _Pill(label: s.inputTypeEnglish, type: InputType.english, selected: selected, onTap: onChanged),
        const SizedBox(width: 8),
        _Pill(label: s.inputTypePinyin,  type: InputType.pinyin,  selected: selected, onTap: onChanged),
        const SizedBox(width: 8),
        _Pill(label: s.inputTypeSerbian, type: InputType.serbian,  selected: selected, onTap: onChanged),
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
