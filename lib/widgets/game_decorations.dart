import 'package:flutter/material.dart';

import '../constants/game_constants.dart';
import '../settings/settings_provider.dart';

/// Refined Classic keeps the original square block language while adding a
/// restrained top-edge highlight and crisp separation between occupied cells.
BoxDecoration classicPieceDecoration(Color color) {
  final highlight = Color.lerp(color, Colors.white, 0.14)!;
  final edge = Color.lerp(color, Colors.black, 0.38)!;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [highlight, color],
      stops: const [0, 0.34],
    ),
    border: Border(
      top: BorderSide(
        color: highlight.withValues(alpha: 0.82),
        width: 0.7,
      ),
      left: BorderSide(color: edge.withValues(alpha: 0.62), width: 0.55),
      right: BorderSide(color: edge.withValues(alpha: 0.62), width: 0.55),
      bottom: BorderSide(color: edge.withValues(alpha: 0.72), width: 0.55),
    ),
  );
}

/// Style-aware decoration for hold / next piece preview boxes.
BoxDecoration pieceBoxDecoration(AppStyle style, ColorScheme cs) {
  switch (style) {
    case AppStyle.classic:
      return BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
      );
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
            color: cs.outlineVariant.withValues(alpha: 0.1),
            blurRadius: 4,
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
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.55),
          width: 1,
        ),
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
            color: cs.outlineVariant.withValues(alpha: 0.08),
            blurRadius: 4,
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
      return BorderRadius.circular(2);
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
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(
          color: borderColor.withValues(alpha: 0.72),
          width: 1,
        ),
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
      return RoundedRectangleBorder(borderRadius: BorderRadius.circular(2));
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
      return BoxDecoration(
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.72),
          width: 1.25,
        ),
      );
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
            color: cs.primary.withValues(alpha: 0.25),
            blurRadius: 6,
          ),
        ],
      );
    case AppStyle.retro:
      return BoxDecoration(border: Border.all(color: cs.outline, width: 2));
  }
}

/// Reserves the border stroke so animated board cells never paint over it.
EdgeInsets boardContentPadding(AppStyle style) {
  final width = switch (style) {
    AppStyle.modern => 1.0,
    AppStyle.neon => 1.5,
    AppStyle.classic => 1.25,
    AppStyle.bubbles || AppStyle.retro => 2.0,
  };
  return EdgeInsets.all(width);
}

/// Exact cell dimensions used by [GameBoard] inside a decorated board.
Size boardCellSize({
  required double boardWidth,
  required double boardHeight,
  required AppStyle style,
}) {
  final padding = boardContentPadding(style);
  return Size(
    (boardWidth - padding.horizontal) / GameConstants.boardWidth,
    (boardHeight - padding.vertical) / GameConstants.boardHeight,
  );
}

/// Fixed Hold/Next box dimensions for four board-sized cells plus padding.
Size piecePreviewBoxSize(
  Size cellSize,
  AppStyle style, {
  double padding = 6,
}) {
  final borderWidth = switch (style) {
    AppStyle.classic || AppStyle.modern => 1.0,
    AppStyle.neon => 1.5,
    AppStyle.bubbles || AppStyle.retro => 2.0,
  };
  return Size(
    cellSize.width * 4 + padding * 2 + borderWidth * 2,
    cellSize.height * 4 + padding * 2 + borderWidth * 2,
  );
}
