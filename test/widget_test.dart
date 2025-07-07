// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:block_drop/main.dart';
import 'package:block_drop/widgets/game_board.dart';
import 'package:block_drop/widgets/next_piece_display.dart';

void main() {
  testWidgets('Tetris app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TetrisApp());

    // Verify that our Tetris game starts with score 0.
    expect(find.text('Score: 0'), findsOneWidget);
    expect(find.text('Level: 1'), findsOneWidget);
    expect(find.text('Lines: 0'), findsOneWidget);

    // Verify that the game board is present
    expect(find.byType(GameBoard), findsOneWidget);

    // Verify that the next piece display is present
    expect(find.byType(NextPieceDisplay), findsOneWidget);
  });
}
