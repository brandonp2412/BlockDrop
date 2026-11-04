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
