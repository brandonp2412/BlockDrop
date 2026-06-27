import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../settings/settings_provider.dart';
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
        title: const Text('Style'),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppStyle.values.map((s) {
            final isSelected = s == widget.settings.style;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _StyleOption(
                style: s,
                label: _styleLabel(s),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 48),
          // Large scrollCacheExtent ensures all children are laid out off-screen so
          // Android TV D-pad focus traversal can reach items below the viewport.
          scrollCacheExtent: const ScrollCacheExtent.pixels(3000),
          children: [
            if (widget.onRestart != null || widget.onQuit != null) ...[
              _SectionHeader(label: 'Game', colorScheme: colorScheme),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            _SectionHeader(label: 'Sound', colorScheme: colorScheme),
            _SettingTile(
              label: 'Music',
              colorScheme: colorScheme,
              style: widget.settings.style,
              child: Switch(
                value: widget.settings.musicEnabled,
                onChanged: (value) => widget.settings.setMusicEnabled(value),
              ),
            ),
            _SettingTile(
              label: 'Sound Effects',
              colorScheme: colorScheme,
              style: widget.settings.style,
              child: Switch(
                value: widget.settings.sfxEnabled,
                onChanged: (value) => widget.settings.setSfxEnabled(value),
              ),
            ),
            _SectionHeader(label: 'Gameplay', colorScheme: colorScheme),
            _SettingTile(
              label: 'Ghost Tile',
              colorScheme: colorScheme,
              style: widget.settings.style,
              child: Switch(
                value: widget.settings.showGhostTile,
                onChanged: (value) => widget.settings.setShowGhostTile(value),
              ),
            ),
            _SectionHeader(label: 'Appearance', colorScheme: colorScheme),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SegmentedButton<AppThemeMode>(
                style: SegmentedButton.styleFrom(
                  shape: buttonBorderShape(widget.settings.style),
                ),
                segments: [
                  ButtonSegment(
                    value: AppThemeMode.system,
                    label: const Text('System'),
                    icon: const Icon(Icons.brightness_auto),
                    enabled: widget.settings.style != AppStyle.neon,
                  ),
                  const ButtonSegment(
                    value: AppThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.light,
                    label: const Text('Light'),
                    icon: const Icon(Icons.light_mode),
                    enabled: widget.settings.style != AppStyle.neon,
                  ),
                ],
                selected: {
                  widget.settings.themeMode == AppThemeMode.black
                      ? AppThemeMode.dark
                      : widget.settings.themeMode == AppThemeMode.system ||
                              widget.settings.themeMode == AppThemeMode.light
                          ? widget.settings.themeMode
                          : AppThemeMode.dark,
                },
                onSelectionChanged: (selection) =>
                    widget.settings.setThemeMode(selection.first),
              ),
            ),
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
            _SettingTile(
              label: 'Style',
              colorScheme: colorScheme,
              style: widget.settings.style,
              child: TextButton(
                onPressed: _pickStyle,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: colorScheme.onSurface,
                  alignment: Alignment.centerLeft,
                ),
                child: Row(children: [
                  Expanded(child: Text(_styleLabel(widget.settings.style))),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ]),
              ),
            ),
            _SectionHeader(label: 'Multiplayer', colorScheme: colorScheme),
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
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: panelDecoration(widget.settings.style, colorScheme),
              child: InkWell(
                borderRadius: panelBorderRadius(widget.settings.style),
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
                      Icon(Icons.wifi, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Play on LAN',
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
            _SectionHeader(label: 'Stats', colorScheme: colorScheme),
            _SettingTile(
              label: 'High Score',
              colorScheme: colorScheme,
              style: widget.settings.style,
              child: Text(
                NumberFormat.decimalPattern('en_US')
                    .format(widget.settings.highScore),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
            _SectionHeader(label: 'Instructions', colorScheme: colorScheme),
            _InstructionsCard(
                colorScheme: colorScheme, style: widget.settings.style),
            _SectionHeader(label: 'About', colorScheme: colorScheme),
            _AboutCard(colorScheme: colorScheme, style: widget.settings.style),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;

  const _SectionHeader({required this.label, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String label;
  final Widget child;
  final ColorScheme colorScheme;
  final AppStyle style;

  const _SettingTile({
    required this.label,
    required this.child,
    required this.colorScheme,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: panelDecoration(style, colorScheme),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 3, child: child),
        ],
      ),
    );
  }
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
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        side: BorderSide(color: color.withAlpha(80)),
        shape: buttonBorderShape(style),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: panelDecoration(style, colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Block Drop',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A free and open-source Tetris clone built with Flutter. '
            'Drop, rotate, and clear lines in this classic puzzle game.',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _LinkRow(
            icon: Icons.code,
            label: 'Source Code',
            url: 'https://github.com/brandonp2412/BlockDrop',
            colorScheme: colorScheme,
          ),
          Divider(
            height: 16,
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
              label,
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
                  label,
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
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (!isLast)
          Divider(
            height: 16,
            thickness: 1,
            color: colorScheme.outline.withAlpha(30),
          ),
      ],
    );
  }
}
