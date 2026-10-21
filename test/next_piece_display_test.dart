import 'package:block_drop/models/tetromino.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:block_drop/widgets/next_piece_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const boxSize = Size.square(80);

  Widget buildPreview(Tetromino piece) {
    return MaterialApp(
      home: Center(
        child: SizedBox.square(
          key: const ValueKey('next-slot'),
          dimension: 120,
          child: NextPieceDisplay(
            piece: piece,
            style: AppStyle.classic,
            boxSize: boxSize.width,
          ),
        ),
      ),
    );
  }

  testWidgets(
      'keeps original preview sizes centered in the same fixed box as Hold', (
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
    expect(tester.getSize(find.byType(GridView)), const Size(39, 39));
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
    expect(tester.getSize(find.byType(GridView)), const Size(78, 19.5));
  });
  for (final style in AppStyle.values) {
    for (final dimension in [58.0, 80.0, 120.0]) {
      testWidgets('centers odd-width pieces in $dimension boxes with $style',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Center(
            child: NextPieceDisplay(
              piece: const Tetromino(
                shape: [
                  [0, 0, 0, 0],
                  [0, 1, 0, 0],
                  [1, 1, 1, 0],
                  [0, 0, 0, 0],
                ],
                color: Colors.purple,
              ),
              style: style,
              boxSize: dimension,
            ),
          ),
        ));
        final border = find.byKey(const ValueKey('next-piece-border'));
        expect(tester.getSize(border), Size.square(dimension));
        expect(
            tester.getCenter(find.byType(GridView)), tester.getCenter(border));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
