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

  String _versionFromPath(String path) =>
      path.split('/').last.replaceFirst('.txt', '');

  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((part) => int.tryParse(part) ?? 0);
    final bParts = b.split('.').map((part) => int.tryParse(part) ?? 0);
    final aList = aParts.toList();
    final bList = bParts.toList();
    for (var index = 0; index < aList.length || index < bList.length; index++) {
      final aPart = index < aList.length ? aList[index] : 0;
      final bPart = index < bList.length ? bList[index] : 0;
      final comparison = aPart.compareTo(bPart);
      if (comparison != 0) return comparison;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadPreference();
    _loadChangelogs();
  }

  Future<void> _loadChangelogs() async {
    final bundle = rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final availablePaths = manifest
        .listAssets()
        .where((path) =>
            path.startsWith('assets/changelogs/') && path.endsWith('.txt'))
        .toList();
    final paths = availablePaths
      ..sort(
          (a, b) => _compareVersions(_versionFromPath(b), _versionFromPath(a)));
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
                        title: Text(
                          'Version ${_versionFromPath(_changelogPaths[_page * _pageSize + index])}',
                        ),
                        subtitle: Text(_changelogs[index]),
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
