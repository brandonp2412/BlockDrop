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

/// Style-aware decoration for general panel/card containers
/// (settings tiles, peer tiles, lobby tiles, etc.).
///
/// Pass [color] to override the default surface fill — useful when a tile
/// needs a highlight (e.g. the "You" lobby row).
BoxDecoration panelDecoration(AppStyle style, ColorScheme cs, {Color? color}) {
  final bg = color ?? cs.surfaceContainerHighest.withAlpha(80);
  switch (style) {
    case AppStyle.classic:
      return BoxDecoration(
        color: bg,
        border: Border.all(color: cs.outline),
      );
    case AppStyle.modern:
      return BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withAlpha(40)),
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
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withAlpha(90), width: 2),
      );
    case AppStyle.neon:
      return BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.outlineVariant.withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      );
    case AppStyle.retro:
      return BoxDecoration(
        color: bg,
        border: Border.all(color: cs.outline, width: 2),
      );
  }
}

/// Returns the [BorderRadius] used by [panelDecoration] for the given style.
/// Use this for InkWell / ClipRRect siblings that must match the container.
BorderRadius panelBorderRadius(AppStyle style) {
  switch (style) {
    case AppStyle.classic:
    case AppStyle.retro:
      return BorderRadius.zero;
    case AppStyle.modern:
      return BorderRadius.circular(12);
    case AppStyle.bubbles:
      return BorderRadius.circular(20);
    case AppStyle.neon:
      return BorderRadius.circular(4);
  }
}

/// Style-aware [ShapeBorder] for [AlertDialog] (and similar overlays).
///
/// Pass [accentColor] to tint the border — e.g. [ColorScheme.error] for a
/// game-over dialog.
ShapeBorder styledDialogShape(
  AppStyle style,
  ColorScheme cs, {
  Color? accentColor,
}) {
  final borderColor = accentColor ?? cs.outline;
  switch (style) {
    case AppStyle.classic:
      return RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
      );
    case AppStyle.modern:
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      );
    case AppStyle.bubbles:
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor.withValues(alpha: 0.5), width: 2),
      );
    case AppStyle.neon:
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: borderColor, width: 1.5),
      );
    case AppStyle.retro:
      return RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 3),
      );
  }
}

/// Style-aware [OutlinedBorder] for buttons (OutlinedButton, FilledButton, etc.).
OutlinedBorder buttonBorderShape(AppStyle style) {
  switch (style) {
    case AppStyle.classic:
    case AppStyle.retro:
      return const RoundedRectangleBorder();
    case AppStyle.modern:
      return RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    case AppStyle.bubbles:
      return RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
    case AppStyle.neon:
      return RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));
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
