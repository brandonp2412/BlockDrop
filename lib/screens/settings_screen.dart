import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../settings/settings_provider.dart';
import '../widgets/game_decorations.dart';
import 'multiplayer_discovery_screen.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsProvider settings;
  final VoidCallback? onRestart;
  final VoidCallback? onQuit;

  const SettingsScreen({
    super.key,
    required this.settings,
    this.onRestart,
    this.onQuit,
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

  static String _themeModeLabel(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => 'System',
        AppThemeMode.light => 'Light',
        AppThemeMode.dark => 'Dark',
        AppThemeMode.black => 'Black (AMOLED)',
      };

  static String _styleLabel(AppStyle style) => switch (style) {
        AppStyle.classic => 'Classic',
        AppStyle.modern => 'Modern',
        AppStyle.bubbles => 'Bubbles',
        AppStyle.neon => 'Neon',
        AppStyle.retro => 'Retro',
      };

  void _pickTheme() {
    final isNeon = widget.settings.style == AppStyle.neon;
    final cs = Theme.of(context).colorScheme;
    final options = [
      if (!isNeon) AppThemeMode.system,
      if (!isNeon) AppThemeMode.light,
      AppThemeMode.dark,
      AppThemeMode.black,
    ];
    showDialog<AppThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: styledDialogShape(widget.settings.style, cs),
        title: const Text('Theme'),
        children: options
            .map((m) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, m),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(
                        width: 20,
                        child: m == widget.settings.themeMode
                            ? const Icon(Icons.check, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(_themeModeLabel(m)),
                    ]),
                  ),
                ))
            .toList(),
      ),
    ).then((v) {
      if (v != null) widget.settings.setThemeMode(v);
    });
  }

  void _pickStyle() {
    final cs = Theme.of(context).colorScheme;
    showDialog<AppStyle>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: styledDialogShape(widget.settings.style, cs),
        title: const Text('Style'),
        children: AppStyle.values
            .map((s) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(
                        width: 20,
                        child: s == widget.settings.style
                            ? const Icon(Icons.check, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(_styleLabel(s)),
                    ]),
                  ),
                ))
            .toList(),
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
          padding: const EdgeInsets.symmetric(vertical: 8),
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
            _SectionHeader(label: 'Appearance', colorScheme: colorScheme),
            _SettingTile(
              label: 'Theme',
              colorScheme: colorScheme,
              style: widget.settings.style,
              child: TextButton(
                onPressed: _pickTheme,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: colorScheme.onSurface,
                  alignment: Alignment.centerLeft,
                ),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          _themeModeLabel(widget.settings.themeMode))),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ]),
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
                  Expanded(
                      child:
                          Text(_styleLabel(widget.settings.style))),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ]),
              ),
            ),
            _SectionHeader(label: 'Multiplayer', colorScheme: colorScheme),
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
            _InstructionsCard(colorScheme: colorScheme, style: widget.settings.style),
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
