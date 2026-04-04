import 'package:flutter/material.dart';
import '../theme.dart';

class ScreenHeader extends StatelessWidget {
  final String subtitle;
  final String title;

  const ScreenHeader({super.key, required this.subtitle, this.title = 'XuéBàn'});

  @override
  Widget build(BuildContext context) {
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
                  Text(subtitle,
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
