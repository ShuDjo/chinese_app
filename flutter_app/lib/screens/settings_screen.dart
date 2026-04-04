import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../language_manager.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageManager>();
    final s = lang.s;

    return Scaffold(
      backgroundColor: AppTheme.warmBg,
      appBar: AppBar(
        title: Text(s.settingsTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.warmBg,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(s.language,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.grey)),
                ),
                _languageOption(context, lang, AppLanguage.english, s.english),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _languageOption(
                    context, lang, AppLanguage.serbianCyrillic, s.serbianCyrillic),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _languageOption(
                    context, lang, AppLanguage.serbianLatin, s.serbianLatin),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text('XuéBàn v1.0',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _languageOption(
    BuildContext context,
    LanguageManager lang,
    AppLanguage option,
    String label,
  ) {
    final selected = lang.language == option;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppTheme.red)
          : null,
      onTap: () => lang.setLanguage(option),
      selectedTileColor: AppTheme.red.withOpacity(0.05),
      selected: selected,
    );
  }
}
