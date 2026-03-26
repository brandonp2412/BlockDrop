import 'package:flutter/material.dart';

import '../settings/settings_provider.dart';

/// Style-aware decoration for hold / next piece preview boxes.
BoxDecoration pieceBoxDecoration(AppStyle style, ColorScheme cs) {
  switch (style) {
    case AppStyle.classic:
      return BoxDecoration(border: Border.all(color: cs.outline));
    case AppStyle.modern:
      return BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline, width: 1),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
    case AppStyle.bubbles:
      return BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.4),
          width: 2,
        ),
      );
    case AppStyle.neon:
      return BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.outlineVariant.withValues(alpha: 0.2),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      );
    case AppStyle.retro:
      return BoxDecoration(border: Border.all(color: cs.outline, width: 2));
  }
}

/// Style-aware decoration for the main game board container.
BoxDecoration boardDecoration(AppStyle style, ColorScheme cs) {
  switch (style) {
    case AppStyle.classic:
      return BoxDecoration(border: Border.all(color: cs.outline, width: 2));
    case AppStyle.modern:
      return BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline, width: 1),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
    case AppStyle.bubbles:
      return BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.4),
          width: 2,
        ),
      );
    case AppStyle.neon:
      return BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cs.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      );
    case AppStyle.retro:
      return BoxDecoration(border: Border.all(color: cs.outline, width: 2));
  }
}
