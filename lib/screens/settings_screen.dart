import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../audio/audio_service.dart';
import '../settings/settings_provider.dart';
import '../game/gameplay_settings.dart';
import '../settings/controller_bindings.dart';
import '../widgets/empty_state.dart';
import '../widgets/game_decorations.dart';
import 'multiplayer_discovery_screen.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsProvider settings;
  final VoidCallback? onRestart;
  final VoidCallback? onQuit;
  final VoidCallback? onPractice;

  const SettingsScreen({
    super.key,
    required this.settings,
    this.onRestart,
    this.onQuit,
    this.onPractice,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _languageNames = <String, String>{
    'en': 'English',
    'th': 'ไทย',
    'tr': 'Türkçe',
    'vi': 'Tiếng Việt',
    'de': 'Deutsch',
    'es': 'Español',
    'fr': 'Français',
    'pt': 'Português (Brasil)',
    'pt-PT': 'Português (Portugal)',
    'pl': 'Polski',
    'it': 'Italiano',
    'bn': 'বাংলা',
    'ur': 'اردو',
    'fa': 'فارسی',
    'nl': 'Nederlands',
    'ja': '日本語',
    'ko': '한국어',
    'zh-Hans': '中文（简体）',
    'zh-Hant': '中文（繁體）',
    'ru': 'Русский',
    'uk': 'Українська',
    'hi': 'हिन्दी',
    'ar': 'العربية',
    'id': 'Bahasa Indonesia',
    'ms': 'Bahasa Melayu',
  };

  String _searchQuery = '';
  bool _isSearching = false;

  Future<String?> _pickAndStoreAudio(String slot) async {
    try {
      final picked = await FilePicker.pickFile(type: FileType.audio);
      if (picked == null) return null;
      final extension = picked.extension?.toLowerCase();
      final directory = Directory(
        '${(await getApplicationSupportDirectory()).path}/custom_audio',
      );
      await directory.create(recursive: true);
      final targetName = extension == null ? slot : '$slot.$extension';
      final target = File(directory.path + Platform.pathSeparator + targetName);
      await target.writeAsBytes(await picked.readAsBytes(), flush: true);
      return target.path;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.text('Unable to import audio'))),
        );
      }
      return null;
    }
  }

  Future<void> _chooseCustomMusic() async {
    final path = await _pickAndStoreAudio('music');
    if (path != null) await widget.settings.setCustomMusicPath(path);
  }

  Future<void> _chooseCustomSfx(String name) async {
    final path = await _pickAndStoreAudio('sfx_$name');
    if (path != null) await widget.settings.setCustomSfxPath(name, path);
  }

  Future<void> _showCustomSfxDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.text('Custom sound effects')),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: AudioService.sfxNames.map((name) {
              final customized = widget.settings.customSfxPaths.containsKey(
                name,
              );
              return ListTile(
                title: Text(name.replaceAll('_', ' ')),
                subtitle: Text(
                  context.l10n.text(
                    customized ? 'Custom audio' : 'Default audio',
                  ),
                ),
                trailing: customized
                    ? IconButton(
                        tooltip: context.l10n.text('Restore default'),
                        icon: const Icon(Icons.restore),
                        onPressed: () async {
                          await widget.settings.setCustomSfxPath(name, null);
                          if (dialogContext.mounted)
                            Navigator.pop(dialogContext);
                        },
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _chooseCustomSfx(name);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.text('Close')),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  bool _matchesSearch(String label, {String? section}) {
    if (_searchQuery.isEmpty) return true;
    final localizedLabel = context.l10n.text(label).toLowerCase();
    final localizedSection =
        section == null ? null : context.l10n.text(section).toLowerCase();
    return localizedLabel.contains(_searchQuery) ||
        (localizedSection?.contains(_searchQuery) ?? false);
  }

  bool _sectionMatches(String section, Iterable<String> labels) {
    if (_searchQuery.isEmpty ||
        context.l10n.text(section).toLowerCase().contains(_searchQuery)) {
      return true;
    }
    return labels.any(
      (label) => context.l10n.text(label).toLowerCase().contains(_searchQuery),
    );
  }

  static String _styleLabel(AppStyle style) => switch (style) {
        AppStyle.classic => 'Classic',
        AppStyle.modern => 'Modern',
        AppStyle.bubbles => 'Bubbles',
        AppStyle.neon => 'Neon',
        AppStyle.retro => 'Retro',
      };

  void _pickStyle() {
    final cs = Theme.of(context).colorScheme;
    showDialog<AppStyle>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: styledDialogShape(widget.settings.style, cs),
        title: Text(context.l10n.text('Style')),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppStyle.values.map((s) {
            final isSelected = s == widget.settings.style;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _StyleOption(
                style: s,
                label: context.l10n.text(_styleLabel(s)),
                isSelected: isSelected,
                colorScheme: cs,
                onTap: () => Navigator.pop(ctx, s),
              ),
            );
          }).toList(),
        ),
      ),
    ).then((v) {
      if (v != null) {
        widget.settings.setStyle(v);
        if (v == AppStyle.neon) widget.settings.setThemeMode(AppThemeMode.dark);
      }
    });
  }

  Future<void> _pickGameplayNumber({
    required String title,
    required String help,
    required int value,
    required int min,
    required int max,
    required int divisions,
    required String suffix,
    required GameplaySettings Function(int value) update,
    String? zeroLabel,
  }) async {
    double selected = value.toDouble();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final current = selected.round();
          final label = current == 0 && zeroLabel != null
              ? context.l10n.text(zeroLabel)
              : suffix == ' lines'
                  ? context.l10n.text('{lines} lines', {'lines': current})
                  : '$current$suffix';
          return AlertDialog(
            shape: styledDialogShape(
              widget.settings.style,
              Theme.of(ctx).colorScheme,
            ),
            title: Text(context.l10n.text(title)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.text(help)),
                const SizedBox(height: 16),
                Text(label, style: Theme.of(ctx).textTheme.titleLarge),
                Slider(
                  value: selected,
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: divisions,
                  label: label,
                  onChanged: (next) => setDialogState(() => selected = next),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.text('Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, current),
                child: Text(context.l10n.text('Save')),
              ),
            ],
          );
        },
      ),
    );
    if (result != null)
      await widget.settings.setGameplaySettings(update(result));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controlTheme = theme.copyWith(
      switchTheme: _switchTheme(widget.settings.style, colorScheme),
    );
    final showGame = _sectionMatches('Game', [
      'Resume',
      'Restart',
      'Quit',
      'Practice Mode',
    ]);
    final showSound = _sectionMatches('Sound', [
      'Music',
      'Sound Effects',
    ]);
    final showGameplay = _sectionMatches('Gameplay', [
      'Ghost Tile',
      'Enable Hold Piece',
      'Swipe Up to Hold',
      'Continue Saved Game',
      'On-Screen Controls',
      'Large Board',
      'Starting Speed',
      'Speed per Level',
      'Maximum Level',
      'Lines per Level',
      'Enable Soft Drop',
      'Back Gesture Holds',
    ]);
    final showController = _sectionMatches('Controller', [
      ...GameplayAction.values.map((action) => action.label),
      'Reset controller layout',
    ]);
    final showAppearance = _sectionMatches('Appearance', [
      'Theme',
      'System',
      'Dark',
      'Light',
      'Pure Black AMOLED',
      'Style',
      'Language',
      'System default',
      ..._languageNames.values,
    ]);
    final showMultiplayer = _sectionMatches('Multiplayer', [
      'Show Opponent Board',
      'Play on LAN',
    ]);
    final showStats = _sectionMatches('Stats', ['High Score']);
    final showInstructions = _sectionMatches('Instructions', ['Controls']);
    final showAbout = _sectionMatches('About', ['BlockDrop']);
    final noSearchResults = _searchQuery.isNotEmpty &&
        !showGame &&
        !showSound &&
        !showGameplay &&
        !showController &&
        !showAppearance &&
        !showMultiplayer &&
        !showStats &&
        !showInstructions &&
        !showAbout;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                key: const ValueKey('settings-search'),
                decoration: InputDecoration(
                  hintText: context.l10n.text('Search settings'),
                  border: InputBorder.none,
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
              )
            : Text(context.l10n.text('Settings')),
        centerTitle: true,
        actions: [
          IconButton(
            key: const ValueKey('settings-search-button'),
            tooltip: context.l10n.text('Search settings'),
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchQuery = '';
            }),
          ),
        ],
      ),
      body: Theme(
        data: controlTheme,
        child: SafeArea(
          child: noSearchResults
              ? AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No settings found',
                  message: 'Try another search term.',
                  actionLabel: 'Clear search',
                  actionIcon: Icons.close_rounded,
                  onAction: () => setState(() {
                    _searchQuery = '';
                    _isSearching = false;
                  }),
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  // Large scrollCacheExtent ensures all children are laid out off-screen so
                  // Android TV D-pad focus traversal can reach items below the viewport.
                  scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
                  children: [
                    if ((widget.onRestart != null || widget.onQuit != null) &&
                        showGame) ...[
                      _SectionHeader(label: 'Game', colorScheme: colorScheme),
                      _SettingsPanel(
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: 'Resume',
                                icon: Icons.play_arrow,
                                colorScheme: colorScheme,
                                style: widget.settings.style,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ActionButton(
                                label: 'Restart',
                                icon: Icons.refresh,
                                colorScheme: colorScheme,
                                style: widget.settings.style,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onRestart?.call();
                                },
                              ),
                            ),
                            if (widget.onQuit != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ActionButton(
                                  label: 'Quit',
                                  icon: Icons.stop,
                                  colorScheme: colorScheme,
                                  style: widget.settings.style,
                                  isDestructive: true,
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    widget.onQuit?.call();
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.onPractice != null)
                        _SettingsPanel(
                          colorScheme: colorScheme,
                          style: widget.settings.style,
                          child: _ActionButton(
                            label: 'Practice Mode',
                            icon: Icons.school,
                            colorScheme: colorScheme,
                            style: widget.settings.style,
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onPractice?.call();
                            },
                          ),
                        ),
                    ],
                    if (showSound)
                      _SectionHeader(label: 'Sound', colorScheme: colorScheme),
                    if (_matchesSearch('Music', section: 'Sound'))
                      _SettingTile(
                        label: 'Music',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        labelFlex: 4,
                        controlFlex: 7,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (widget.settings.customMusicPath != null)
                              IconButton(
                                tooltip: context.l10n.text('Restore default'),
                                onPressed: () =>
                                    widget.settings.setCustomMusicPath(null),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                                icon: const Icon(Icons.restore, size: 20),
                              ),
                            IconButton(
                              tooltip: context.l10n.text('Choose audio file'),
                              onPressed: _chooseCustomMusic,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              icon: const Icon(Icons.audio_file, size: 20),
                            ),
                            SizedBox(
                              width: 48,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Switch(
                                  key: const Key('settingsMusicSwitch'),
                                  value: widget.settings.musicEnabled,
                                  onChanged: (value) =>
                                      widget.settings.setMusicEnabled(value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_matchesSearch('Sound Effects', section: 'Sound'))
                      _SettingTile(
                        label: 'Sound Effects',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: context.l10n.text(
                                'Choose custom sound effects',
                              ),
                              onPressed: _showCustomSfxDialog,
                              icon: const Icon(Icons.library_music),
                            ),
                            Switch(
                              value: widget.settings.sfxEnabled,
                              onChanged: (value) =>
                                  widget.settings.setSfxEnabled(value),
                            ),
                          ],
                        ),
                      ),
                    if (showGameplay)
                      _SectionHeader(
                        label: 'Gameplay',
                        colorScheme: colorScheme,
                      ),
                    if (_matchesSearch('Ghost Tile', section: 'Gameplay'))
                      _SettingTile(
                        label: 'Ghost Tile',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Switch(
                          value: widget.settings.showGhostTile,
                          onChanged: (value) =>
                              widget.settings.setShowGhostTile(value),
                        ),
                      ),
                    if (_matchesSearch(
                      'Enable Hold Piece',
                      section: 'Gameplay',
                    ))
                      _SettingTile(
                        label: 'Enable Hold Piece',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Switch(
                          value: widget.settings.enableHold,
                          onChanged: (value) =>
                              widget.settings.setEnableHold(value),
                        ),
                      ),
                    if (widget.settings.enableHold &&
                        _matchesSearch('Swipe Up to Hold', section: 'Gameplay'))
                      _SettingTile(
                        label: 'Swipe Up to Hold',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Switch(
                          key: const Key('settingsSwipeUpHoldSwitch'),
                          value: widget.settings.gameplay.swipeUpHoldEnabled,
                          onChanged: (value) =>
                              widget.settings.setGameplaySettings(
                            widget.settings.gameplay.copyWith(
                              swipeUpHoldEnabled: value,
                            ),
                          ),
                        ),
                      ),
                    if (_matchesSearch(
                      'Continue Saved Game',
                      section: 'Gameplay',
                    ))
                      _SettingTile(
                        label: 'Continue Saved Game',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Switch(
                          key: const Key('settingsContinueGameSwitch'),
                          value: widget.settings.continueGameEnabled,
                          onChanged: widget.settings.setContinueGameEnabled,
                        ),
                      ),
                    if (_matchesSearch(
                      'On-Screen Controls',
                      section: 'Gameplay',
                    ))
                      _SettingTile(
                        label: 'On-Screen Controls',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Switch(
                          value: widget.settings.showOnScreenControls,
                          onChanged: widget.settings.setShowOnScreenControls,
                        ),
                      ),
                    if (_matchesSearch('Large Board', section: 'Gameplay'))
                      _SettingTile(
                        label: 'Large Board',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Switch(
                          value: widget.settings.fullscreenBoard,
                          onChanged: (value) =>
                              widget.settings.setFullscreenBoard(value),
                        ),
                      ),
                    if (_matchesSearch('Starting Speed', section: 'Gameplay'))
                      _GameplayValueTile(
                        label: 'Starting Speed',
                        value:
                            '${widget.settings.gameplay.initialDropSpeed} ms',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        onTap: () => _pickGameplayNumber(
                          title: 'Starting Speed',
                          help:
                              'Time between automatic downward moves at level 1. '
                              'Lower values are faster.',
                          value: widget.settings.gameplay.initialDropSpeed,
                          min: 200,
                          max: 2000,
                          divisions: 18,
                          suffix: ' ms',
                          update: (value) => widget.settings.gameplay.copyWith(
                            initialDropSpeed: value,
                          ),
                        ),
                      ),
                    if (_matchesSearch('Speed per Level', section: 'Gameplay'))
                      _GameplayValueTile(
                        label: 'Speed per Level',
                        value: '${widget.settings.gameplay.speedIncrement} ms',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        onTap: () => _pickGameplayNumber(
                          title: 'Speed per Level',
                          help:
                              'Milliseconds removed from the drop delay each level.',
                          value: widget.settings.gameplay.speedIncrement,
                          min: 0,
                          max: 200,
                          divisions: 20,
                          suffix: ' ms',
                          update: (value) => widget.settings.gameplay.copyWith(
                            speedIncrement: value,
                          ),
                        ),
                      ),
                    if (_matchesSearch('Maximum Level', section: 'Gameplay'))
                      _GameplayValueTile(
                        label: 'Maximum Level',
                        value: widget.settings.gameplay.maximumLevel ==
                                GameplaySettings.unlimitedLevels
                            ? context.l10n.text('Unlimited')
                            : '${widget.settings.gameplay.maximumLevel}',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        onTap: () => _pickGameplayNumber(
                          title: 'Maximum Level',
                          help: 'Choose 0 for unlimited level progression.',
                          value: widget.settings.gameplay.maximumLevel,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          suffix: '',
                          zeroLabel: 'Unlimited',
                          update: (value) => widget.settings.gameplay.copyWith(
                            maximumLevel: value,
                          ),
                        ),
                      ),
                    if (_matchesSearch('Lines per Level', section: 'Gameplay'))
                      _GameplayValueTile(
                        label: 'Lines per Level',
                        value: '${widget.settings.gameplay.linesPerLevel}',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        onTap: () => _pickGameplayNumber(
                          title: 'Lines per Level',
                          help: 'Cleared lines required to advance one level.',
                          value: widget.settings.gameplay.linesPerLevel,
                          min: 1,
                          max: 50,
                          divisions: 49,
                          suffix: ' lines',
                          update: (value) => widget.settings.gameplay.copyWith(
                            linesPerLevel: value,
                          ),
                        ),
                      ),
                    if (_matchesSearch('Enable Soft Drop', section: 'Gameplay'))
                      _SettingTile(
                        label: 'Enable Soft Drop',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Switch(
                          value: widget.settings.gameplay.softDropEnabled,
                          onChanged: (value) =>
                              widget.settings.setGameplaySettings(
                            widget.settings.gameplay.copyWith(
                              softDropEnabled: value,
                            ),
                          ),
                        ),
                      ),
                    if (widget.settings.enableHold &&
                        _matchesSearch(
                          'Back Gesture Holds',
                          section: 'Gameplay',
                        ))
                      _SettingTile(
                        label: 'Back Gesture Holds',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Switch(
                          value: widget.settings.gameplay.holdInteractionMode ==
                              HoldInteractionMode.panelAndBackGesture,
                          onChanged: (value) =>
                              widget.settings.setGameplaySettings(
                            widget.settings.gameplay.copyWith(
                              holdInteractionMode: value
                                  ? HoldInteractionMode.panelAndBackGesture
                                  : HoldInteractionMode.panelOnly,
                            ),
                          ),
                        ),
                      ),
                    if (showController) ...[
                      _SectionHeader(
                        label: 'Controller',
                        colorScheme: colorScheme,
                      ),
                      _ControllerBindingsPanel(
                        settings: widget.settings,
                        colorScheme: colorScheme,
                      ),
                    ],
                    if (showAppearance)
                      _SectionHeader(
                        label: 'Appearance',
                        colorScheme: colorScheme,
                      ),
                    if (_matchesSearch(
                      'Theme System Dark Light',
                      section: 'Appearance',
                    ))
                      _SettingsPanel(
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: SegmentedButton<AppThemeMode>(
                          style: SegmentedButton.styleFrom(
                            shape: buttonBorderShape(widget.settings.style),
                            side: BorderSide(
                              color: colorScheme.primary.withValues(
                                alpha: widget.settings.style == AppStyle.neon
                                    ? 0.55
                                    : 0.3,
                              ),
                              width: widget.settings.style == AppStyle.retro
                                  ? 2
                                  : 1,
                            ),
                            selectedBackgroundColor:
                                colorScheme.primary.withValues(alpha: 0.18),
                            selectedForegroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onSurface,
                            disabledForegroundColor:
                                colorScheme.onSurface.withValues(alpha: 0.65),
                            backgroundColor: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                          ),
                          segments: [
                            ButtonSegment(
                              value: AppThemeMode.system,
                              label: Text(context.l10n.text('System')),
                              icon: const Icon(Icons.brightness_auto),
                              enabled: widget.settings.style != AppStyle.neon,
                            ),
                            ButtonSegment(
                              value: AppThemeMode.dark,
                              label: Text(context.l10n.text('Dark')),
                              icon: const Icon(Icons.dark_mode),
                            ),
                            ButtonSegment(
                              value: AppThemeMode.light,
                              label: Text(context.l10n.text('Light')),
                              icon: const Icon(Icons.light_mode),
                              enabled: widget.settings.style != AppStyle.neon,
                            ),
                          ],
                          selected: {
                            widget.settings.themeMode == AppThemeMode.black
                                ? AppThemeMode.dark
                                : widget.settings.themeMode ==
                                            AppThemeMode.system ||
                                        widget.settings.themeMode ==
                                            AppThemeMode.light
                                    ? widget.settings.themeMode
                                    : AppThemeMode.dark,
                          },
                          onSelectionChanged: (selection) =>
                              widget.settings.setThemeMode(selection.first),
                        ),
                      ),
                    if (_matchesSearch(
                      'Language System default ${_languageNames.values.join(' ')}',
                      section: 'Appearance',
                    ))
                      _SettingTile(
                        label: 'Language',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: const Key('settingsLanguageDropdown'),
                            isExpanded: true,
                            alignment: AlignmentDirectional.centerEnd,
                            value: widget.settings.localeCode ?? 'system',
                            items: [
                              DropdownMenuItem(
                                value: 'system',
                                child: Text(
                                  context.l10n.text('System default'),
                                ),
                              ),
                              for (final entry in _languageNames.entries)
                                DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              widget.settings.setLocaleCode(
                                value == 'system' ? null : value,
                              );
                            },
                          ),
                        ),
                      ),
                    if (_matchesSearch(
                      'Pure Black AMOLED',
                      section: 'Appearance',
                    ))
                      _SettingTile(
                        label: 'Pure Black (AMOLED)',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Switch(
                          value: widget.settings.isBlackMode,
                          onChanged: (value) => widget.settings.setThemeMode(
                            value ? AppThemeMode.black : AppThemeMode.dark,
                          ),
                        ),
                      ),
                    if (_matchesSearch('Style', section: 'Appearance'))
                      _SettingTile(
                        label: 'Style',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: TextButton(
                          onPressed: _pickStyle,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            foregroundColor: colorScheme.onSurface,
                            alignment: Alignment.centerRight,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  context.l10n.text(
                                    _styleLabel(widget.settings.style),
                                  ),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 20),
                            ],
                          ),
                        ),
                      ),
                    if (showMultiplayer)
                      _SectionHeader(
                        label: 'Multiplayer',
                        colorScheme: colorScheme,
                      ),
                    if (_matchesSearch(
                      'Show Opponent Board',
                      section: 'Multiplayer',
                    ))
                      _SettingTile(
                        label: 'Show Opponent Board',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Switch(
                          value: widget.settings.showOpponentBoard,
                          onChanged: (value) =>
                              widget.settings.setShowOpponentBoard(value),
                        ),
                      ),
                    if (_matchesSearch('Play on LAN', section: 'Multiplayer'))
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: panelDecoration(
                          widget.settings.style,
                          colorScheme,
                        ),
                        child: InkWell(
                          borderRadius: panelBorderRadius(
                            widget.settings.style,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MultiplayerDiscoveryScreen(
                                settings: widget.settings,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.wifi,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    context.l10n.text('Play on LAN'),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (showStats)
                      _SectionHeader(label: 'Stats', colorScheme: colorScheme),
                    if (_matchesSearch('High Score', section: 'Stats'))
                      _SettingTile(
                        label: 'High Score',
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                        child: Text(
                          NumberFormat.decimalPattern(
                            Localizations.localeOf(context).toLanguageTag(),
                          ).format(widget.settings.highScore),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    if (showInstructions) ...[
                      _SectionHeader(
                        label: 'Instructions',
                        colorScheme: colorScheme,
                      ),
                      _InstructionsCard(
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                      ),
                    ],
                    if (showAbout) ...[
                      _SectionHeader(label: 'About', colorScheme: colorScheme),
                      _AboutCard(
                        colorScheme: colorScheme,
                        style: widget.settings.style,
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ),
    );
  }
}

SwitchThemeData _switchTheme(AppStyle style, ColorScheme colorScheme) {
  final outlineAlpha = switch (style) {
    AppStyle.classic => 0.65,
    AppStyle.modern => 0.25,
    AppStyle.bubbles => 0.4,
    AppStyle.neon => 0.55,
    AppStyle.retro => 0.8,
  };
  return SwitchThemeData(
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? colorScheme.primary.withValues(alpha: 0.42)
          : colorScheme.surfaceContainerHighest,
    ),
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? colorScheme.primary
          : colorScheme.onSurfaceVariant,
    ),
    trackOutlineColor: WidgetStateProperty.all(
      colorScheme.primary.withValues(alpha: outlineAlpha),
    ),
    trackOutlineWidth: WidgetStateProperty.all(style == AppStyle.retro ? 2 : 1),
  );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;

  const _SectionHeader({required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final icon = _sectionIcon(label);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Text(
            context.l10n.text(label),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _sectionIcon(String label) => switch (label) {
      'Game' => Icons.sports_esports_rounded,
      'Sound' => Icons.graphic_eq_rounded,
      'Gameplay' => Icons.tune_rounded,
      'Controller' => Icons.gamepad_rounded,
      'Appearance' => Icons.palette_rounded,
      'Multiplayer' => Icons.people_alt_rounded,
      'Stats' => Icons.leaderboard_rounded,
      'Instructions' => Icons.menu_book_rounded,
      'About' => Icons.info_outline_rounded,
      _ => Icons.settings_rounded,
    };

class _SettingsPanel extends StatelessWidget {
  final Widget child;
  final ColorScheme colorScheme;
  final AppStyle style;

  const _SettingsPanel({
    required this.child,
    required this.colorScheme,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: panelDecoration(style, colorScheme),
      child: child,
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String label;
  final Widget child;
  final ColorScheme colorScheme;
  final AppStyle style;
  final int labelFlex;
  final int controlFlex;

  const _SettingTile({
    required this.label,
    required this.child,
    required this.colorScheme,
    required this.style,
    this.labelFlex = 6,
    this.controlFlex = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: panelDecoration(style, colorScheme),
      child: Row(
        children: [
          Expanded(
            flex: labelFlex,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(
                      alpha: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    _settingIcon(label),
                    size: 17,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.text(label),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: controlFlex,
            child: Align(alignment: Alignment.centerRight, child: child),
          ),
        ],
      ),
    );
  }
}

IconData _settingIcon(String label) => switch (label) {
      'Music' => Icons.music_note_rounded,
      'Sound Effects' => Icons.volume_up_rounded,
      'Ghost Tile' => Icons.layers_outlined,
      'Enable Hold Piece' => Icons.inventory_2_outlined,
      'Swipe Up to Hold' => Icons.swipe_up_alt_rounded,
      'Continue Saved Game' => Icons.save_outlined,
      'On-Screen Controls' => Icons.touch_app_outlined,
      'Large Board' => Icons.fullscreen_rounded,
      'Starting Speed' => Icons.speed_rounded,
      'Speed per Level' => Icons.trending_up_rounded,
      'Maximum Level' => Icons.vertical_align_top_rounded,
      'Lines per Level' => Icons.format_line_spacing_rounded,
      'Enable Soft Drop' => Icons.keyboard_double_arrow_down_rounded,
      'Back Gesture Holds' => Icons.swipe_right_alt_rounded,
      'Language' => Icons.language_rounded,
      'Pure Black (AMOLED)' => Icons.contrast_rounded,
      'Style' => Icons.auto_awesome_rounded,
      'Show Opponent Board' => Icons.view_sidebar_outlined,
      'High Score' => Icons.emoji_events_outlined,
      _ => Icons.tune_rounded,
    };

class _GameplayValueTile extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final AppStyle style;
  final VoidCallback onTap;

  const _GameplayValueTile({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _SettingTile(
        label: label,
        colorScheme: colorScheme,
        style: style,
        child: TextButton(
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(value),
              const SizedBox(width: 4),
              const Icon(Icons.tune, size: 18),
            ],
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final ColorScheme colorScheme;
  final AppStyle style;
  final VoidCallback onPressed;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.colorScheme,
    required this.style,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? colorScheme.error : colorScheme.primary;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: Text(
        context.l10n.text(label),
        style: TextStyle(color: color, fontSize: 13),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        backgroundColor: color.withValues(
          alpha: style == AppStyle.neon ? 0.08 : 0.04,
        ),
        side: BorderSide(
          color: color.withValues(alpha: style == AppStyle.neon ? 0.55 : 0.32),
          width: style == AppStyle.retro ? 2 : 1,
        ),
        shape: buttonBorderShape(style),
      ),
    );
  }
}

class _ControllerBindingsPanel extends StatelessWidget {
  final SettingsProvider settings;
  final ColorScheme colorScheme;

  const _ControllerBindingsPanel({
    required this.settings,
    required this.colorScheme,
  });

  Future<void> _captureBinding(
    BuildContext context,
    GameplayAction action,
  ) async {
    final key = await showDialog<LogicalKeyboardKey>(
      context: context,
      builder: (dialogContext) =>
          _ControllerKeyDialog(action: action, style: settings.style),
    );
    if (key != null) await settings.setControllerBinding(action, key);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: panelDecoration(settings.style, colorScheme),
      child: Column(
        children: [
          for (final action in GameplayAction.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                minVerticalPadding: 0,
                title: Text(context.l10n.text(action.label)),
                trailing: OutlinedButton(
                  key: Key('controller-binding-${action.name}'),
                  onPressed: () => _captureBinding(context, action),
                  style: OutlinedButton.styleFrom(
                    shape: buttonBorderShape(settings.style),
                    side: BorderSide(
                      color: colorScheme.outline,
                      width: settings.style == AppStyle.retro ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    context.l10n.text(
                      controllerKeyLabel(settings.controllerBindings[action]!),
                    ),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('reset-controller-bindings'),
              onPressed: settings.resetControllerBindings,
              style: TextButton.styleFrom(
                shape: buttonBorderShape(settings.style),
              ),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: Text(context.l10n.text('Reset controller layout')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControllerKeyDialog extends StatefulWidget {
  final GameplayAction action;
  final AppStyle style;

  const _ControllerKeyDialog({required this.action, required this.style});

  @override
  State<_ControllerKeyDialog> createState() => _ControllerKeyDialogState();
}

class _ControllerKeyDialogState extends State<_ControllerKeyDialog> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.pop(context);
          return;
        }
        if (event.deviceType != ui.KeyEventDeviceType.keyboard) {
          Navigator.pop(context, event.logicalKey);
        }
      },
      child: AlertDialog(
        shape: styledDialogShape(widget.style, Theme.of(context).colorScheme),
        title: Text(
          context.l10n.text('Bind {action}', {
            'action': context.l10n.text(widget.action.label),
          }),
        ),
        content: Text(
          context.l10n.text(
            'Press a button or direction on your connected controller.\n\n'
            'Press Escape to cancel.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(shape: buttonBorderShape(widget.style)),
            child: Text(context.l10n.text('Cancel')),
          ),
        ],
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final AppStyle style;

  const _InstructionsCard({required this.colorScheme, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: panelDecoration(style, colorScheme),
      child: Column(
        children: [
          _InstructionRow(
            icon: Icons.swipe,
            label: 'Swipe left / right',
            description: 'Move piece',
            colorScheme: colorScheme,
          ),
          _InstructionRow(
            icon: Icons.swipe_down,
            label: 'Swipe down',
            description: 'Soft drop',
            colorScheme: colorScheme,
          ),
          _InstructionRow(
            icon: Icons.arrow_downward,
            label: 'Fast swipe down',
            description: 'Hard drop',
            colorScheme: colorScheme,
          ),
          _InstructionRow(
            icon: Icons.touch_app,
            label: 'Tap left / right side',
            description: 'Rotate piece',
            colorScheme: colorScheme,
          ),
          _InstructionRow(
            icon: Icons.swipe_up_alt,
            label: 'Tap Hold area',
            description: 'Hold piece',
            colorScheme: colorScheme,
          ),
          _InstructionRow(
            icon: Icons.keyboard,
            label: '← → ↓',
            description: 'Move piece',
            colorScheme: colorScheme,
          ),
          _InstructionRow(
            icon: Icons.keyboard,
            label: '↑ or Z / X',
            description: 'Rotate',
            colorScheme: colorScheme,
          ),
          _InstructionRow(
            icon: Icons.keyboard,
            label: 'Space',
            description: 'Hard drop',
            colorScheme: colorScheme,
          ),
          _InstructionRow(
            icon: Icons.keyboard,
            label: 'C',
            description: 'Hold piece',
            colorScheme: colorScheme,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final AppStyle style;

  const _AboutCard({required this.colorScheme, required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: panelDecoration(style, colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.text('Block Drop'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.text(
              'A free and open-source Tetris clone built with Flutter. '
              'Drop, rotate, and clear lines in this classic puzzle game.',
            ),
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          _LinkRow(
            icon: Icons.code,
            label: 'Source Code',
            url: 'https://github.com/brandonp2412/BlockDrop',
            colorScheme: colorScheme,
          ),
          Divider(
            height: 12,
            thickness: 1,
            color: colorScheme.outline.withAlpha(30),
          ),
          _LinkRow(
            icon: Icons.favorite,
            label: 'Support Development',
            url: 'https://github.com/sponsors/brandonp2412',
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final ColorScheme colorScheme;

  const _LinkRow({
    required this.icon,
    required this.label,
    required this.url,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.text(label),
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(Icons.open_in_new, size: 14, color: colorScheme.primary),
        ],
      ),
    );
  }
}

class _StyleOption extends StatelessWidget {
  final AppStyle style;
  final String label;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _StyleOption({
    required this.style,
    required this.label,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = panelBorderRadius(style);
    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            decoration: panelDecoration(style, colorScheme),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: isSelected
                      ? Icon(Icons.check, size: 16, color: colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.text(label),
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface,
                    letterSpacing: style == AppStyle.retro ? 1.5 : null,
                    fontWeight: style == AppStyle.retro
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final ColorScheme colorScheme;
  final bool isLast;

  const _InstructionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.colorScheme,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.text(label),
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              context.l10n.text(description),
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (!isLast)
          Divider(
            height: 12,
            thickness: 1,
            color: colorScheme.outline.withAlpha(30),
          ),
      ],
    );
  }
}
