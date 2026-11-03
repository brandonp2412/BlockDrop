# LAN match completion: Android/Linux verification

Verified on 3 November 2026 with a Samsung Galaxy S25 (SM-S931B) controlled by ADB and the Flutter Linux application running on Glass.

## Reproduced failure

Before this change, sending a garbage attack into a real match caused both managers to reset to `discovering`, close their peer sockets, and leave their game screens running without a result overlay. Opponent scores reset to zero.

`GameLogic.exportBoardSnapshot()` encodes garbage cells as palette index `8`. The receiver accepted only `0..7`, rejected a valid snapshot as malformed, and reset the connection. The previous match-completion fix could not exchange final scores after that reset.

The fix accepts the existing `0..8` palette. The socket regression test uses actual `GameLogic` garbage boards in both directions and verifies subsequent score updates and game-over messages. It failed before the fix (Pueue #4340) and passed afterward (#4343).

## Device verification

The APK was built through Pueue and updated with `adb install -r`; existing app data was preserved. Debug build number 714 is installed on the phone. Linux ran through `flutter run -d linux --debug` in Pueue (#4342). The APK build succeeded in #4341.

Both apps connected through the real join screen and TCP handshake. Linux hosted at `192.168.1.102:45899`. The phone's VPN remained enabled; Linux observed the phone connection from `10.66.66.3`. This verifies the real Android/Linux application connection to the LAN host, rather than a VPN-disabled Wi-Fi-only route. ADB forwarding was used only to inspect the Dart VM service.

Board rows were prepared through the Dart VM service, then the real line-clear code generated nonzero scores and attacks. Gravity was temporarily stopped to make the scenario repeatable. Scores, opponent boards, garbage, and results used the existing game-screen callbacks and TCP connection. Android top-out was driven by repeated ADB space key events; Linux top-out used repeated calls to the running game's hard-drop method. Neither match injected a game-over flag or a result message.

| Match | Linux result (own / opponent) | Android result (own / opponent) |
| --- | --- | --- |
| Android tops out | Win: 100 / 300 | Loss: 300 / 100 |
| Linux tops out | Loss: 900 / 1,500 | Win: 1,500 / 900 |

Before each top-out, both apps remained `inGame` with live sockets, matching nonzero opponent scores, and nine garbage cells visible in each opponent snapshot. After each top-out, both reached `gameOver`, both result overlays appeared, and the surviving game was paused. Android background/resume preserved both results. Leaving the Linux result after the second match also preserved Android's win and opponent score of 900.

Screenshots:

- Android loses: [Linux win](evidence/lan-match-20261103/android-loses-linux.png), [Android loss](evidence/lan-match-20261103/android-loses-phone.png).
- Linux loses: [Linux loss](evidence/lan-match-20261103/linux-loses-linux.png), [Android win](evidence/lan-match-20261103/linux-loses-phone.png).
- VM state assertions: [first match before](evidence/lan-match-20261103/live-before.json), [first match after](evidence/lan-match-20261103/live-after.json), [second match before](evidence/lan-match-20261103/reverse-before.json), [second match after](evidence/lan-match-20261103/reverse-after.json).

## Required checks

All commands ran through Pueue:

- #4344: `dart format debug_tcp_server.dart lib test integration_test patrol_test test_driver` passed.
- #4345: `flutter analyze` passed.
- #4346: `flutter test` passed: 294 tests, one pre-existing environment-dependent cross-host test skipped.

Both players must receive the updated receiver validation. An older peer can still reject garbage snapshots sent by the updated player.
