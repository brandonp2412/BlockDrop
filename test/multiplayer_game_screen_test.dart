import 'package:block_drop/multiplayer/multiplayer_manager.dart';
import 'package:block_drop/screens/multiplayer_game_screen.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:block_drop/widgets/game_board.dart';
import 'package:block_drop/widgets/opponent_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [
    const Size(393, 852),
    const Size(960, 1080),
    const Size(960, 540),
    const Size(540, 960),
  ]) {
    testWidgets('multiplayer fits and supports touch slams at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final manager = MultiplayerManager(playerName: 'Player');
      addTearDown(manager.dispose);
      final settings = SettingsProvider();
      await settings.load();
      await tester.pumpWidget(MaterialApp(
        home: MultiplayerGameScreen(manager: manager, settings: settings),
      ));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      for (final type in [GameBoard, OpponentBoard]) {
        final rect = tester.getRect(find.byType(type));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
      final game = tester.widget<GameBoard>(find.byType(GameBoard)).gameLogic;
      game.gameTimer?.cancel();
      for (final type in [GameBoard, OpponentBoard]) {
        game.isNewPieceGracePeriod = false;
        final occupiedBefore =
            game.board.expand((row) => row).whereType<Color>().length;
        final area = tester.getRect(find.byType(type));
        await tester.flingFrom(
          Offset(area.center.dx, area.top + area.height * 0.4),
          const Offset(0, 150),
          1800,
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          game.board.expand((row) => row).whereType<Color>().length,
          greaterThan(occupiedBefore),
          reason: 'Slams starting over $type should reach the game',
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
