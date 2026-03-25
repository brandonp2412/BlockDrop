import 'package:flutter/material.dart';
import 'screens/tetris_game_screen.dart';
import 'settings/settings_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TetrisApp());
}

class TetrisApp extends StatefulWidget {
  const TetrisApp({super.key});

  @override
  State<TetrisApp> createState() => _TetrisAppState();
}

class _TetrisAppState extends State<TetrisApp> {
  final _settings = SettingsProvider();

  static final _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  static final _darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    useMaterial3: true,
  );

  static final _blackTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ).copyWith(
      surface: Colors.black,
      surfaceContainerHighest: const Color(0xFF111111),
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.black,
    useMaterial3: true,
  );

  @override
  void initState() {
    super.initState();
    _settings.addListener(() => setState(() {}));
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Drop - Tetris',
      // Neon style requires a dark background everywhere — override theme mode
      themeMode: _settings.style == AppStyle.neon
          ? ThemeMode.dark
          : _settings.flutterThemeMode,
      theme: _lightTheme,
      darkTheme: _settings.isBlackMode ? _blackTheme : _darkTheme,
      home: TetrisGameScreen(settings: _settings),
      debugShowCheckedModeBanner: false,
    );
  }
}
