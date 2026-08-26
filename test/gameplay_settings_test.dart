import 'package:block_drop/game/game_logic.dart';
import 'package:block_drop/game/gameplay_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameplaySettings', () {
    test('calculates progression and clamps the configured maximum level', () {
      const rules = GameplaySettings(
        initialDropSpeed: 1000,
        speedIncrement: 100,
        maximumLevel: 3,
        linesPerLevel: 4,
      );

      expect(rules.levelForLines(0), 1);
      expect(rules.levelForLines(4), 2);
      expect(rules.levelForLines(40), 3);
      expect(rules.dropSpeedForLevel(1), 1000);
      expect(rules.dropSpeedForLevel(3), 800);
      expect(rules.dropSpeedForLevel(99), 100);
    });

    test('allows effectively unlimited progression', () {
      const rules = GameplaySettings(
        maximumLevel: GameplaySettings.unlimitedLevels,
        linesPerLevel: 2,
      );

      expect(rules.levelForLines(398), 200);
    });

    test('disabled soft drop ignores player input but gravity still moves', () {
      final logic = GameLogic(
        gameplaySettings: const GameplaySettings(softDropEnabled: false),
      )..startGame();
      logic.isNewPieceGracePeriod = false;
      final startingY = logic.currentY;

      logic.softDrop();
      expect(logic.currentY, startingY);

      logic.movePieceDown();
      expect(logic.currentY, startingY + 1);
      logic.dispose();
    });

    test('new games use custom starting speed', () {
      final logic = GameLogic(
        gameplaySettings: const GameplaySettings(initialDropSpeed: 1500),
      )..startGame();

      expect(logic.dropSpeed, 1500);
      logic.dispose();
    });
  });
}
