import 'package:block_drop/game/classic_rotation.dart';
import 'package:block_drop/game/game_logic.dart';
import 'package:block_drop/game/gameplay_settings.dart';
import 'package:block_drop/main.dart';
import 'package:block_drop/models/tetromino.dart';
import 'package:block_drop/settings/settings_provider.dart';
import 'package:block_drop/widgets/game_board.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saved Classic game supports keyboard rotation and hold',
      (tester) async {
    final settings = SettingsProvider();
    await settings.load();
    await settings.setGameplaySettings(
        const GameplaySettings(rotationMode: RotationMode.classic));
    await settings.setMusicEnabled(false);
    final source = GameLogic(gameplaySettings: settings.gameplay);
    addTearDown(source.dispose);
    addTearDown(settings.dispose);

    for (var index = 0; index < Tetromino.pieces.length; index++) {
      final piece = Tetromino.pieces[index];
      source.currentPiece = ClassicRotation.pieceAt(piece, 0);
      source.nextPiece = piece;
      source.heldPiece = piece;
      source.currentX = 3;
      source.currentY = 5;
      source.isGameRunning = true;
      await settings.saveGameSnapshot(source.createSnapshot());
      final reloaded = SettingsProvider();
      await reloaded.load();
      await tester.pumpWidget(BlockDropApp(settings: reloaded));
      await tester.pump(const Duration(milliseconds: 300));
      final game = tester.widget<GameBoard>(find.byType(GameBoard)).gameLogic;
      game.gameTimer?.cancel();
      expect(game.currentPiece!.color.runtimeType, Color);
      for (var turn = 1; turn <= 4; turn++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(game.currentPiece!.shape,
            ClassicRotation.pieceAt(piece, turn).shape);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(game.canHold, isFalse);
      expect(game.currentPiece!.shape, ClassicRotation.pieceAt(piece, 0).shape);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      reloaded.dispose();
    }
  });
}
