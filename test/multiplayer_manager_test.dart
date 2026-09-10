import 'package:block_drop/game/gameplay_settings.dart';
import 'package:block_drop/multiplayer/multiplayer_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returning to discovery restores this device gameplay rules', () {
    const localRules = GameplaySettings(
      initialDropSpeed: 1400,
      speedIncrement: 25,
      maximumLevel: 12,
      linesPerLevel: 7,
      softDropEnabled: false,
      holdEnabled: false,
    );
    const remoteRules = GameplaySettings(
      initialDropSpeed: 300,
      speedIncrement: 150,
      maximumLevel: 3,
      linesPerLevel: 2,
      softDropEnabled: true,
      holdEnabled: true,
    );

    final manager = MultiplayerManager(
      playerName: 'Local player',
      gameplaySettings: localRules,
    );

    manager.gameplaySettings = remoteRules;
    manager.enableHold = remoteRules.holdEnabled;
    manager.state = MultiplayerState.inGame;

    manager.backToDiscovery();

    expect(manager.state, MultiplayerState.discovering);
    expect(manager.gameplaySettings.toMap(), localRules.toMap());
    expect(manager.enableHold, isFalse);

    manager.dispose();
  });
}
