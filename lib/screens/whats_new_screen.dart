import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../update_notice.dart';

class WhatsNewScreen extends StatefulWidget {
  const WhatsNewScreen({super.key});

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  bool _showUpdateNotices = true;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() =>
          _showUpdateNotices = prefs.getBool(showUpdateNoticesKey) ?? true);
    }
  }

  Future<void> _setPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(showUpdateNoticesKey, enabled);
    if (mounted) setState(() => _showUpdateNotices = enabled);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.text("What's new"))),
        body: ListView(
          children: [
            SwitchListTile.adaptive(
              title: Text(context.l10n.text('Show update notices')),
              value: _showUpdateNotices,
              onChanged: _setPreference,
            ),
            ListTile(
              leading: const Icon(Icons.new_releases_outlined),
              title: Text(context.l10n.text('View release notes')),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => launchUrl(
                Uri.parse('https://github.com/brandonp2412/BlockDrop/releases'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ],
        ),
      );
}
