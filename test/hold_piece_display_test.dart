import 'package:block_drop/models/tetromino.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:block_drop/widgets/hold_piece_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const heldPiece = Tetromino(
    shape: [
      [1, 1],
      [1, 1],
    ],
    color: Colors.yellow,
  );
  const cellWidth = 20.0;
  const cellHeight = 21.0;
  const boxSize = Size(94, 98);

  Widget buildPreview(
      {required bool isAvailable, Tetromino? piece = heldPiece}) {
    return MaterialApp(
      home: Center(
        child: SizedBox.square(
          key: const ValueKey('hold-slot'),
          dimension: 120,
          child: HoldPieceDisplay(
            piece: piece,
            style: AppStyle.classic,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            isAvailable: isAvailable,
          ),
        ),
      ),
    );
  }

  testWidgets('dims and desaturates the piece when hold is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(buildPreview(isAvailable: false));
    expect(find.bySemanticsLabel('Held piece unavailable'), findsOneWidget);
  });

  testWidgets('shows the normal piece when hold is available', (tester) async {
    await tester.pumpWidget(buildPreview(isAvailable: true));
    expect(find.bySemanticsLabel('Held piece available'), findsOneWidget);
  });

  testWidgets('keeps board-sized cells and centers them in a fixed box', (
    tester,
  ) async {
    await tester.pumpWidget(buildPreview(isAvailable: true));

    expect(
      tester.getSize(find.byKey(const ValueKey('hold-piece-border'))),
      boxSize,
    );
    expect(tester.getSize(find.byType(GridView)), const Size(40, 42));
    expect(
      tester.getCenter(find.byKey(const ValueKey('hold-piece-border'))),
      tester.getCenter(find.byKey(const ValueKey('hold-slot'))),
    );

    const linePiece = Tetromino(
      shape: [
        [0, 0, 0, 0],
        [1, 1, 1, 1],
        [0, 0, 0, 0],
        [0, 0, 0, 0],
      ],
      color: Colors.cyan,
    );
    await tester.pumpWidget(
      buildPreview(isAvailable: true, piece: linePiece),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('hold-piece-border'))),
      boxSize,
    );
    expect(tester.getSize(find.byType(GridView)), const Size(80, 21));
  });

  testWidgets('shows the empty hold box before a piece has been held', (
    tester,
  ) async {
    await tester.pumpWidget(buildPreview(isAvailable: true, piece: null));
    expect(find.byKey(const ValueKey('hold-piece-border')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('hold-piece-border'))),
      boxSize,
    );
  });
}
