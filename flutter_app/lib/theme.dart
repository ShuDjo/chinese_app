import 'package:flutter/material.dart';

class AppTheme {
  static const Color red = Color(0xFFC71414);
  static const Color jade = Color(0xFF2E7D5E);
  static const Color warmBg = Color(0xFFF9F7F4);
  static const Color cardBg = Colors.white;

  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: red),
        scaffoldBackgroundColor: warmBg,
        fontFamily: '.SF Pro Text',
        appBarTheme: const AppBarTheme(
          backgroundColor: warmBg,
          foregroundColor: Colors.black,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        useMaterial3: true,
      );

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      );

  static LinearGradient get redGradient => const LinearGradient(
        colors: [Color(0xFFC71414), Color(0xFFB71010)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get jadeGradient => const LinearGradient(
        colors: [Color(0xFF2E7D5E), Color(0xFF1A5C42)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
}
