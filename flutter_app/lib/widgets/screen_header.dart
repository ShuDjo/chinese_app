import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../language_manager.dart';

class ScreenHeader extends StatelessWidget {
  final String subtitle;
  final String title;

  const ScreenHeader({super.key, required this.subtitle, this.title = 'XuéBàn'});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageManager>();

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
                  Text(title,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(subtitle,
                          style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 14)),
                      const SizedBox(width: 6),
                      PopupMenuButton<AppLanguage>(
                        icon: const Icon(Icons.language_rounded,
                            color: Color(0xCCFFFFFF), size: 18),
                        padding: EdgeInsets.zero,
                        color: Colors.white,
                        onSelected: (l) => context.read<LanguageManager>().setLanguage(l),
                        itemBuilder: (_) => [
                          _langItem(AppLanguage.english, 'English', lang.language),
                          _langItem(AppLanguage.serbianCyrillic, 'Српски (ћирилица)', lang.language),
                          _langItem(AppLanguage.serbianLatin, 'Srpski (latinica)', lang.language),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<AppLanguage> _langItem(
      AppLanguage value, String label, AppLanguage current) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (value == current)
            const Icon(Icons.check_rounded, size: 18, color: AppTheme.red),
        ],
      ),
    );
  }
}
