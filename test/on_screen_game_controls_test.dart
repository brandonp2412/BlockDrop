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
      await tester.tap(find.bySemanticsLabel(label));
    }

    expect(actions, [
      'left',
      'right',
      'soft',
      'rotate-left',
      'rotate-right',
      'hard',
      'hold',
    ]);
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
