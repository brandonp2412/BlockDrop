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

  for (final opponentFinishesFirst in [true, false]) {
    testWidgets(
        'match stops and sends final score (opponent first: '
        '$opponentFinishesFirst)', (tester) async {
      final manager = _RecordingManager()..state = MultiplayerState.inGame;
      addTearDown(manager.dispose);
      final settings = SettingsProvider();
      await settings.load();
      await tester.pumpWidget(MaterialApp(
        home: MultiplayerGameScreen(manager: manager, settings: settings),
      ));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      final game = tester.widget<GameBoard>(find.byType(GameBoard)).gameLogic;
      game.score = 2400;
      manager.opponentScore = 1200;
      if (opponentFinishesFirst) {
        manager.opponentIsGameOver = true;
        manager.notifyListeners();
      } else {
        game.isGameOver = true;
        game.notifyListeners();
      }
      await tester.pump();
      expect(manager.state, MultiplayerState.gameOver);
      expect(manager.finalScore, 2400);
      expect(manager.snapshotScore, 2400);
      expect(manager.gameOverMessages, 1);
      expect(game.isPaused || game.isGameOver, isTrue);
      expect(find.text('2,400'), findsWidgets);
      expect(find.text('1,200'), findsWidgets);
      final board = game.exportBoardSnapshot();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 2));
      expect(game.exportBoardSnapshot(), board);
      expect(game.score, 2400);
      expect(manager.gameOverMessages, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }

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

class _RecordingManager extends MultiplayerManager {
  _RecordingManager() : super(playerName: 'Player');

  int? snapshotScore;
  int? finalScore;
  int gameOverMessages = 0;

  @override
  void sendBoardSnapshot(List<int> cells, int score, int lines) {
    snapshotScore = score;
    super.sendBoardSnapshot(cells, score, lines);
  }

  @override
  void sendGameOver(int score) {
    gameOverMessages++;
    finalScore = score;
    super.sendGameOver(score);
  }
}
