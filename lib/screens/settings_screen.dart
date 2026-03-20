import 'package:flutter/material.dart';
import '../settings/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsProvider settings;

  const SettingsScreen({super.key, required this.settings});

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
