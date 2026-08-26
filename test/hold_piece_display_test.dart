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

  Widget buildPreview({required bool isAvailable}) {
    return MaterialApp(
      home: SizedBox.square(
        dimension: 80,
        child: HoldPieceDisplay(
          piece: heldPiece,
          style: AppStyle.classic,
          isAvailable: isAvailable,
        ),
      ),
    );
  }

  testWidgets('dims and desaturates the piece when hold is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(buildPreview(isAvailable: false));

    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));
  });

  testWidgets('shows the normal piece when hold is available', (tester) async {
    await tester.pumpWidget(buildPreview(isAvailable: true));

    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.byType(Opacity), findsNothing);
  });
}
