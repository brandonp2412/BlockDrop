import 'package:block_drop/multiplayer/multiplayer_game_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MultiplayerGameConfig', () {
    test('encodes shared-pieces game starts with the seed', () {
      const config = MultiplayerGameConfig.sharedPieces(pieceSeed: 123456);

      expect(config.toGameStartMessage(), {
        'type': 'game_start',
        'mode': 'shared_pieces',
        'piece_seed': 123456,
      });
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
    });
  });
}
