import 'package:block_drop/models/tetromino.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:block_drop/widgets/next_piece_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cellWidth = 20.0;
  const cellHeight = 21.0;
  const boxSize = Size(94, 98);

  Widget buildPreview(Tetromino piece) {
    return MaterialApp(
      home: Center(
        child: SizedBox.square(
          key: const ValueKey('next-slot'),
          dimension: 120,
          child: NextPieceDisplay(
            piece: piece,
            style: AppStyle.classic,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
          ),
        ),
      ),
    );
  }

  testWidgets('keeps board-sized cells centered in the same fixed box as Hold',
      (
    tester,
  ) async {
    const squarePiece = Tetromino(
      shape: [
        [1, 1],
        [1, 1],
      ],
      color: Colors.yellow,
    );
    await tester.pumpWidget(buildPreview(squarePiece));

    expect(
      tester.getSize(find.byKey(const ValueKey('next-piece-border'))),
      boxSize,
    );
    expect(tester.getSize(find.byType(GridView)), const Size(40, 42));
    expect(
      tester.getCenter(find.byKey(const ValueKey('next-piece-border'))),
      tester.getCenter(find.byKey(const ValueKey('next-slot'))),
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
    await tester.pumpWidget(buildPreview(linePiece));

    expect(
      tester.getSize(find.byKey(const ValueKey('next-piece-border'))),
      boxSize,
    );
    expect(tester.getSize(find.byType(GridView)), const Size(80, 21));
  });
}
