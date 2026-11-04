# P2P slice 11/12 — Nox verification handoff (2026-11-04 NZ)

Status: **automated replay validation passed; cross-endpoint/release verification remains incomplete**. Continue the earliest unfinished real-device acceptance work before claiming later stages done.

## Working state

- Glass MCP tunnel offline; switched to Nox. Nox main `5d0a445` matched `origin/main` and was clean before work.
- Isolated worktree: `/home/brandon/.cache/blockdrop-p2p11-20261104`, branch `verify/blockdrop-p2p-11`, based on `5d0a445`. Do not modify the original main checkout or the older `/tmp/blockdrop-p2p10-nox` worktree.
- New untracked test: `test/p2p_pairing_replay_test.dart`. Exercises the real loopback TCP match, independent/host-authoritative mode, distinct bidirectional board states/scores, both terminal results, stale QR/manual token replay rejection, fresh code rejoin, UDP remaining off, and asserts no Dart HTTP client is constructed during this pairing route. It does not assert that the whole app has no HTTP dependencies or prove physical transport.
- `flutter pub get --offline` succeeded in isolated worktree. `dart format debug_tcp_server.dart lib test integration_test patrol_test test_driver` succeeded (formatting only new test after offline dependency resolution). `dart analyze test/p2p_pairing_replay_test.dart` passed (no issues).
- Other existing tests already cover QR-scanned URI and manual IP joining, malformed/expired codes, camera denial/cancel, UDP bind failure, TCP disconnection/rejoining, independent/shared pieces, garbage and final boards. Avoid duplicating them.

## Real Nox Linux ↔ Waydroid TCP route diagnosis

- Nox Linux physical WLAN: `192.168.1.133`; Waydroid bridge: Linux `192.168.240.1/24`, Android `192.168.240.2/24`.
- Waydroid Android shell `ping 192.168.240.1` passed, but `toybox nc -w 2 192.168.240.1 1` returned `No route to host`; a temporary Nox TCP listener on bridge IP also timed out accepting the Android connection.
- Root cause: Nox nftables has an input hook `policy drop`; inbound `iifname "waydroid0"` is allowed only for DNS/DHCP (UDP 53/67, TCP 53), with other traffic rejected. **Do not weaken/change firewall policy without an explicit network-security decision.** QR does not bypass this restriction.
- Reverse role is reachable: Nox Linux TCP client connected to Android `toybox nc -l -p 48792` at `192.168.240.2`; Android received exact `NOX_TO_WAYDROID_P2P11\\n` payload. This is network reachability only, not actual BlockDrop gameplay.
- Waydroid foreground was SloppaTV test; BlockDrop was installed but never launched. Samsung was enumerated by ADB only; no Samsung app launch/install/session change. No real physical camera or Wi-Fi Direct E2E was attempted.

## Queue state and validation tasks

Nox Pueue group `default` was `Paused` (1 worker), with seven previously queued unrelated tasks `#4488–#4494`. It was deliberately left paused to avoid unexpectedly executing those tasks. The following were accepted into the same buildq queue **but have not run yet**:

1. `#4495`: `flutter test test/p2p_pairing_replay_test.dart`
2. `#4496`: `flutter analyze`
3. `#4497`: `flutter test`
4. `#4498`: `flutter build apk --debug`

Enqueue success is **not** test/build success. Confirm actual Pueue exit codes with `buildq status` / `buildq log ID` after the queue runs. Check the queue ownership before changing its paused state.

## Resume checklist

1. Inspect Git status and concurrent work again. Keep all tests/changes isolated.
2. Once authorized/appropriate to resume the shared Pueue worker, collect `#4495–#4498` exit codes and full logs, fix any failures, then rerun required full format/analyze/test gates. Commit only on genuine success in Conventional Commits style; otherwise leave uncommitted per repo AGENTS.md.
3. With Glass online and a fresh unexpired invitation, run the existing `/tmp/blockdrop-p2p07-cross_test.dart` harness using the latest identical sources on both Glass and Nox, in **both host roles**; capture each side's cells, scores, lines, and game-over timestamps. Avoid stale invitation reuse.
4. Test Nox Linux ↔ Waydroid gameplay only via an explicitly permitted TCP route and without taking over other active app sessions. Do not mistake ICMP or one-way socket reachability for an app match.
5. With explicit session availability/consent and two physical Android devices, perform optical QR pairing and Wi-Fi Direct group and permission tests, each with bidirectional board and finish proof. Samsung-to-Samsung and physical Wi-Fi Direct remain unverified.
6. Windows/macOS TCP/QR/manual-IP interoperability, client-isolation/firewall diagnostics, and full transitive FOSS/license verification remain release follow-ups. No hosted backend, accounts, STUN/TURN, relay or WebSockets.

Existing source/architecture detail: `docs/p2p-implementation-plan.md`.

## Continuation — 2026-11-05 NZ (automated gates, no hardware claim)

- Nox `main` was clean at `2e1e4c2` and matched `origin/main`. This isolated verification branch was fast-forwarded from `5d0a445` to `2e1e4c2` with `git merge --ff-only main`. Existing untracked replay test and handoff were retained. Older slice-10 verification branch remains untouched; its changes must not be blindly merged over newer main.
- Required `dart format debug_tcp_server.dart lib test integration_test patrol_test test_driver` passed: **78 files, 0 changed**. `git diff --check` passed.
- Prior buildq jobs `#4495–#4498` were confirmed **success**: replay test, analyzer, full Flutter tests and Android debug APK at the original `5d0a445` base. These are historical validation, not tests against the newer head.
- On current `2e1e4c2` base, buildq jobs `#4688` (`flutter test test/p2p_pairing_replay_test.dart`), `#4689` (`flutter analyze`) and `#4690` (`flutter test`) all returned **Success**. No changes to the live `main` checkout, firewall, production services, or Android apps.
- Glass execution connector returned HTTP **429** before executing commands and Nox SSH to `glass` failed. Pi was reachable but had no BlockDrop checkout, Dart or Flutter runtime. Cross-host Glass ↔ Nox bidirectional game-over **was not rerun**. This remains the earliest unfinished slice-11 acceptance task.
- Nox's Waydroid Android API **33** had `Stone and Banner` as its visible active app; BlockDrop was installed but **not launched** to avoid stealing an active session. Existing Nox firewall/Waydroid bridge restrictions remain unchanged. Samsung S25 appeared in ADB device enumeration only; no device interaction was performed.
- **Next:** when Glass is online, run a fresh identical-source Nox ↔ Glass TCP match with both host roles and distinct snapshots/scores/lines and terminal results on both peers. If unavailable, use a non-disruptive second endpoint capable of running the real BlockDrop manager, with actual logged result evidence. Confirm there is no competing owner/session before launching an Android app. Only after this stage is genuinely complete proceed to Post-Slice QA 2/5 for Wi-Fi Direct permission/discovery/owner-client/address/teardown; do not claim Waydroid hardware P2P support or two-phone proof.

## Continuation — 2026-11-05 NZ (independent-process TCP proof, not cross-host acceptance)

- Glass connector still returned HTTP 429; direct SSH to Glass's configured LAN IP `192.168.1.102:22` timed out. Pi was available but had neither Dart/Flutter nor an x86-64 emulator. No cross-machine match was run.
- Nox `main` stayed clean at `2e1e4c2` and matched `origin/main`; this work remains isolated on `verify/blockdrop-p2p-11`. Nox already had a Linux BlockDrop process listening on port 45679 and the Android app foreground in Waydroid. Neither active app, its input, nor the firewall was changed; no Samsung interaction.
- Added `test/p2p_cross_endpoint_test.dart` as an opt-in, two-process real-`MultiplayerManager` TCP harness. A host binds an ephemeral port, writes a fresh invitation inside an OS-private temporary directory, accepts its guest, starts independent pieces and sends a distinct board. The guest uses that invitation and sends a different board. Each asserts the entire 200-cell remote board, opponent score/lines, listener-defined role, UDP-off status and both game-over states; `HttpOverrides` rejects Dart HTTP client construction. The token is never printed.
- Two concurrent Flutter test processes on **Nox Linux only**, using `127.0.0.1:41757`, both exited 0. Host saw guest cell 199 = 5, score 456, lines 7; guest saw host cell 0 = 2, score 123, lines 4. Each logged `state: gameOver`, `opponentIsGameOver: true`, `udp: off` at 2026-11-05 04:48:57 NZ. Exact logs: `/home/brandon/.local/state/blockdrop/p2p11-cross-process-20261105/{host,guest}.log`. **This proves independent processes, not two machines, physical controls, or Android/QR gameplay.**
- Required checks on the updated source: `dart format debug_tcp_server.dart lib test integration_test patrol_test test_driver` — 79 files, zero changes; `git diff --check` — clean; Nox buildq `#4693` (`flutter analyze --no-pub`) — no issues; Nox buildq `#4694` (`flutter test --no-pub`) — 305 passed, 1 opt-in test skipped.

### Exact cross-endpoint reproduction

1. On a test **host** running these same sources, use `BLOCKDROP_P2P_ROLE=host BLOCKDROP_P2P_ADDRESS=<reachable-host-IPv4> flutter test --no-pub --reporter expanded test/p2p_cross_endpoint_test.dart`. It prints `BLOCKDROP_P2P_READY inviteFile=<path> host=<ip> port=<port>` without printing the bearer token.
2. Copy that temporary invitation file securely to a private location on the **guest** before the 90-second wait expires. The host's test teardown deletes its temporary directory.
3. On a separate test **guest** with the same source revision, use `BLOCKDROP_P2P_ROLE=guest BLOCKDROP_P2P_INVITE_FILE=<secure-copied-path> flutter test --no-pub --reporter expanded test/p2p_cross_endpoint_test.dart`.
4. Retain both `BLOCKDROP_P2P_PROOF` lines, process exit codes, routes and timestamps; swap physical host/guest roles with a **new** invitation and repeat. Never replay an old bearer token. This is a manager transport test, not optical QR/UI acceptance.

**Earliest unfinished stage remains slice 11**: obtain fresh two-machine matching-source proof with both roles, then non-disruptive Android UI/camera and physical-device acceptance with explicit availability/consent. Only afterward begin Post-Slice QA 2/5, 3/5 and 4/5 fault injection in order. No firewall policy change, active Samsung touch, internet gameplay service or release claim is authorized.
