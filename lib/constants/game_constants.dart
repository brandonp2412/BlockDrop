import 'package:flutter/material.dart';

class GameConstants {
  static const int boardWidth = 10;
  static const int boardHeight = 20;
  static const int previewRows = 4;
  static const int initialDropSpeed = 800; // milliseconds
  static const int minDropSpeed = 100;
  static const int speedIncrement = 50;
  static const int linesPerLevel = 10;

  // Standard Tetris guideline line-clear scores (multiplied by level)
  static const List<int> lineClearScores = [0, 100, 300, 500, 800];
  static const List<String> lineClearLabels = [
    '',
    'SINGLE',
    'DOUBLE',
    'TRIPLE',
    'TETRIS!'
  ];

  // T-Spin scores for 0–3 lines (multiplied by level)
  static const List<int> tSpinScores = [400, 800, 1200, 1600];
  static const List<String> tSpinLabels = [
    'T-SPIN',
    'T-SPIN SINGLE',
    'T-SPIN DOUBLE',
    'T-SPIN TRIPLE'
  ];

  // Ghost piece sentinel colour (used to identify ghost cells in the board)
  static const Color ghostPieceColor = Color(0xFF87CEEB);

  // Ghost border colours per theme
  static const Color ghostBorderDark = Color(0xFF87CEEB); // 9.25:1 on dark
  static const Color ghostBorderLight = Color(0xFF4A7282); // 4.50:1 on light

  // Light-mode piece colour overrides — all pass WCAG AA 4.5:1 on #EEEEEE
  static final Map<Color, Color> _lightPieceColors = {
    const Color(0xFF00BCD4): const Color(0xFF007787), // cyan  → deep teal
    const Color(0xFFFFEB3B): const Color(0xFF776D1B), // yellow → dark ochre
    const Color(0xFF4CAF50): const Color(0xFF357A38), // green  → forest green
    const Color(0xFF2196F3): const Color(0xFF196FB5), // blue   → medium navy
    const Color(0xFFFF9800): const Color(0xFF9D5D00), // orange → burnt amber
  };

  // Dark-mode piece colour overrides — purple (#9C27B0) only reaches 2.55:1
  // on the dark board; lighten to #BA68C8 which gives 4.52:1
  static final Map<Color, Color> _darkPieceColors = {
    const Color(0xFF9C27B0): const Color(0xFFBA68C8), // purple → purple[300]
  };

  static Color adaptPieceColor(Color color, Brightness brightness) {
    if (brightness == Brightness.light) {
      return _lightPieceColors[color] ?? color;
    } else {
      return _darkPieceColors[color] ?? color;
    }
  }

  static Color ghostBorderColor(Brightness brightness) =>
      brightness == Brightness.light ? ghostBorderLight : ghostBorderDark;
}
