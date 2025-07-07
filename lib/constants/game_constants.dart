import 'package:flutter/material.dart';

class GameConstants {
  static const int boardWidth = 10;
  static const int boardHeight = 20;
  static const int previewRows = 4;
  static const int initialDropSpeed = 800; // milliseconds
  static const int minDropSpeed = 100;
  static const int speedIncrement = 50;
  static const int pointsPerLine = 100;
  static const int linesPerLevel = 10;

  // Ghost piece color for outline rendering
  static const Color ghostPieceColor = Color(0xFF87CEEB); // Light blue
}
