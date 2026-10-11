import 'package:block_drop/widgets/on_screen_game_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes every configured game action', (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnScreenGameControls(
            onMoveLeft: () => actions.add('left'),
            onMoveRight: () => actions.add('right'),
            onSoftDrop: () => actions.add('soft'),
            onRotateLeft: () => actions.add('rotate-left'),
            onRotateRight: () => actions.add('rotate-right'),
            onHardDrop: () => actions.add('hard'),
            onHold: () => actions.add('hold'),
          ),
        ),
      ),
    );

    for (final label in [
      'Move left',
      'Move right',
      'Soft drop',
      'Rotate left',
      'Rotate right',
      'Hard drop',
      'Hold piece',
    ]) {
      await tester.tap(find.bySemanticsLabel(label).first);
    }

    await tester.tap(find.byKey(const Key('soft-drop-right-control')));

    expect(actions, [
      'left',
      'right',
      'soft',
      'rotate-left',
      'rotate-right',
      'hard',
      'hold',
      'soft',
    ]);
  });

  testWidgets('clusters position actions for two thumbs at narrow widths',
      (tester) async {
    for (final width in [280.0, 360.0, 600.0]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: OnScreenGameControls(
                onMoveLeft: () {},
                onMoveRight: () {},
                onSoftDrop: () {},
                onRotateLeft: () {},
                onRotateRight: () {},
                onHardDrop: () {},
                onHold: () {},
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      Offset center(String key) => tester.getCenter(find.byKey(Key(key)));
      final left = center('move-left-control');
      final right = center('move-right-control');
      final hard = center('hard-drop-control');
      final soft = center('soft-drop-control');
      final rotateLeft = center('rotate-left-control');
      final rotateRight = center('rotate-right-control');
      final hold = center('hold-control');
      final rightSoft = center('soft-drop-right-control');
      expect(left.dx, lessThan(hard.dx));
      expect(hard.dx, lessThan(right.dx));
      expect(hard.dy, lessThan(left.dy));
      expect(left.dy, closeTo(right.dy, 0.1));
      expect(soft.dy, greaterThan(left.dy));
      expect(right.dx, lessThan(rotateLeft.dx));
      expect(rotateLeft.dx, lessThan(hold.dx));
      expect(hold.dx, lessThan(rotateRight.dx));
      expect(hold.dy, lessThan(rotateLeft.dy));
      expect(rightSoft.dy, greaterThan(rotateRight.dy));
      expect(rightSoft.dy, closeTo(soft.dy, 0.1));
      expect(
        tester.getSize(find.byType(OnScreenGameControls)).height,
        closeTo(OnScreenGameControls.heightForWidth(width), 0.1),
      );
    }
  });

  testWidgets('omits hold when the action is unavailable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnScreenGameControls(
            onMoveLeft: () {},
            onMoveRight: () {},
            onSoftDrop: () {},
            onRotateLeft: () {},
            onRotateRight: () {},
            onHardDrop: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Hold piece'), findsNothing);
  });
}
