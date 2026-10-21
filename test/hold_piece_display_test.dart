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
  const boxSize = Size.square(80);

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
            boxSize: boxSize.width,
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

  testWidgets('keeps original preview sizes and centers them in a fixed box', (
    tester,
  ) async {
    await tester.pumpWidget(buildPreview(isAvailable: true));

    expect(
      tester.getSize(find.byKey(const ValueKey('hold-piece-border'))),
      boxSize,
    );
    expect(tester.getSize(find.byType(GridView)), const Size(39, 39));
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
    expect(tester.getSize(find.byType(GridView)), const Size(78, 19.5));
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
  for (final style in AppStyle.values) {
    for (final dimension in [58.0, 80.0, 120.0]) {
      testWidgets('centers odd-width pieces in $dimension boxes with $style',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Center(
            child: HoldPieceDisplay(
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
        final border = find.byKey(const ValueKey('hold-piece-border'));
        expect(tester.getSize(border), Size.square(dimension));
        expect(
            tester.getCenter(find.byType(GridView)), tester.getCenter(border));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
