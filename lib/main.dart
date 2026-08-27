import 'dart:async';

import 'package:flutter/material.dart';
import 'logging.dart';
import 'screens/tetris_game_screen.dart';
import 'settings/settings_provider.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      installTalkerErrorHandlers();
      talker.info('Starting Block Drop');
      final settings = SettingsProvider();
      await settings.load();
      runApp(TetrisApp(settings: settings));
    },
    (error, stackTrace) =>
        talker.handle(error, stackTrace, 'Uncaught zone error'),
  );
}

class TetrisApp extends StatefulWidget {
  final SettingsProvider? settings;

  const TetrisApp({super.key, this.settings});

  @override
  State<TetrisApp> createState() => _TetrisAppState();
}

class _TetrisAppState extends State<TetrisApp> {
  late final SettingsProvider _settings;
  late final bool _ownsSettings;
  late final VoidCallback _settingsListener;

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
    _ownsSettings = widget.settings == null;
    _settings = widget.settings ?? SettingsProvider();
    _settingsListener = () => setState(() {});
    _settings.addListener(_settingsListener);
    if (_ownsSettings) _settings.load();
  }

  @override
  void dispose() {
    _settings.removeListener(_settingsListener);
    if (_ownsSettings) _settings.dispose();
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
