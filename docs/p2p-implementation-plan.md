# Direct P2P multiplayer — architecture and acceptance plan

Status: slice 1 architecture and slice 2 TCP direct-join manager completed on 2026-11-03 (NZ). QR joining and real-device P2P gameplay are **not yet proven**.

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
