import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../update_notice.dart';

class WhatsNewScreen extends StatefulWidget {
  const WhatsNewScreen({super.key});

  @override
  State<WhatsNewScreen> createState() => _WhatsNewScreenState();
}

class _WhatsNewScreenState extends State<WhatsNewScreen> {
  static const _pageSize = 10;

  bool _showUpdateNotices = true;
  List<String> _changelogPaths = const [];
  List<String> _changelogs = const [];
  int _page = 0;
  bool _isLoading = true;
  String? _loadedLocale;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (_loadedLocale == locale) return;
    _loadedLocale = locale;
    _page = 0;
    _isLoading = true;
    _loadChangelogs();
  }

  Future<void> _loadChangelogs() async {
    final bundle = rootBundle;
    final locale = Localizations.localeOf(context);
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final language = locale.languageCode.toLowerCase();
    final region = locale.countryCode?.toUpperCase();
    final localeDirectory = region == null ? null : '$language-$region';
    final availablePaths = manifest
        .listAssets()
        .where((path) =>
            path.startsWith('metadata/') &&
            path.contains('/changelogs/') &&
            path.endsWith('.txt'))
        .toList();
    final localizedPaths = availablePaths
        .where((path) =>
            localeDirectory != null &&
            path.startsWith('metadata/$localeDirectory/'))
        .toList();
    final languagePaths = availablePaths
        .where((path) =>
            path.startsWith('metadata/$language-') ||
            path.startsWith('metadata/$language/'))
        .toList();
    final paths = (localizedPaths.isNotEmpty
        ? localizedPaths
        : languagePaths.isNotEmpty
            ? languagePaths
            : availablePaths
                .where((path) => path.startsWith('metadata/en-US/'))
                .toList())
      ..sort((a, b) {
        final aVersion = int.tryParse(a.split('/').last.split('.').first) ?? 0;
        final bVersion = int.tryParse(b.split('/').last.split('.').first) ?? 0;
        return bVersion.compareTo(aVersion);
      });
    final pagePaths = paths.skip(_page * _pageSize).take(_pageSize);
    final changelogs = <String>[];
    for (final path in pagePaths) {
      changelogs.add((await bundle.loadString(path)).trim());
    }
    if (!mounted) return;
    setState(() {
      _changelogPaths = paths;
      _changelogs = changelogs;
      _isLoading = false;
    });
  }

  Future<void> _setPage(int page) async {
    final pageCount = (_changelogPaths.length / _pageSize).ceil();
    if (page < 0 || page >= pageCount) return;
    setState(() {
      _page = page;
      _isLoading = true;
    });
    await _loadChangelogs();
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
        body: Column(
          children: [
            SwitchListTile.adaptive(
              title: Text(context.l10n.text('Show update notices')),
              value: _showUpdateNotices,
              onChanged: _setPreference,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _changelogs.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(_changelogs[index]),
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _changelogPaths.length > _pageSize
            ? SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _page > 0 ? () => _setPage(_page - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                        '${_page + 1} / ${(_changelogPaths.length / _pageSize).ceil()}'),
                    IconButton(
                      onPressed:
                          (_page + 1) * _pageSize < _changelogPaths.length
                              ? () => _setPage(_page + 1)
                              : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              )
            : null,
      );
}
