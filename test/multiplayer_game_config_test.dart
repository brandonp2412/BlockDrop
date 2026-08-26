import 'package:block_drop/multiplayer/multiplayer_game_config.dart';
import 'package:block_drop/game/gameplay_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultiplayerGameConfig', () {
    test('encodes shared-pieces game starts with the seed', () {
      const config = MultiplayerGameConfig.sharedPieces(
        pieceSeed: 123456,
        enableHold: false,
      );

      expect(config.toGameStartMessage(), {
        'type': 'game_start',
        'mode': 'shared_pieces',
        'piece_seed': 123456,
        'enable_hold': false,
        'gameplay_settings': {
          'initial_drop_speed': 800,
          'speed_increment': 50,
          'maximum_level': 20,
          'lines_per_level': 10,
          'soft_drop_enabled': true,
          'hold_enabled': false,
          'hold_interaction_mode': 'panel_and_back',
        },
      });
    });

    test('round trips all host gameplay rules', () {
      const rules = GameplaySettings(
        initialDropSpeed: 1200,
        speedIncrement: 20,
        maximumLevel: GameplaySettings.unlimitedLevels,
        linesPerLevel: 6,
        softDropEnabled: false,
        holdEnabled: true,
        holdInteractionMode: HoldInteractionMode.panelOnly,
      );
      const sent = MultiplayerGameConfig.independent(
        gameplaySettings: rules,
      );

      final received = MultiplayerGameConfig.fromGameStartMessage(
        sent.toGameStartMessage(),
      );

      expect(received.gameplaySettings.initialDropSpeed, 1200);
      expect(received.gameplaySettings.speedIncrement, 20);
      expect(received.gameplaySettings.maximumLevel, 0);
      expect(received.gameplaySettings.linesPerLevel, 6);
      expect(received.gameplaySettings.softDropEnabled, false);
      expect(
        received.gameplaySettings.holdInteractionMode,
        HoldInteractionMode.panelOnly,
      );
    });

    test('decodes shared-pieces game starts into deterministic piece bags', () {
      final config = MultiplayerGameConfig.fromGameStartMessage({
        'type': 'game_start',
        'mode': 'shared_pieces',
        'piece_seed': 2026,
      });

      final firstBag = config.createPieceBag();
      final secondBag = config.createPieceBag();
      final firstSequence = List.generate(14, (_) => firstBag.next().color);
      final secondSequence = List.generate(14, (_) => secondBag.next().color);

      expect(config.mode, MultiplayerGameMode.sharedPieces);
      expect(config.pieceSeed, 2026);
      expect(firstSequence, equals(secondSequence));
    });

    test('decodes legacy game starts as independent pieces', () {
      final config = MultiplayerGameConfig.fromGameStartMessage({
        'type': 'game_start',
      });

      expect(config.mode, MultiplayerGameMode.independent);
      expect(config.pieceSeed, isNull);
      expect(config.enableHold, true);
    });

    test('decodes enable-hold from a game start payload', () {
      final config = MultiplayerGameConfig.fromGameStartMessage({
        'type': 'game_start',
        'mode': 'independent',
        'enable_hold': false,
      });

      expect(config.enableHold, false);
      expect(config.mode, MultiplayerGameMode.independent);
    });
  });
}
