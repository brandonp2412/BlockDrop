import 'package:flutter/material.dart';
import '../settings/settings_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (widget.onRestart != null || widget.onQuit != null) ...[
            _SectionHeader(label: 'Game', colorScheme: colorScheme),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Resume',
                      icon: Icons.play_arrow,
                      colorScheme: colorScheme,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: 'Restart',
                      icon: Icons.refresh,
                      colorScheme: colorScheme,
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
            child: Switch(
              value: widget.settings.musicEnabled,
              onChanged: (value) => widget.settings.setMusicEnabled(value),
            ),
          ),
          _SettingTile(
            label: 'Sound Effects',
            colorScheme: colorScheme,
            child: Switch(
              value: widget.settings.sfxEnabled,
              onChanged: (value) => widget.settings.setSfxEnabled(value),
            ),
          ),
          _SectionHeader(label: 'Appearance', colorScheme: colorScheme),
          _SettingTile(
            label: 'Theme',
            colorScheme: colorScheme,
            child: DropdownButton<AppThemeMode>(
              value: widget.settings.themeMode,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              onChanged: (value) {
                if (value != null) widget.settings.setThemeMode(value);
              },
              items: const [
                DropdownMenuItem(
                  value: AppThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.light,
                  child: Text('Light'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.dark,
                  child: Text('Dark'),
                ),
                DropdownMenuItem(
                  value: AppThemeMode.black,
                  child: Text('Black (AMOLED)'),
                ),
              ],
            ),
          ),
          _SettingTile(
            label: 'Style',
            colorScheme: colorScheme,
            badge: 'Coming soon',
            child: DropdownButton<AppStyle>(
              value: widget.settings.style,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              onChanged: (value) {
                if (value != null) widget.settings.setStyle(value);
              },
              items: const [
                DropdownMenuItem(
                  value: AppStyle.classic,
                  child: Text('Classic'),
                ),
                DropdownMenuItem(
                  value: AppStyle.modern,
                  child: Text('Modern'),
                ),
                DropdownMenuItem(
                  value: AppStyle.bubbles,
                  child: Text('Bubbles'),
                ),
              ],
            ),
          ),
          _SectionHeader(label: 'Instructions', colorScheme: colorScheme),
          _InstructionsCard(colorScheme: colorScheme),
          const SizedBox(height: 8),
        ],
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
  final String? badge;

  const _SettingTile({
    required this.label,
    required this.child,
    required this.colorScheme,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withAlpha(40)),
      ),
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
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 10,
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
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
  final VoidCallback onPressed;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.colorScheme,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  final ColorScheme colorScheme;

  const _InstructionsCard({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withAlpha(40)),
      ),
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
