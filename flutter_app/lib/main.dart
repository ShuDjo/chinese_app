import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_manager.dart';
import 'theme.dart';
import 'screens/translate_screen.dart';
import 'screens/exam_screen.dart';
import 'screens/characters_screen.dart';
import 'screens/flashcards_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final langManager = LanguageManager();
  await langManager.load();
  runApp(
    ChangeNotifierProvider.value(
      value: langManager,
      child: const XueBanApp(),
    ),
  );
}

class XueBanApp extends StatelessWidget {
  const XueBanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XuéBàn',
      theme: AppTheme.theme,
      home: const HomeShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  static const _screens = [
    TranslateScreen(),
    CharactersScreen(),
    FlashcardsScreen(),
    ExamScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageManager>().s;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.red,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore_rounded),
            label: s.tabTranslate,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.auto_stories),
            label: s.tabCharacters,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.style),
            label: s.tabFlashcards,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.school),
            label: s.tabExam,
          ),
        ],
      ),
    );
  }
}
