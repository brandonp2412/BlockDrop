import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../logging.dart';
import '../game/gameplay_settings.dart';
import 'multiplayer_game_config.dart';
import 'peer.dart';
import 'direct_join_invite.dart';
import 'lan_network.dart';

enum MultiplayerState {
  idle,
  discovering,
  inviting, // we sent an invite, awaiting response
  invited, // we received an invite, user deciding
  inLobby,
  inGame,
  gameOver,
}

/// Operational state of the optional UDP 45678 nearby-host finder.
enum NearbyDiscoveryStatus { off, searching, unavailable }

class MultiplayerManager extends ChangeNotifier {
  static const int _udpPort = 45678;
  static const int _tcpPort = 45679;
  static const int _maxPieceSeed = 0x7fffffff;
  static const int _maxFrameBytes = 16 * 1024;
  final Duration _handshakeTimeout;
  final Future<RawDatagramSocket> Function(InternetAddress, int)?
      _bindDiscoverySocket;
  bool _discoveryStarting = false;

  /// UDP discovery is independent of the direct TCP listener.
  NearbyDiscoveryStatus nearbyStatus = NearbyDiscoveryStatus.off;
  String? nearbyFailure;

  final String playerId;
  final String playerName;
  final String _unknownPlayerName;
  final String _opponentFallbackName;

  MultiplayerState state = MultiplayerState.idle;
  List<Peer> peers = [];
  bool _isHost = false;
  bool get isHost => _isHost;
  int _localPort = _tcpPort;
  int? get hostingPort => _tcpServer?.port;
  String? get pairingToken => _pairingToken;
  DateTime? get pairingExpiresAt => _pairingExpiresAt;
  String? _pairingToken;
  DateTime? _pairingExpiresAt;
  Duration _tokenLifetime = const Duration(minutes: 5);
  final DateTime Function() _now;
  Timer? _handshakeTimer;
  bool _awaitingAuth = false;
  bool _disposed = false;
  final List<int> _incomingFrame = [];
  String? _broadcastAddress;

  /// Piece sequence mode selected for the next multiplayer match.
  MultiplayerGameMode gameMode = MultiplayerGameMode.independent;

  /// Whether hold is enabled for the next multiplayer match.
  bool enableHold = true;

  /// Host-selected gameplay rules for the next match.
  GameplaySettings gameplaySettings = GameplaySettings.defaults;

  /// This device's preferred rules, restored after a guest match finishes.
  GameplaySettings _localGameplaySettings = GameplaySettings.defaults;

  /// Seed shared by both players when [gameMode] is shared pieces.
  int? sharedPieceSeed;

  /// Match configuration the game screen should use when play begins.
  MultiplayerGameConfig get gameConfig {
    if (gameMode == MultiplayerGameMode.sharedPieces &&
        sharedPieceSeed != null) {
      return MultiplayerGameConfig.sharedPieces(
        pieceSeed: sharedPieceSeed!,
        gameplaySettings: gameplaySettings.copyWith(holdEnabled: enableHold),
      );
    }

    return MultiplayerGameConfig.independent(
      gameplaySettings: gameplaySettings.copyWith(holdEnabled: enableHold),
    );
  }

  // Opponent state (updated via board_snapshot messages)
  List<int> opponentBoard = List.filled(200, 0); // 20 rows × 10 cols
  int opponentScore = 0;
  int opponentLines = 0;
  bool opponentIsGameOver = false;
  String? opponentName;

  // Callbacks – set by the UI layer
  void Function(String fromName)? onInviteReceived;
  void Function(int lines)? onGarbageReceived;
  void Function(String error)? onError;

  // Networking
  RawDatagramSocket? _udpSocket;
  StreamSubscription? _udpSub; // keep alive – unsub'd GC would drop packets
  ServerSocket? _tcpServer;
  Socket? _peerSocket;
  StreamSubscription? _socketSub;
  Timer? _announceTimer;
  Timer? _peerExpiryTimer;
  String? _localIp;

  /// Exposed for the UI to display as a diagnostic aid.
  String? get localIp => _localIp;
  String? get broadcastAddress => _broadcastAddress;

  MultiplayerManager({
    required this.playerName,
    GameplaySettings gameplaySettings = GameplaySettings.defaults,
    String unknownPlayerName = 'Unknown',
    String opponentFallbackName = 'Opponent',
    DateTime Function()? now,
    Duration handshakeTimeout = const Duration(seconds: 5),
    Future<RawDatagramSocket> Function(InternetAddress, int)?
        bindDiscoverySocket,
  })  : playerId = _generateId(),
        _now = now ?? DateTime.now,
        _handshakeTimeout = handshakeTimeout,
        _bindDiscoverySocket = bindDiscoverySocket,
        _unknownPlayerName = unknownPlayerName,
        _opponentFallbackName = opponentFallbackName {
    this.gameplaySettings = gameplaySettings;
    _localGameplaySettings = gameplaySettings;
    enableHold = gameplaySettings.holdEnabled;
  }

  static String _generateId() {
    final r = Random.secure();
    return List.generate(
      8,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static int _generatePieceSeed() {
    return Random.secure().nextInt(_maxPieceSeed);
  }

  /// Opens a host TCP listener without binding UDP or requiring discovery.
  Future<void> startHosting({
    int port = _tcpPort,
    Duration tokenLifetime = const Duration(minutes: 5),
  }) async {
    if (_disposed || _tcpServer != null) return;
    if (state != MultiplayerState.idle &&
        state != MultiplayerState.discovering) {
      throw StateError('Cannot host while a match is active');
    }
    if (tokenLifetime <= Duration.zero || port < 0 || port > 65535) {
      throw ArgumentError('Invalid hosting port or token lifetime');
    }
    _tokenLifetime = tokenLifetime;
    await _startTcpServer(port);
    if (_disposed) {
      await _tcpServer?.close();
      _tcpServer = null;
      return;
    }
    _rotatePairingToken();
    _isHost = true;
    state = MultiplayerState.discovering;
    notifyListeners();
  }

  /// Rotates the capability for another guest without restarting the listener.
  void refreshPairingToken() {
    if (_tcpServer == null || _peerSocket != null) {
      throw StateError('No available hosted lobby');
    }
    _rotatePairingToken();
    notifyListeners();
  }

  /// Supplies connection details to the manual-join or QR-code UI.
  DirectJoinInvite hostingInvite(String address) {
    if (_tcpServer == null || _pairingToken == null) {
      throw StateError('Hosting has not started');
    }
    return DirectJoinInvite(
      host: address,
      port: _localPort,
      token: _pairingToken!,
      displayName: playerName,
      expiresAt: _pairingExpiresAt,
    );
  }

  void _rotatePairingToken() {
    if (_tcpServer == null) return;
    _pairingToken = DirectJoinInvite.generateToken();
    _pairingExpiresAt = _now().add(_tokenLifetime);
  }

  /// Starts UDP 45678 discovery on demand without interrupting TCP hosting.
  Future<void> startDiscovery() async {
    if (_discoveryStarting || _disposed) return;
    if (state != MultiplayerState.idle &&
        state != MultiplayerState.discovering) {
      return;
    }
    _discoveryStarting = true;
    try {
      try {
        await startHosting();
      } catch (error, stackTrace) {
        talker.handle(
            error, stackTrace, 'Starting multiplayer TCP host failed');
        onError
            ?.call('Could not listen for TCP multiplayer connections: $error');
        return;
      }
      if (_udpSocket != null || _disposed) return;

      nearbyStatus = NearbyDiscoveryStatus.searching;
      nearbyFailure = null;
      notifyListeners();
      try {
        final lan = await LanNetwork.detect();
        _localIp = lan?.ip;
        _broadcastAddress = lan?.broadcast ?? '255.255.255.255';
      } catch (error, stackTrace) {
        talker.handle(error, stackTrace, 'Physical LAN detection unavailable');
        _localIp = null;
        _broadcastAddress = '255.255.255.255';
      }

      try {
        await LanNetwork.setMulticastEnabled(true);
      } catch (error, stackTrace) {
        talker.handle(error, stackTrace, 'Optional multicast lock unavailable');
      }

      try {
        await _startUdp();
        if (_disposed) {
          _stopUdpDiscovery();
          return;
        }
        _startAnnouncing();
        _startPeerExpiryTimer();
      } catch (error, stackTrace) {
        talker.handle(error, stackTrace, 'Optional UDP discovery bind failed');
        _stopUdpDiscovery();
        nearbyStatus = NearbyDiscoveryStatus.unavailable;
        nearbyFailure = 'UDP port 45678 unavailable: $error. '
            'QR and manual TCP joining remain available.';
        onError?.call(nearbyFailure!);
      }
      if (!_disposed) notifyListeners();
    } finally {
      _discoveryStarting = false;
    }
  }

  Future<void> _startUdp() async {
    final socket = await (_bindDiscoverySocket?.call(
          InternetAddress.anyIPv4,
          _udpPort,
        ) ??
        RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _udpPort,
          reuseAddress: true,
        ));
    try {
      socket.broadcastEnabled = true;
      _udpSocket = socket;
      _udpSub = socket.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final datagram = socket.receive();
            if (datagram != null) _handleUdpDatagram(datagram);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          talker.handle(
              error, stackTrace, 'Optional UDP discovery socket failed');
          _stopUdpDiscovery();
          if (!_disposed) {
            nearbyStatus = NearbyDiscoveryStatus.unavailable;
            nearbyFailure = 'Nearby UDP discovery stopped: $error. '
                'QR and manual TCP joining remain available.';
            onError?.call(nearbyFailure!);
            notifyListeners();
          }
        },
      );
    } catch (_) {
      socket.close();
      rethrow;
    }
  }

  void _stopUdpDiscovery() {
    _announceTimer?.cancel();
    _announceTimer = null;
    _peerExpiryTimer?.cancel();
    _peerExpiryTimer = null;
    _udpSub?.cancel();
    _udpSub = null;
    _udpSocket?.close();
    _udpSocket = null;
    unawaited(LanNetwork.setMulticastEnabled(false));
  }

  Future<void> _startTcpServer(int port) async {
    // Try the preferred port first; if already in use (e.g. another instance
    // on the same machine), fall back to any free port. Using catchError keeps
    // VS Code from pausing on the intermediate SocketException.
    _tcpServer = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
    ).catchError((_) => ServerSocket.bind(InternetAddress.anyIPv4, 0));
    _localPort = _tcpServer!.port;
    _tcpServer!.listen(_handleIncomingConnection);
  }

  void _startAnnouncing() {
    _announceTimer?.cancel();
    _sendAnnounce();
    _announceTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _sendAnnounce(),
    );
  }

  void _sendAnnounce() {
    if (_udpSocket == null) return;
    if (state == MultiplayerState.inGame) return;

    // Retry IP detection on each tick if we haven't found an IP yet (e.g.
    // Wi-Fi finishes connecting after the screen opens).
    if (_localIp == null) {
      LanNetwork.detect().then((lan) {
        if (lan != null && _localIp == null) {
          _localIp = lan.ip;
          _broadcastAddress = lan.broadcast;
          notifyListeners();
        }
      });
    }

    final data = utf8.encode(
      jsonEncode({
        'type': 'announce',
        'id': playerId,
        'name': playerName,
        'port': _localPort,
        if (_pairingToken != null) 'token': _pairingToken,
        'status': state.name,
      }),
    );

    // Directed subnet broadcast (e.g. 192.168.1.255) – works on all platforms.
    if (_broadcastAddress != null) {
      try {
        _udpSocket!.send(data, InternetAddress(_broadcastAddress!), _udpPort);
      } catch (_) {}
    }

    // Limited broadcast fallback – works on Windows/macOS, fails silently on
    // Android (EPERM); harmless since we already have the directed address.
    if (_broadcastAddress != '255.255.255.255') {
      try {
        _udpSocket!.send(data, InternetAddress('255.255.255.255'), _udpPort);
      } catch (_) {}
    }
  }

  void _handleUdpDatagram(Datagram dg) {
    try {
      final msg = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
      if (msg['type'] != 'announce') return;

      final id = msg['id'] as String?;
      if (id == null || id == playerId) return; // ignore own broadcasts

      // Always use the datagram's actual source address – it is always the
      // real sender IP. msg['ip'] can be wrong (e.g. a Hyper-V virtual
      // adapter) and caused stale entries that pointed at unreachable IPs.
      final ip = dg.address.address;
      final port = msg['port'] as int? ?? _tcpPort;
      final name = msg['name'] as String? ?? _unknownPlayerName;
      final status = msg['status'] as String? ?? 'idle';
      final isAvailable = status == 'idle' || status == 'discovering';
      final token = msg['token'] is String ? msg['token'] as String : null;

      final idx = peers.indexWhere((p) => p.id == id);
      if (idx >= 0) {
        if (isAvailable) {
          // Replace the whole object so ip/port stay current.
          peers[idx] = Peer(
            id: id,
            name: name,
            ip: ip,
            port: port,
            lastSeen: DateTime.now(),
            token: token,
          );
        } else {
          peers.removeAt(idx);
        }
      } else if (isAvailable) {
        peers.add(
          Peer(
            id: id,
            name: name,
            ip: ip,
            port: port,
            lastSeen: DateTime.now(),
            token: token,
          ),
        );
      }
      notifyListeners();
    } catch (error, stackTrace) {
      talker.handle(
        error,
        stackTrace,
        'Parsing multiplayer discovery packet failed',
      );
    }
  }

  void _startPeerExpiryTimer() {
    _peerExpiryTimer?.cancel();
    _peerExpiryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final before = peers.length;
      final cutoff = DateTime.now().subtract(const Duration(seconds: 6));
      peers.removeWhere((p) => p.lastSeen.isBefore(cutoff));
      if (peers.length != before) notifyListeners();
    });
  }

  // ── Invite flow ───────────────────────────────────────────────────────────

  /// Joins the TCP listener described by a scanned or manually entered invite.
  Future<void> joinHost(
    DirectJoinInvite invite, {
    String? hostName,
  }) async {
    invite.validate();
    if (_disposed ||
        (state != MultiplayerState.idle &&
            state != MultiplayerState.discovering) ||
        _peerSocket != null) {
      throw StateError('Cannot join while already connected');
    }
    state = MultiplayerState.inviting;
    _isHost = false;
    opponentName = hostName;
    _resetGameConfig();
    notifyListeners();

    try {
      final socket = await Socket.connect(
        invite.host,
        invite.port,
        timeout: _handshakeTimeout,
      );
      if (_disposed || state != MultiplayerState.inviting) {
        socket.destroy();
        return;
      }
      _peerSocket = socket;
      _listenOnSocket(socket);
      _send({
        'type': 'join',
        'version': invite.version,
        'token': invite.token,
        'id': playerId,
        'name': playerName,
      });
      _handshakeTimer = Timer(_handshakeTimeout, () {
        if (_peerSocket == socket && state == MultiplayerState.inviting) {
          _handleDisconnect(socket, reason: 'Host did not respond');
        }
      });
    } catch (error, stackTrace) {
      talker.handle(error, stackTrace, 'Connecting to multiplayer host failed');
      if (!_disposed && state == MultiplayerState.inviting) {
        _resetAfterConnection();
        onError
            ?.call('Could not reach the host. Check its address and firewall.');
      }
    }
  }

  /// Joins a host found through optional UDP discovery.
  Future<void> invitePeer(Peer peer) async {
    final token = peer.token;
    if (token == null) {
      onError?.call('Host uses an older protocol. Ask for a new invitation.');
      return;
    }
    await joinHost(
      DirectJoinInvite(host: peer.ip, port: peer.port, token: token),
      hostName: peer.name,
    );
  }

  void cancelInvite() {
    if (state != MultiplayerState.inviting) return;
    _closeConnection();
    _resetAfterConnection();
  }

  void acceptInvite() {
    if (state != MultiplayerState.invited) return;
    if (!_isHost) return;
    _handshakeTimer?.cancel();
    _send({'type': 'invite_accept', 'name': playerName});
    state = MultiplayerState.inLobby;
    talker.info('Accepted multiplayer invite');
    notifyListeners();
  }

  void rejectInvite() {
    if (state != MultiplayerState.invited) return;
    final socket = _peerSocket;
    if (socket != null) unawaited(_rejectSocket(socket, 'declined'));
    talker.info('Rejected multiplayer invite');
  }

  // ── Lobby / game ──────────────────────────────────────────────────────────

  /// Host only – sends game_start to guest then changes own state.
  void startGame() {
    if (state != MultiplayerState.inLobby || !_isHost) return;
    final config = _createGameStartConfig();
    _send(config.toGameStartMessage());
    state = MultiplayerState.inGame;
    talker.info('Started multiplayer game (${gameMode.wireName})');
    notifyListeners();
  }

  /// Host only – selects the piece sequence mode shown in the lobby.
  void setGameMode(MultiplayerGameMode mode) {
    if (state != MultiplayerState.inLobby || !_isHost) return;
    if (gameMode == mode) return;

    gameMode = mode;
    sharedPieceSeed = null;
    _send({'type': 'game_mode', 'mode': mode.wireName});
    notifyListeners();
  }

  MultiplayerGameConfig _createGameStartConfig() {
    if (gameMode == MultiplayerGameMode.sharedPieces) {
      sharedPieceSeed = _generatePieceSeed();
      return MultiplayerGameConfig.sharedPieces(
        pieceSeed: sharedPieceSeed!,
        gameplaySettings: gameplaySettings.copyWith(holdEnabled: enableHold),
      );
    }

    sharedPieceSeed = null;
    return MultiplayerGameConfig.independent(
      gameplaySettings: gameplaySettings.copyWith(holdEnabled: enableHold),
    );
  }

  void sendGarbage(int lines) {
    if (state != MultiplayerState.inGame || lines <= 0) return;
    _send({'type': 'garbage', 'lines': lines});
  }

  void sendBoardSnapshot(List<int> cells, int score, int lines) {
    if (state != MultiplayerState.inGame) return;
    _send({
      'type': 'board_snapshot',
      'cells': cells,
      'score': score,
      'lines': lines,
    });
  }

  void sendGameOver(int score) {
    if (state != MultiplayerState.inGame) return;
    state = MultiplayerState.gameOver;
    _send({'type': 'game_over', 'score': score});
    notifyListeners();
  }

  /// Returns to discovery after a finished or abandoned match.
  void backToDiscovery() {
    final socket = _peerSocket;
    final subscription = _socketSub;
    _send({'type': 'quit'});
    _closeConnection(destroySocket: false, cancelSubscription: false);
    if (socket != null) unawaited(_closeGracefully(socket, subscription));
    _resetAfterConnection();
  }

  Future<void> _closeGracefully(
    Socket socket,
    StreamSubscription? subscription,
  ) async {
    final peerDone = subscription?.asFuture<void>();
    try {
      await socket.flush().timeout(const Duration(seconds: 2));
      await socket.close().timeout(const Duration(seconds: 2));
      await peerDone?.timeout(const Duration(seconds: 2));
    } catch (_) {
      // A broken peer cannot hold the local socket open indefinitely.
    } finally {
      await subscription?.cancel();
      socket.destroy();
    }
  }

  void _resetAfterConnection({bool rotateToken = true}) {
    state = MultiplayerState.discovering;
    opponentName = null;
    opponentIsGameOver = false;
    opponentBoard = List.filled(200, 0);
    opponentScore = 0;
    opponentLines = 0;
    _isHost = _tcpServer != null;
    _resetGameConfig();
    if (_tcpServer != null && rotateToken) _rotatePairingToken();
    if (!_disposed) notifyListeners();
  }

  // ── TCP socket handling ───────────────────────────────────────────────────

  void _handleIncomingConnection(Socket socket) {
    if (_disposed ||
        state != MultiplayerState.discovering ||
        _peerSocket != null) {
      unawaited(_rejectSocket(socket, 'busy'));
      return;
    }
    _peerSocket = socket;
    _awaitingAuth = true;
    _listenOnSocket(socket);
    _handshakeTimer = Timer(_handshakeTimeout, () {
      if (_peerSocket == socket && _awaitingAuth) {
        unawaited(_rejectSocket(socket, 'timeout'));
      }
    });
  }

  void _listenOnSocket(Socket socket) {
    _socketSub?.cancel();
    _incomingFrame.clear();
    _socketSub = socket.listen(
      (data) => _handleBytes(socket, data),
      onDone: () => _handleDisconnect(socket),
      onError: (_) => _handleDisconnect(socket),
      cancelOnError: true,
    );
  }

  void _handleBytes(Socket socket, List<int> data) {
    if (_peerSocket != socket) return;
    for (final byte in data) {
      if (byte == 10) {
        final frame = List<int>.of(_incomingFrame);
        _incomingFrame.clear();
        if (frame.isEmpty) continue;
        try {
          _handleMessage(socket, utf8.decode(frame));
        } catch (_) {
          unawaited(_rejectSocket(socket, 'malformed'));
        }
        if (_peerSocket != socket) return;
      } else {
        _incomingFrame.add(byte);
        if (_incomingFrame.length > _maxFrameBytes) {
          unawaited(_rejectSocket(socket, 'oversized'));
          return;
        }
      }
    }
  }

  Future<void> _rejectSocket(Socket socket, String reason) async {
    if (_peerSocket == socket) {
      final authenticated = !_awaitingAuth;
      _closeConnection(destroySocket: false);
      _resetAfterConnection(rotateToken: authenticated);
    }
    try {
      socket.add(utf8.encode('${jsonEncode({
            'type': 'join_reject',
            'reason': reason,
          })}\n'));
      await socket.flush().timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // The remote peer may have already closed.
    } finally {
      socket.destroy();
    }
  }

  void _handleMessage(Socket socket, String line) {
    final msg = jsonDecode(line);
    if (msg is! Map<String, dynamic>) {
      throw const FormatException('Expected an object');
    }
    final type = msg['type'] as String?;

    if (_awaitingAuth) {
      if (type != 'join' ||
          msg['version'] != DirectJoinInvite.protocolVersion ||
          msg['token'] is! String ||
          _pairingToken == null ||
          _pairingExpiresAt == null ||
          !_now().isBefore(_pairingExpiresAt!) ||
          !DirectJoinInvite.matchesToken(
            msg['token'] as String,
            _pairingToken!,
          ) ||
          msg['id'] is! String ||
          (msg['id'] as String).isEmpty ||
          msg['name'] is! String ||
          (msg['name'] as String).trim().isEmpty ||
          (msg['name'] as String).length > 64) {
        unawaited(_rejectSocket(socket, 'unauthorized'));
        return;
      }
      _handshakeTimer?.cancel();
      _awaitingAuth = false;
      _isHost = true;
      state = MultiplayerState.invited;
      opponentName = msg['name'] as String;
      notifyListeners();
      onInviteReceived?.call(opponentName!);
      return;
    }

    if (state == MultiplayerState.inviting && !_isHost) {
      if (type == 'join_reject' || type == 'invite_reject') {
        final reason =
            msg['reason'] is String ? msg['reason'] as String : 'declined';
        _closeConnection();
        _resetAfterConnection();
        onError?.call('Join rejected: $reason');
        return;
      }
      if (type != 'invite_accept') {
        unawaited(_rejectSocket(socket, 'unexpected'));
        return;
      }
    } else if (state == MultiplayerState.invited ||
        (state != MultiplayerState.inLobby &&
            state != MultiplayerState.inGame &&
            state != MultiplayerState.gameOver)) {
      unawaited(_rejectSocket(socket, 'unexpected'));
      return;
    }

    switch (type) {
      case 'invite_accept':
        if (state == MultiplayerState.inviting && !_isHost) {
          _handshakeTimer?.cancel();
          opponentName = msg['name'] as String? ?? opponentName;
          state = MultiplayerState.inLobby;
          notifyListeners();
        }

      case 'game_mode':
        if (state == MultiplayerState.inLobby &&
            !_isHost &&
            (msg['mode'] == 'independent' || msg['mode'] == 'shared_pieces')) {
          gameMode = MultiplayerGameModeInfo.fromWireName(msg['mode']);
          sharedPieceSeed = null;
          notifyListeners();
        } else {
          unawaited(_rejectSocket(socket, 'unauthorized'));
        }

      case 'game_start':
        if (state == MultiplayerState.inLobby && !_isHost) {
          final config = MultiplayerGameConfig.fromGameStartMessage(msg);
          gameMode = config.mode;
          sharedPieceSeed = config.pieceSeed;
          enableHold = config.enableHold;
          gameplaySettings = config.gameplaySettings;
          state = MultiplayerState.inGame;
          notifyListeners();
        } else {
          unawaited(_rejectSocket(socket, 'unauthorized'));
        }

      case 'garbage':
        if (state == MultiplayerState.inGame &&
            msg['lines'] is int &&
            (msg['lines'] as int) > 0) {
          onGarbageReceived?.call(msg['lines'] as int);
        } else {
          unawaited(_rejectSocket(socket, 'unexpected'));
        }

      case 'board_snapshot':
        if (state != MultiplayerState.inGame &&
            state != MultiplayerState.gameOver) {
          unawaited(_rejectSocket(socket, 'unexpected'));
          return;
        }
        final raw = msg['cells'];
        if (raw is! List ||
            raw.length != 200 ||
            raw.any((v) => v is! int || v < 0 || v > 7) ||
            msg['score'] is! int ||
            msg['lines'] is! int ||
            (msg['score'] as int) < 0 ||
            (msg['lines'] as int) < 0) {
          unawaited(_rejectSocket(socket, 'malformed'));
          return;
        }
        opponentBoard = raw.cast<int>().toList();
        opponentScore = msg['score'] as int;
        opponentLines = msg['lines'] as int;
        notifyListeners();

      case 'game_over':
        if (state != MultiplayerState.inGame &&
            state != MultiplayerState.gameOver) {
          unawaited(_rejectSocket(socket, 'unexpected'));
          return;
        }
        if (msg['score'] is! int || (msg['score'] as int) < 0) {
          unawaited(_rejectSocket(socket, 'malformed'));
          return;
        }
        opponentIsGameOver = true;
        opponentScore = msg['score'] as int;
        notifyListeners();

      case 'quit':
        _handleDisconnect(socket);
      default:
        unawaited(_rejectSocket(socket, 'unexpected'));
    }
  }

  void _handleDisconnect(Socket socket, {String? reason}) {
    if (_peerSocket != socket) return;
    final wasConnected = _peerSocket != null;
    final authenticated = !_awaitingAuth;
    final prevState = state;
    final prevOpponentName = opponentName;

    _closeConnection();

    if (!wasConnected) return;

    if (reason != null) onError?.call(reason);
    if (prevState == MultiplayerState.inGame ||
        prevState == MultiplayerState.inLobby) {
      talker.warning('Multiplayer peer disconnected during ${prevState.name}');
      onError
          ?.call('${prevOpponentName ?? _opponentFallbackName} disconnected');
    }

    if (prevState == MultiplayerState.gameOver ||
        state == MultiplayerState.gameOver) {
      if (authenticated && _tcpServer != null) _rotatePairingToken();
      notifyListeners();
      return;
    }

    _resetAfterConnection(rotateToken: authenticated);
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _peerSocket?.add(utf8.encode('${jsonEncode(msg)}\n'));
    } catch (_) {}
  }

  void _closeConnection({
    bool destroySocket = true,
    bool cancelSubscription = true,
  }) {
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    _awaitingAuth = false;
    _incomingFrame.clear();
    if (cancelSubscription) _socketSub?.cancel();
    _socketSub = null;
    try {
      if (destroySocket) _peerSocket?.destroy();
    } catch (_) {}
    _peerSocket = null;
  }

  void _resetGameConfig() {
    gameMode = MultiplayerGameMode.independent;
    sharedPieceSeed = null;
    gameplaySettings = _localGameplaySettings;
    enableHold = _localGameplaySettings.holdEnabled;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopUdpDiscovery();
    _closeConnection();
    _tcpServer?.close();
    super.dispose();
  }
}
