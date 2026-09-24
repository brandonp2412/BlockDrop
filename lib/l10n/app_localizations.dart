import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'translations.dart';

/// Localized user-facing copy for Block Drop.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale('ru'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// Returns the localization instance attached to [context].
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  /// Translates [source] and substitutes named brace placeholders.
  String text(
    String source, [
    Map<String, Object?> values = const <String, Object?>{},
  ]) {
    final translations = appTranslations[locale.languageCode];
    var template = translations?[source];
    if (template == null) {
      final button = RegExp(r'^Button (.+)$').firstMatch(source);
      if (button != null) {
        template = translations?['Button {id}'];
        values = <String, Object?>{
          ...values,
          'id': button.group(1),
        };
      }
    }
    var result = template ?? source;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return result;
  }

  /// Translates runtime network messages containing dynamic values.
  String runtimeText(String source) {
    final direct = appTranslations[locale.languageCode]?[source];
    if (direct != null) return direct;

    final discovery =
        RegExp(r'^Could not start network discovery: (.*)$').firstMatch(source);
    if (discovery != null) {
      return text('Could not start network discovery: {error}', {
        'error': discovery.group(1),
      });
    }

    final firewall = RegExp(
      r"^Check that Block Drop is allowed in Windows Defender Firewall on (.*)'s device\.$",
    ).firstMatch(source);
    if (firewall != null) {
      return text(
        "Check that Block Drop is allowed in Windows Defender Firewall on {name}'s device.",
        {'name': firewall.group(1)},
      );
    }

    final connection = RegExp(
      r'^Could not connect to (.*)\. Make sure they have Block Drop open\.$',
    ).firstMatch(source);
    if (connection != null) {
      return text(
        'Could not connect to {name}. Make sure they have Block Drop open.',
        {'name': connection.group(1)},
      );
    }

    final disconnected = RegExp(r'^(.*) disconnected$').firstMatch(source);
    if (disconnected != null) {
      return text('{name} disconnected', {'name': disconnected.group(1)});
    }

    return source;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  /// Localized Block Drop strings for this context.
  AppLocalizations get l10n => AppLocalizations.of(this);
}
