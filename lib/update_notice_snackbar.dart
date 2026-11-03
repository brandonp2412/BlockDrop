import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

/// Builds a short, bounded update announcement with a link to release notes.
SnackBar newVersionSnackBar(
  BuildContext context,
  String version,
  VoidCallback onWhatsNew,
) =>
    SnackBar(
      content: Text('New version $version'),
      behavior: SnackBarBehavior.floating,
      width: MediaQuery.sizeOf(context).width >= 900 ? 360 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      action: SnackBarAction(
        label: context.l10n.text("What's new"),
        onPressed: onWhatsNew,
      ),
      duration: const Duration(seconds: 4),
      persist: false,
    );
