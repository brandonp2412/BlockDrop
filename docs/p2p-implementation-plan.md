# Direct P2P multiplayer — architecture and acceptance plan

Status: slices 1–3 integrated; guest QR/manual join and optional UDP isolation implemented in the 2026-11-03 continuation. **Physical camera QR scanning and a finished cross-device match are not yet proven.**

## Constraints and decisions

- All game traffic runs directly between players over the existing newline-delimited JSON-over-TCP protocol. The hosting **player's device** listens. No game server, account, backend, subscription, cloud, externally operated STUN/TURN/relay, or proprietary SDK.
- Primary entry points: **Host game** (QR + plain-text address/port/token) and **Join game** (scan QR or enter address/port/token). A reachable IP connection is still required. QR transfers details; it does **not** open firewalls, bridge isolated Wi-Fi clients or traverse NAT.
- Optional UDP LAN discovery may show hosts; it must never be required for direct host/join. Android Wi-Fi Direct is an optional fallback if normal LAN networking is blocked, not a prerequisite for Android/desktop.
- Preserve Flutter game UI/logic and TCP gameplay messages. No WebSockets without evidence and a separate decision. Linux, Windows, macOS, Android and Waydroid use the same TCP path.
- Select QR generator/scanner packages only after verifying current APIs, free/open-source license and transitive dependencies. Keep manual join usable without camera permission.

## Existing architecture at baseline

| Boundary | Current code and behavior | Gap / risk |
| --- | --- | --- |
| Lifecycle | `lib/screens/multiplayer_discovery_screen.dart` owns `MultiplayerManager`, calls `startDiscovery()` on entry, lists peers and shows invite dialog/lobby | No explicit Host/Join choice or QR/manual entry. UDP startup failure can prevent TCP listening. |
| State | `lib/multiplayer/multiplayer_manager.dart`: `idle → discovering → inviting/invited → inLobby → inGame → gameOver`; disconnect returns to discovery | `invitePeer()` opens outgoing TCP but also sets `_isHost = true`, although the recipient is listening. Host ownership must follow the listener. |
| Listener | `ServerSocket.bind(anyIPv4, 45679)` with ephemeral-port fallback; one accepted peer at a time | Auto-starts alongside UDP. Expose actual port and explicit host lifetime. |
| Discovery | UDP 45678, broadcasts `announce` every 2 s, expires peers after 6 s; uses real datagram source IP | Optional, unauthenticated and may be filtered. Discovery must not bypass join-token checks. |
| Connect/auth | `Socket.connect(peer.ip, peer.port, timeout: 5s)` then immediate unauthenticated `invite` JSON | No token, version, pre-auth timeout or input frame-size bound; incoming gameplay frames have weak state checks. |
| Game wire | `invite`, `invite_accept/reject`, `game_mode`, `game_start`, `garbage`, `board_snapshot`, `game_over`, `quit`, UTF-8 JSON lines | Retain gameplay payloads; add authenticated join handshake, state validation and bounded frames. |
| Gameplay UI | `lib/screens/multiplayer_game_screen.dart` sends board/score/lines every 500 ms and renders opponent board, result and garbage | Not proven between two real devices; no finished two-peer integration test. |
| LAN address | `lib/multiplayer/lan_network.dart`; Android `MainActivity.kt` selects physical Wi-Fi/Ethernet link/prefix and Waydroid interface fallback | Desktop guesses /24 and can choose VPN/Docker/virtual IP. Allow host address selection/copy and honest reachability errors. |
| Android | Main `AndroidManifest.xml` includes Internet/network/Wi-Fi/multicast state permissions and native multicast lock | QR scanner will need a separately vetted camera permission/package; raw TCP needs no platform-specific transport. |
| Dependencies | Flutter, `talker_flutter`, preferences, audio, file picker, `intl`, path provider, URL launcher; test/dev tools incl. Patrol and MSIX | No QR package currently. No networking SaaS found in present P2P code, but this is **not** a full transitive-license or assets audit. |
| Tests | `test/multiplayer_manager_test.dart` 2 state tests, `test/lan_network_test.dart` 2 broadcast tests, `test/multiplayer_game_config_test.dart` 5 config tests | Missing real two-manager TCP, token-negative, bidirectional board and finish tests. |

At the start, Glass `main` matched `origin/main` at `d80534c`, with clean status, one worktree and no previous P2P handoff/branch/commit found.

## Target connection flow

1. **Host** chooses Host game. Detect useful LAN IPv4 addresses and bind `ServerSocket` on `0.0.0.0` (prefer 45679, use actual assigned port); do not await UDP. Generate a new unpredictable **128-bit-or-stronger** token using `Random.secure`. Display a candidate IP, actual port, token and QR. If no address is known, show diagnostics and permit address selection—never imply guaranteed reachability.
2. Encode a versioned join URI, e.g. `blockdrop://join?v=1&host=192.168.1.20&port=45679&token=<random-token>`. No identity/account/private device metadata. Manual Join takes the same address/port/token; never log the token.
3. **Guest** scans/enters details, validates the URI/fields, and connects over ordinary TCP with a deadline. Its first newline-delimited JSON message is `join`, including protocol version, token, guest ID/name. Host validates token/version/shape before showing the request or allowing gameplay traffic. Invalid/oversized/malformed/unauthorized frames or timeout close that peer connection, leaving the host available.
4. Host accepts/declines the authenticated request. On accept, both enter `inLobby`; listener has `_isHost = true`, caller has `_isHost = false`. Reuse `invite_accept`, `game_mode`, `game_start` and existing game payloads where possible. Hosting socket ownership, not who dialled, defines lobby control.
5. Both enter `inGame`, exchange independent board/score/line snapshots and garbage, and reach `game_over`/result. Leaving, canceling and disconnect reset peer state. A fresh host lobby gets a fresh token.
6. Optional UDP can announce a host and offer a Join shortcut; if UDP is blocked, direct joining still works. Its announcement is not authentication. No relay, NAT traversal or online fallback.

The token is an access capability, **not encryption**: plaintext TCP can expose it and game state on an untrusted LAN. Do not advertise end-to-end encryption or Internet-wide reachability.

## Acceptance matrix

| ID | Verification | Required result | Baseline |
| --- | --- | --- | --- |
| A01 | Host with UDP blocked/disabled | TCP listener starts and reports actual bound port | Missing |
| A02 | Scan host QR | Guest reaches authenticated host approval/lobby without Internet/account | Missing |
| A03 | Manual IP + port + token | Same join path and result as QR | Missing |
| A04 | Wrong/expired/missing token, wrong version, malformed or oversized JSON | Host stays available; no unauthorized lobby/game entry; socket closed with useful error | Missing |
| A05 | Host/guest roles and lobby | Listener owns mode/hold/start; caller guest; reject/cancel/leave reset safely | Current roles reversed |
| A06 | UDP unavailable or announcements duplicated | QR/manual path succeeds; discovery remains optional | UDP/TCP coupled |
| A07 | Two loopback managers using real TCP | Join → lobby → both in-game → **distinct bidirectional** board cells/score/lines → terminal game-over observed on both | Missing |
| A08 | Glass Linux ↔ Nox Linux | QR/manual join, bidirectional boards and finished game | Nox endpoint not checked |
| A09 | Glass Linux ↔ Glass Waydroid Android | Establish actual virtual-bridge reachability; finish game or document blocked route | ADB availability only |
| A10 | Glass Linux ↔ Samsung S25 | Full match only after active-session/installation permission check | ADB availability only |
| A11 | Windows/macOS desktop | Native TCP, QR display/manual, firewall diagnostics, cross-platform interoperability | Runtimes unavailable |
| A12 | Real physical two-device match | Observe changed opponent boards and scores **both directions**, then game-over/result **on both**, with time/log evidence | Missing |
| A13 | Internet disabled, firewall/client isolation | Works on a permitted LAN route; accurately reports blocked inbound paths, no fake bypass | Missing |
| A14 | QR dependency and license audit | No proprietary SDK, runtime hosted endpoint, account or subscription; verify QR and transitive licenses | Pending |

**Release gates:** A02, A03, A04, A07 and A12. A TCP connect, mock test or one-way board update is not finished-game proof.

### Device and platform limitations (slice 1)

- Glass Linux is online, with a physical private LAN interface and separate `waydroid0` bridge. A Waydroid address may work from Glass while remaining unreachable from other physical LAN clients: verify actual routes.
- Glass ADB listed a Waydroid Android device and a Samsung Galaxy S25. Samsung was *enumerated only*—no app launch, install, input or session modification.
- Nox Linux, Windows and macOS gameplay endpoints were not exercised. No firewall rules changed. QR cannot defeat NAT, client isolation or a blocked listener.
- The README lists Flutter web generally, but multiplayer imports `dart:io`: browser-to-raw-TCP gameplay is outside this direct-socket scope.

## Baseline test evidence (Glass, 2026-11-03 NZ)

- `git status --short --branch`: clean `main...origin/main`.
- `dart format --output=none --set-exit-if-changed debug_tcp_server.dart lib test integration_test patrol_test test_driver`: 62 files, **0 changes**.
- `flutter analyze`: **no issues** (buildq #3853).
- `flutter test test/multiplayer_manager_test.dart test/lan_network_test.dart test/multiplayer_game_config_test.dart`: **9 passed** (buildq #3852).
- `flutter test`: **254 passed** (buildq #3854).
- No gameplay implementation changed. These results establish the baseline, not P2P end-to-end success.

## Narrow slice 2 handoff (earliest unfinished work)

1. Re-read `AGENTS.md`, Git status/worktrees and this handoff. If a previous slice has since left incomplete work, finish that first.
2. Focus on `lib/multiplayer/multiplayer_manager.dart` and small pure-Dart helpers: explicit `startHosting`/`joinHost`, listener-defined host role, secure per-lobby token and versioned authenticated first frame, bound-port getter, guarded transitions/timeouts and teardown. Decouple TCP from UDP. Retain JSON-over-TCP game messages.
3. Add pure-helper tests and a **real two-manager loopback TCP** test in `test/`: bad token rejected while host remains available; good token → lobby → game; unique board snapshots/score/lines both directions; `game_over` seen by both. Cover reject/cancel/disconnect, port fallback, malformed/oversized input and disabled UDP.
4. Defer QR UI/scanner dependencies and Android Wi-Fi Direct to later slices unless essential to prove transport. Before integrating third-party packages, read up-to-date pub.dev documentation/license per repository `AGENTS.md`.
5. Use `buildq` for costly tests/builds; run required `dart format debug_tcp_server.dart lib test integration_test patrol_test test_driver`, `flutter analyze` and full `flutter test`. Commit successful work with Conventional Commit; if any required check fails, follow repository Give Up rule and leave precise uncommitted failure evidence.
6. Do **not** alter the active Samsung app/session during transport development. Real-device installs require a separate availability/permission check. Leave exact commit, test logs and next remaining work.

Do not call P2P complete until QR/manual authenticated join and a genuinely finished two-device game pass.


## Slice 2 — authenticated TCP direct-join (2026-11-03 NZ)

Implemented transport/manager layer only; QR and manual-entry UI are next. Files: lib/multiplayer/direct_join_invite.dart, multiplayer_manager.dart, peer.dart, discovery-screen cleanup, and test/direct_join_test.dart.

- startHosting(port: ...) starts TCP with no UDP requirement and exposes hostingPort, hostingInvite(address), pairingToken, pairingExpiresAt, and refreshPairingToken(). joinHost(DirectJoinInvite) always initiates a guest connection; the accepting listener governs mode/hold/rules/start.
- DirectJoinInvite round-trips a versioned blockdrop://join URI. Random.secure generates a 192-bit token valid for five minutes by default, checked on the first bounded JSON frame. Authentication and guest-accept timeouts default to five seconds. Invalid/wrong-version/expired/missing token, malformed/oversized frame and overlapping joins are rejected; failed pre-auth attempts do not rotate valid host invites.
- Optional UDP discovery remains available, with TCP starting first. Legacy discovery peers supply their advertised token to joinHost. UDP broadcast includes the token for backward UI discovery; LAN sniffers can see it. This token is an access capability, NOT encryption or secrecy from LAN observers.
- The game wire remains JSON-over-TCP. Frames are bounded to 16 KiB, invalid gameplay transitions rejected. Authenticated disconnect/match reset rotates the invite; reconnect requires refreshed details. No hosted service, SaaS, proprietary SDK or new dependency.

### Local acceptance evidence

- Real two-manager loopback TCP match: host accept, guest lobby, host-controlled game settings, distinct bidirectional 200-cell boards/scores/lines, game-over on both; reconnect with rotated token.
- Negative tests: wrong/expired/missing token, wrong version, malformed/oversized JSON, double joins, timeout, reject/cancel/unexpected disconnect, occupied preferred port, TCP host without UDP.
- Final formatting: 64 files, 0 changes. Final flutter analyze: no issues (buildq #3878). Final full flutter test: 262 passed (buildq #3879). Final targeted suite with timeout case: 8 passed (buildq #3870). Git diff --check: clean. This does not prove a real two-device match.

### Next unfinished stage

1. Explicit Host/Join UI with candidate editable address, actual port, token/expiry, QR and manual fields. Manual must remain available without camera or UDP.
2. Vet QR packages' latest API/docs, licenses/transitives; no proprietary or hosted endpoints. Parse QR via DirectJoinInvite.fromUri; invoke joinHost. Keep firewall/client isolation caveats.
3. Glass/Nox and Waydroid interoperability, then a genuine two-physical-device match showing both boards and terminal results. Do not alter an active Samsung session without checking/permission.
4. Consider auto-refreshing the displayed host invite when its token expires while idle, without rotating it on invalid probes.

## Slice 3 — Host QR and local pairing payload (2026-11-03 NZ)

- Added Host game on the multiplayer screen, using the actual TCP listener port and 192-bit five-minute token. Host UI renders a QR locally with qr_flutter and a selectable/copyable blockdrop://join code; display name and expiry augment versioned IPv4/port/token fields. No remote QR generator.
- Regenerate token/address on demand; a five-second network check hides stale QR on Wi-Fi/Ethernet change or loss. Expired QR stays hidden until refresh. UI explicitly says QR cannot bypass firewall/NAT/client isolation and plain TCP is unencrypted.
- Physical IPv4/prefix detection: Android native Wi-Fi/Ethernet, Linux iproute2 JSON, Windows physical Get-NetAdapter plus Get-NetIPAddress, macOS active enN/ifconfig mask. Unknown prefix returns null, never a guessed /24 or default virtual adapter.
- Dependency licenses, verified at [qr_flutter 4.1.0](https://pub.dev/packages/qr_flutter/versions/4.1.0), [qr 3.0.3](https://pub.dev/packages/qr/versions/3.0.3/license), and [meta](https://pub.dev/packages/meta): all BSD-3-Clause. Local rendering only; no cloud, account, subscription or proprietary SDK.
- Tests cover URI round-trip/version/invalid IP, Linux interface and prefix, macOS prefix, host widget QR/regeneration, missing network. Glass Ethernet physical IP/prefix inspected; Docker and Waydroid interfaces filtered. No Samsung changes.
- This is host QR display only, not guest camera/manual UI or real-device pairing. Prior loopback TCP game verification is not physical-device proof.

### Slice 4 handoff

1. Inspect main, worktrees and status. Finish any prior failing checks first.
2. Implement guest QR scan and manual IPv4/port/token via DirectJoinInvite.fromUri and joinHost. Vet scanner offline/FOSS license and camera permission; manual join works without camera/UDP/Internet.
3. Test expired/changed code, invalid input, access failures, camera denial, host/guest roles. Run format, analyzer, full tests; prove physical two-way match later where devices are available.
4. No Samsung installation/session modification without checking/permission. No hosted relay, cloud or WebSockets.


## Slice 4 — QR scan and manual TCP join (2026-11-03 NZ)

- A guest can scan a locally decoded `blockdrop://join` QR on Android/iOS, paste the full invitation, or enter IPv4/port/token manually. All routes call the existing authenticated JSON-over-TCP `MultiplayerManager.joinHost`; none need UDP or an account. Expired codes, malformed inputs and cancelled scans leave manual entry available.
- The scanner is provided by `flutter_zxing` 3.1.0 and ZXing C++ (local camera processing, no remote decoding endpoint). `flutter_zxing` is MIT; the source package's direct dependencies include BSD-licensed Flutter `camera` and `ffi`, and MIT `image`, with the Flutter `image_picker` family BSD-licensed. Confirmed against local package licenses and [pub.dev package/API documentation](https://pub.dev/packages/flutter_zxing); this is not a complete audit of every transitive native artifact.
- Camera is optional in Android manifest, with iOS usage text. Desktop QR camera support is deliberately unavailable: package documentation requires an additional camera plugin on Linux/macOS and does not confirm Windows support. Pasted codes and manual IP remain available on desktops and Waydroid. No Samsung session was touched.
- Mocked widget scan tests demonstrate routing to a real loopback TCP host and host acceptance; cancellation and invalid scan recovery are tested. These are **not** evidence of a real physical camera reading a displayed QR, a Wi-Fi Direct route, or finished two-device gameplay.
- Glass debug Android APK compiled through buildq #3970. One analyzer gate passed (#3968); the slice-specific test suite passed five tests (#3976). Full regression and final commit should be recorded after all concurrent discovery edits settle.

### Follow-up before release

1. Record a physical camera scan and true two-peer finished game (distinct board/score/line snapshots in both directions, both results). Keep Samsung untouched until the current owner explicitly permits a session change.
2. Prove Glass Linux ↔ Nox Linux and Waydroid routes if available; never infer Waydroid Wi-Fi Direct support.
3. Add optional Android Wi-Fi Direct group owner/peer management only after the normal TCP path and prior slices are integrated. Group formation must not imply firewall, NAT, or client-isolation bypass.


## Slices 4–6 continuation — guest join and optional LAN discovery (2026-11-03 NZ)

### Implementation

- Join game offers manual IPv4/port/192-bit token, pasted versioned blockdrop:// code, and native camera QR scanning on Android/iOS. All three inputs validate using DirectJoinInvite and enter the same authenticated JSON-over-TCP joinHost path. Linux/Windows/macOS retain QR-code paste and manual IP without a camera.
- Camera scan uses [flutter_zxing 3.1.0](https://pub.dev/packages/flutter_zxing) (MIT) with ZXing C++ decoding (open-source). Camera and image-picker Flutter plugin dependencies are BSD-style licensed. The bundled Zint barcode backend is BSD licensed; its GPL frontend is not used. No Google ML Kit, hosted service, account, remote QR generation, or network requests were added for scanning. Android's CAMERA permission/optional camera feature and iOS's camera-use description are declared.
- Cancellation, invalid code, expired code and camera-denial UI all retain manual join. The scanner hardware path remains unproven without a usable camera device.
- Entering Multiplayer starts only the TCP listener. UDP port 45678 is activated explicitly by **Find Nearby**; failed or missing LAN detection, multicast-lock errors, and UDP bind/socket errors do not close or block TCP. UDP discovery status and bind failure are visible, with a retry action. TCP listener failure has its own retry UI.
- Physical WLAN IPv4/prefix detection, directed broadcast, multicast lock release, peer announcement, peer expiry, legacy nearby invite shortcut, existing host control, gameplay JSON and token authentication remain. Optional discovery still broadcasts the bearer token in cleartext, as documented above.
- A test-injectable UDP bind failure verifies that QR/direct TCP completes a game with independent boards/scores/lines and both game-over states despite UDP failure; a real UDP loopback datagram verifies nearby host listing and joining; retry preserves the existing TCP port and token.

### Verification and limitations

- Formatting: dart format debug_tcp_server.dart lib test integration_test patrol_test test_driver.
- Targeted Flutter tests cover manual form, scan-to-TCP, expired/malformed/denied/cancelled scans, failed UDP with bidirectional finished match, actual loopback UDP nearby invitation and listener lifecycle.
- Android debug APK built with the open-source QR scanner included. This proves compilation, **not** a live camera scan.
- Analyzer and full-suite results are recorded in the final Git commit/handoff for this continuation.
- No Samsung installation, launch, active-session change or firewall rule change performed. No cloud relay or NAT-bypass claim.
- Remaining release gates: physically scan a host QR; Glass Linux ↔ another machine/Waydroid and finally two physical devices play to completed game with board/score changes on both; validate real camera permission-denial behavior, firewall isolation and UDP behavior on targeted OSes. Android Wi-Fi Direct remains optional and unimplemented.


## Slice 9 — optional Android Wi-Fi Direct fallback (2026-11-03 NZ)

**Status: implemented and statically verified, physical Wi-Fi Direct interoperability unproven.**

- `WifiDirectBridge.kt` uses Android's built-in [`WifiP2pManager`](https://developer.android.com/develop/connectivity/wifi/wifi-direct) only: group creation, peer discovery/list, connect, cancel/remove group, connection and group info callbacks, and Wi-Fi/peer/connection broadcasts. There is no external relay, host service, SDK or dependency. Android permission requests use NEARBY_WIFI_DEVICES (API 33+) or fine location on older devices. Unsupported devices, Wi-Fi off and denied permission are explicit states/errors.
- `WifiDirectController` uses bounded (25 s) group-formation waits, cancellation, failure cleanup, group-loss notification, and rejects unexpected group ownership. A `createGroup`/`connect` action callback alone is not treated as an established network. Android's reported group-owner IPv4 (with physical P2P interface fallback) is used for the socket route.
- `MultiplayerWifiDirectScreen` offers an opt-in Android fallback. Host creates a group and displays a refreshed local QR containing the **actual** TCP listener port and temporary capability; guest discovers/selects a peer, joins its group, then scans/pastes the host code. Guest verifies the code and connects to Android's live group owner IP via the existing `MultiplayerManager.joinHost` authentication/approval handshake. Standard LAN QR/manual IP and optional UDP discovery remain independent.
- Tests: six **mocked platform-state** controller scenarios (#4017) for owner/guest roles, permission denial, timeout, simultaneous-host conflict and lost group; one **mocked Wi-Fi Direct UI** test (#4040) verifies the QR token/port are forwarded to the TCP manager with the OS-reported P2P IP. The prior `test/direct_join_test.dart` proves independent two-manager **real loopback TCP**, bidirectional board/score/lines and terminal game-over, but does **not** prove physical Wi-Fi Direct.
- Full Glass `flutter test`: **284 passed** (#4042). `flutter analyze`: **no issues** (#4043). Android debug APK **compiled** (#4044); warning about Patrol's Kotlin Gradle Plugin remains unrelated. Full format and Git checks required before committing.
- No Samsung app/session was launched or modified. Waydroid and physical Android hardware were **not** used for Wi-Fi Direct proof; some Android environments do not implement P2P. The app does not claim QR bypasses firewalls, client isolation or NAT.

### Slice 9 outstanding / next handoff

1. On **two physical Android devices with explicit session consent**, form a group, discover peers, connect, test manual/QR token from the owner, verify both board snapshots with distinct cells/score/lines and a completed game result on both devices. Capture actual route addresses, timestamps and errors. Do not use Waydroid as evidence of physical P2P.
2. Exercise live permission denial/recovery, Wi-Fi toggle, group loss during TCP match, timeout/cancel, and simultaneous-host recovery on hardware. Mocked tests cover transitions only; system UX/group negotiation vary by OEM.
3. Verify `Wi-Fi Direct` host advertises a P2P interface address actually reachable by its peer, not a guessed common default. Confirm no permission warnings on the targeted API levels, and run a manual live inspection before a release.
4. Keep existing JSON-over-TCP. Do not claim release gate A12 (finished physical two-device game) passed until there is concrete both-sided proof.

## Slice 10 — Wi-Fi Direct UX and terminal-result recovery (2026-11-03 NZ)

- Wi-Fi Direct fallback is Android-only and remains below QR/manual IP. Its owner/guest setup, system permission prompts, and TCP pairing use the framework implementation from slice 9; desktop has no Wi-Fi Direct button.
- Fixed a TCP finish/quit race: voluntary departure flushes buffered frames and drains the read side before closing. Peer departure from `gameOver` retains the final board, score, line count and result until the local player leaves.
- The multiplayer route now owns the Wi-Fi Direct controller beyond its setup page; it removes the Android P2P group when the user backs out of setup, leaves a game, or closes multiplayer, and handles group loss while the game is active. It does not intentionally change ordinary Wi-Fi or firewall state.
- Tests: local regression with an immediate guest departure preserves terminal data; full combined Flutter suite **285 passed** (Glass buildq #4053), analyzer **clean** (#4052), and follow-up cleanup suite/analyzer **passed** (#4058/#4057).
- Android debug APK compiled (#4054); Waydroid build number 720 compiled (#4055), installed with `adb install -r` (no app-data wipe), launched and navigated from Settings → Play on LAN → Wi-Fi Direct. The expected unsupported-device explanation appeared and the app did not crash. This is a **negative-path smoke test**, not proof that a physical P2P group forms.
- No Samsung session was launched or changed. Physical camera scanning, physical Android P2P and end-to-end finished gameplay on separate devices remain unverified.
- Cross-machine Glass host test (#4051) timed out waiting for a Nox guest because Nox's single build worker was occupied by unrelated job #4336; dependency task #4337 was queued and expired guest test #4338 removed. No direct cross-host success is claimed from this attempt.

### Resumption checklist

1. Confirm the current main branch, its worktrees and running build queues before edits. Keep finished changes integrated; never duplicate Wi-Fi Direct bridge work.
2. Once the Nox worker is free, prepare a new synchronized, unexpired pairing invitation and rerun the direct Glass ↔ Nox JSON/TCP harness (`/tmp/blockdrop-p2p07-cross_test.dart` on both hosts) using the same commit, recording distinct boards/scores/lines and both terminal results. Avoid stale invite reuse.
3. On two physical Android devices only with explicit session consent, prove real Wi-Fi Direct discovery, user approval, owner IPv4 route, manual/QR TCP join, group-loss/recovery and complete bidirectional gameplay. Waydroid does not support this hardware proof.
4. Keep QR/manual IP primary, UDP optional, no relay/server/hosted infrastructure, and no assertion that QR bypasses NAT or client isolation.
