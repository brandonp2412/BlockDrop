import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'logging.dart';
import 'multiplayer/online_connection.dart';
import 'screens/block_drop_game_screen.dart';
import 'screens/multiplayer_discovery_screen.dart';
import 'settings/settings_provider.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      installTalkerErrorHandlers();
      talker.info('Starting Block Drop');
      final settings = SettingsProvider();
      await settings.load();
      runApp(BlockDropApp(settings: settings));
    },
    (error, stackTrace) =>
        talker.handle(error, stackTrace, 'Uncaught zone error'),
  );
}

class BlockDropApp extends StatefulWidget {
  final SettingsProvider? settings;

  const BlockDropApp({super.key, this.settings});

  @override
  State<BlockDropApp> createState() => _BlockDropAppState();
}

class _BlockDropAppState extends State<BlockDropApp> {
  late final SettingsProvider _settings;
  late final bool _ownsSettings;
  late final VoidCallback _settingsListener;

  static final _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    popupMenuTheme: const PopupMenuThemeData(menuPadding: EdgeInsets.zero),
    useMaterial3: true,
  );

  static final _darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    popupMenuTheme: const PopupMenuThemeData(menuPadding: EdgeInsets.zero),
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
    popupMenuTheme: const PopupMenuThemeData(menuPadding: EdgeInsets.zero),
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
    final invite = initialOnlineInvite;
    return MaterialApp(
      onGenerateInitialRoutes: invite == null
          ? null
          : (_) => [
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/'),
                  builder: (_) => BlockDropGameScreen(settings: _settings),
                ),
                MaterialPageRoute<void>(
                  builder: (_) => MultiplayerDiscoveryScreen(
                    settings: _settings,
                    onlineInvite: invite,
                  ),
                ),
              ],
      onGenerateTitle: (context) => context.l10n.text('Block Drop'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _settings.locale,
      localeListResolutionCallback: (locales, _) =>
          AppLocalizations.resolveLocale(locales),
      // Neon style requires a dark background everywhere — override theme mode
      themeMode: _settings.style == AppStyle.neon
          ? ThemeMode.dark
          : _settings.flutterThemeMode,
      theme: _lightTheme,
      darkTheme: _settings.isBlackMode ? _blackTheme : _darkTheme,
      routes: {'/': (_) => BlockDropGameScreen(settings: _settings)},
      debugShowCheckedModeBanner: false,
    );
  }
}
