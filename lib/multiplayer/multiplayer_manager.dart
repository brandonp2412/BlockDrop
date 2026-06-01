import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'peer.dart';

enum MultiplayerState {
  idle,
  discovering,
  inviting, // we sent an invite, awaiting response
  invited, // we received an invite, user deciding
  inLobby,
  inGame,
  gameOver,
}

class MultiplayerManager extends ChangeNotifier {
  static const int _udpPort = 45678;
  static const int _tcpPort = 45679;

  final String playerId;
  final String playerName;

  MultiplayerState state = MultiplayerState.idle;
  List<Peer> peers = [];
  bool _isHost = false;
  bool get isHost => _isHost;
  int _localPort = _tcpPort;
  String? _broadcastAddress;

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

  MultiplayerManager({required this.playerName}) : playerId = _generateId();

  static String _generateId() {
    final r = Random.secure();
    return List.generate(
      8,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  // ── Discovery ────────────────────────────────────────────────────────────

  Future<void> startDiscovery() async {
    if (state != MultiplayerState.idle) return;
    state = MultiplayerState.discovering;
    notifyListeners();

    try {
      _localIp = await _getLocalIp();
      _broadcastAddress =
          _localIp != null ? _directedBroadcast(_localIp!) : '255.255.255.255';
      await _startUdp();
      await _startTcpServer();
      _startAnnouncing();
      _startPeerExpiryTimer();
    } catch (e) {
      state = MultiplayerState.idle;
      onError?.call('Could not start network discovery: $e');
      notifyListeners();
    }
  }

  /// Converts a local IP like 192.168.1.125 → 192.168.1.255 (directed /24 broadcast).
  /// Android rejects 255.255.255.255 (limited broadcast) with EPERM; directed
  /// subnet broadcast works on both Android and Windows/macOS.
  static String _directedBroadcast(String localIp) {
    final parts = localIp.split('.');
    if (parts.length == 4) return '${parts[0]}.${parts[1]}.${parts[2]}.255';
    return '255.255.255.255';
  }

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      // Collect candidates by priority bucket so virtual adapters (172.x from
      // Hyper-V / VirtualBox) don't shadow the real Wi-Fi / Ethernet address.
      String? best192;
      String? best10;
      String? best172;
      String? fallbackAny; // any non-loopback IPv4 (covers unusual ranges)
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.')) {
            best192 ??= ip;
          } else if (ip.startsWith('10.')) {
            best10 ??= ip;
          } else if (RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip)) {
            best172 ??= ip;
          } else {
            fallbackAny ??= ip;
          }
        }
      }
      return best192 ?? best10 ?? best172 ?? fallbackAny;
    } catch (_) {}
    return null;
  }

  Future<void> _startUdp() async {
    _udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _udpPort,
      reuseAddress: true,
    );
    _udpSocket!.broadcastEnabled = true;
    _udpSub = _udpSocket!.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket?.receive();
          if (dg != null) _handleUdpDatagram(dg);
        }
      },
      onError: (_) {},
    );
  }

  Future<void> _startTcpServer() async {
    // Try the preferred port first; if already in use (e.g. another instance
    // on the same machine), fall back to any free port. Using catchError keeps
    // VS Code from pausing on the intermediate SocketException.
    _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, _tcpPort)
        .catchError((_) => ServerSocket.bind(InternetAddress.anyIPv4, 0));
    _localPort = _tcpServer!.port;
    _tcpServer!.listen(_handleIncomingConnection);
  }

  void _startAnnouncing() {
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
      _getLocalIp().then((ip) {
        if (ip != null && _localIp == null) {
          _localIp = ip;
          _broadcastAddress = _directedBroadcast(ip);
          notifyListeners();
        }
      });
    }

    final data = utf8.encode(jsonEncode({
      'type': 'announce',
      'id': playerId,
      'name': playerName,
      'port': _localPort,
      'status': state.name,
    }));

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
      final name = msg['name'] as String? ?? 'Unknown';
      final status = msg['status'] as String? ?? 'idle';
      final isAvailable = status == 'idle' || status == 'discovering';

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
          );
        } else {
          peers.removeAt(idx);
        }
      } else if (isAvailable) {
        peers.add(Peer(
          id: id,
          name: name,
          ip: ip,
          port: port,
          lastSeen: DateTime.now(),
        ));
      }
      notifyListeners();
    } catch (_) {}
  }

  void _startPeerExpiryTimer() {
    _peerExpiryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final before = peers.length;
      final cutoff = DateTime.now().subtract(const Duration(seconds: 6));
      peers.removeWhere((p) => p.lastSeen.isBefore(cutoff));
      if (peers.length != before) notifyListeners();
    });
  }

  // ── Invite flow ───────────────────────────────────────────────────────────

  Future<void> invitePeer(Peer peer) async {
    if (state != MultiplayerState.discovering) return;
    state = MultiplayerState.inviting;
    opponentName = peer.name;
    _isHost = true;
    notifyListeners();

    try {
      final socket = await Socket.connect(
        peer.ip,
        peer.port,
        timeout: const Duration(seconds: 5),
      );
      if (state != MultiplayerState.inviting) {
        socket.destroy();
        return;
      }
      _peerSocket = socket;
      _listenOnSocket(socket);
      _send({'type': 'invite', 'name': playerName, 'id': playerId});
    } catch (_) {
      if (state == MultiplayerState.inviting) {
        state = MultiplayerState.discovering;
        opponentName = null;
        _isHost = false;
        notifyListeners();
        final hint = Platform.isWindows
            ? 'Check that Block Drop is allowed in Windows Defender Firewall on ${peer.name}\'s device.'
            : 'Could not connect to ${peer.name}. Make sure they have Block Drop open.';
        onError?.call(hint);
      }
    }
  }

  void cancelInvite() {
    if (state != MultiplayerState.inviting) return;
    _closeConnection();
    state = MultiplayerState.discovering;
    opponentName = null;
    _isHost = false;
    notifyListeners();
  }

  void acceptInvite() {
    if (state != MultiplayerState.invited) return;
    _send({'type': 'invite_accept', 'name': playerName});
    state = MultiplayerState.inLobby;
    notifyListeners();
  }

  void rejectInvite() {
    if (state != MultiplayerState.invited) return;
    _send({'type': 'invite_reject'});
    _closeConnection();
    state = MultiplayerState.discovering;
    opponentName = null;
    notifyListeners();
  }

  // ── Lobby / game ──────────────────────────────────────────────────────────

  /// Host only – sends game_start to guest then changes own state.
  void startGame() {
    if (state != MultiplayerState.inLobby || !_isHost) return;
    _send({'type': 'game_start'});
    state = MultiplayerState.inGame;
    notifyListeners();
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
    _send({'type': 'quit'});
    _closeConnection();
    state = MultiplayerState.discovering;
    opponentName = null;
    opponentIsGameOver = false;
    opponentBoard = List.filled(200, 0);
    opponentScore = 0;
    opponentLines = 0;
    _isHost = false;
    notifyListeners();
  }

  // ── TCP socket handling ───────────────────────────────────────────────────

  void _handleIncomingConnection(Socket socket) {
    if (state != MultiplayerState.discovering || _peerSocket != null) {
      socket.destroy();
      return;
    }
    _peerSocket = socket;
    _listenOnSocket(socket);
  }

  void _listenOnSocket(Socket socket) {
    _socketSub?.cancel();
    _socketSub = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleMessage,
          onDone: _handleDisconnect,
          onError: (_) => _handleDisconnect(),
          cancelOnError: true,
        );
  }

  void _handleMessage(String line) {
    if (line.isEmpty) return;
    try {
      final msg = jsonDecode(line) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'invite':
          if (state == MultiplayerState.discovering) {
            state = MultiplayerState.invited;
            _isHost = false;
            opponentName = msg['name'] as String? ?? 'Someone';
            notifyListeners();
            onInviteReceived?.call(opponentName!);
          } else {
            _send({'type': 'invite_reject'});
          }

        case 'invite_accept':
          if (state == MultiplayerState.inviting) {
            opponentName = msg['name'] as String? ?? opponentName;
            state = MultiplayerState.inLobby;
            notifyListeners();
          }

        case 'invite_reject':
          if (state == MultiplayerState.inviting) {
            _closeConnection();
            state = MultiplayerState.discovering;
            opponentName = null;
            _isHost = false;
            notifyListeners();
            onError?.call('Invite was declined');
          }

        case 'game_start':
          if (state == MultiplayerState.inLobby) {
            state = MultiplayerState.inGame;
            notifyListeners();
          }

        case 'garbage':
          if (state == MultiplayerState.inGame) {
            final lines = (msg['lines'] as num?)?.toInt() ?? 0;
            if (lines > 0) onGarbageReceived?.call(lines);
          }

        case 'board_snapshot':
          final raw = msg['cells'];
          if (raw is List && raw.length == 200) {
            opponentBoard = raw.map((v) => (v as num).toInt()).toList();
          }
          opponentScore = (msg['score'] as num?)?.toInt() ?? opponentScore;
          opponentLines = (msg['lines'] as num?)?.toInt() ?? opponentLines;
          notifyListeners();

        case 'game_over':
          opponentIsGameOver = true;
          opponentScore = (msg['score'] as num?)?.toInt() ?? opponentScore;
          notifyListeners();

        case 'quit':
          _handleDisconnect();
      }
    } catch (_) {}
  }

  void _handleDisconnect() {
    final wasConnected = _peerSocket != null;
    final prevState = state;
    final prevOpponentName = opponentName;

    _closeConnection();

    if (!wasConnected) return;

    if (prevState == MultiplayerState.inGame ||
        prevState == MultiplayerState.inLobby) {
      onError?.call('${prevOpponentName ?? 'Opponent'} disconnected');
    }

    if (prevState != MultiplayerState.discovering &&
        prevState != MultiplayerState.idle) {
      state = MultiplayerState.discovering;
      opponentName = null;
      opponentIsGameOver = false;
      _isHost = false;
      notifyListeners();
    }
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _peerSocket?.add(utf8.encode('${jsonEncode(msg)}\n'));
    } catch (_) {}
  }

  void _closeConnection() {
    _socketSub?.cancel();
    _socketSub = null;
    try {
      _peerSocket?.destroy();
    } catch (_) {}
    _peerSocket = null;
  }

  @override
  void dispose() {
    _announceTimer?.cancel();
    _peerExpiryTimer?.cancel();
    _closeConnection();
    _udpSub?.cancel();
    _tcpServer?.close();
    _udpSocket?.close();
    super.dispose();
  }
}
