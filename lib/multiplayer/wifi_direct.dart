import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A nearby Android device advertised by the system Wi-Fi Direct service.
class WifiDirectPeer {
  final String name;
  final String address;
  final int status;

  const WifiDirectPeer({
    required this.name,
    required this.address,
    required this.status,
  });

  factory WifiDirectPeer.fromMap(Map<Object?, Object?> map) => WifiDirectPeer(
        name: map['name'] is String ? map['name'] as String : '',
        address: map['address'] is String ? map['address'] as String : '',
        status: map['status'] is int ? map['status'] as int : -1,
      );
}

/// Physical Android P2P network state, independent of BlockDrop TCP gameplay.
class WifiDirectSnapshot {
  final bool supported;
  final bool wifiEnabled;
  final bool permissionGranted;
  final bool connected;
  final bool groupOwner;
  final String? groupOwnerIp;
  final List<WifiDirectPeer> peers;

  const WifiDirectSnapshot({
    this.supported = false,
    this.wifiEnabled = false,
    this.permissionGranted = false,
    this.connected = false,
    this.groupOwner = false,
    this.groupOwnerIp,
    this.peers = const [],
  });

  factory WifiDirectSnapshot.fromMap(Map<Object?, Object?> map) {
    final rawPeers = map['peers'];
    return WifiDirectSnapshot(
      supported: map['supported'] == true,
      wifiEnabled: map['wifiEnabled'] == true,
      permissionGranted: map['permissionGranted'] == true,
      connected: map['connected'] == true,
      groupOwner: map['groupOwner'] == true,
      groupOwnerIp:
          map['groupOwnerIp'] is String ? map['groupOwnerIp'] as String : null,
      peers: rawPeers is List
          ? rawPeers
              .whereType<Map>()
              .map((value) => WifiDirectPeer.fromMap(value))
              .toList(growable: false)
          : const [],
    );
  }
}

/// Native Wi-Fi Direct operations; all data-plane traffic remains TCP sockets.
abstract class WifiDirectPlatform {
  Stream<WifiDirectSnapshot> get events;
  Future<WifiDirectSnapshot> status();
  Future<bool> requestPermission();
  Future<void> discover();
  Future<List<WifiDirectPeer>> peers();
  Future<void> createGroup();
  Future<void> connect(String address);
  Future<void> cancelConnect();
  Future<void> disconnect();
}

/// Android framework platform-channel adapter, with no proprietary SDK.
class AndroidWifiDirectPlatform implements WifiDirectPlatform {
  static const _methods = MethodChannel('com.blockdrop.game/wifi_direct');
  static const _events = EventChannel('com.blockdrop.game/wifi_direct/events');

  @override
  Stream<WifiDirectSnapshot> get events => _events
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => WifiDirectSnapshot.fromMap(event as Map));

  @override
  Future<WifiDirectSnapshot> status() async => WifiDirectSnapshot.fromMap(
      await _methods.invokeMapMethod<Object?, Object?>('status') ?? {});

  @override
  Future<bool> requestPermission() async =>
      await _methods.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<void> discover() => _methods.invokeMethod<void>('discover');

  @override
  Future<List<WifiDirectPeer>> peers() async {
    final list = await _methods.invokeListMethod<dynamic>('peers') ?? [];
    return list
        .whereType<Map>()
        .map((value) => WifiDirectPeer.fromMap(value))
        .toList(growable: false);
  }

  @override
  Future<void> createGroup() => _methods.invokeMethod<void>('createGroup');

  @override
  Future<void> connect(String address) =>
      _methods.invokeMethod<void>('connect', {'address': address});

  @override
  Future<void> cancelConnect() => _methods.invokeMethod<void>('cancelConnect');

  @override
  Future<void> disconnect() => _methods.invokeMethod<void>('disconnect');
}

/// Forms a direct Android network with explicit deadlines and cancellation.
class WifiDirectController extends ChangeNotifier {
  final WifiDirectPlatform platform;
  final Duration groupTimeout;
  StreamSubscription<WifiDirectSnapshot>? _subscription;
  Completer<void>? _pendingGroup;
  Timer? _deadline;
  int _generation = 0;
  bool _disposed = false;
  bool _groupWasConnected = false;

  WifiDirectSnapshot state = const WifiDirectSnapshot();
  String? error;
  bool busy = false;
  String? operation;
  VoidCallback? onGroupLost;

  WifiDirectController(
      {WifiDirectPlatform? platform,
      this.groupTimeout = const Duration(seconds: 25)})
      : platform = platform ?? AndroidWifiDirectPlatform();

  /// Attaches to system events and recovers current group state on resume.
  Future<void> initialize() async {
    if (!Platform.isAndroid && platform is AndroidWifiDirectPlatform) return;
    _subscription ??= platform.events.listen(_onEvent, onError: (Object error) {
      if (_disposed) return;
      this.error = 'Wi-Fi Direct event stream unavailable: $error';
      notifyListeners();
    });
    try {
      _onEvent(await platform.status());
    } catch (error) {
      this.error = 'Could not query Wi-Fi Direct: $error';
      notifyListeners();
    }
  }

  void _onEvent(WifiDirectSnapshot next) {
    if (_disposed) return;
    final wasConnected = _groupWasConnected;
    state = next;
    _groupWasConnected = next.connected;
    if (wasConnected && !next.connected) onGroupLost?.call();
    if (next.connected &&
        next.groupOwnerIp != null &&
        next.groupOwnerIp!.isNotEmpty) {
      _pendingGroup?.complete();
      _pendingGroup = null;
    }
    notifyListeners();
  }

  Future<void> _ensureReady() async {
    if (!state.supported)
      throw StateError('Wi-Fi Direct unsupported on this device');
    if (!state.wifiEnabled) throw StateError('Turn Wi-Fi on first');
    if (!state.permissionGranted) {
      final allowed = await platform.requestPermission();
      if (!allowed) throw StateError('Nearby Wi-Fi permission denied');
      _onEvent(await platform.status());
    }
  }

  Future<void> discover() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await _ensureReady();
      await platform.discover();
      _onEvent(await platform.status());
    } catch (failure) {
      error = 'Could not search Wi-Fi Direct peers: $failure';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshPeers() async {
    try {
      await platform.peers();
      _onEvent(await platform.status());
    } catch (failure) {
      error = 'Could not refresh peers: $failure';
      notifyListeners();
    }
  }

  /// Creates a group owned by the host; waits for a real owner IPv4 address.
  Future<bool> host() => _formGroup(null);

  /// Connects to a discovered owner; the owner still approves the TCP join.
  Future<bool> joinPeer(WifiDirectPeer peer) => _formGroup(peer.address);

  Future<bool> _formGroup(String? peerAddress) async {
    if (busy) return false;
    if (state.connected) {
      error = 'Disconnect the existing group before starting another.';
      notifyListeners();
      return false;
    }
    busy = true;
    operation = peerAddress == null ? 'Creating group' : 'Connecting to peer';
    error = null;
    final generation = ++_generation;
    notifyListeners();
    try {
      await _ensureReady();
      final pending = Completer<void>();
      _pendingGroup = pending;
      _deadline = Timer(groupTimeout, () {
        if (!pending.isCompleted) pending.complete();
      });
      final request = peerAddress == null
          ? platform.createGroup()
          : platform.connect(peerAddress);
      await request.timeout(groupTimeout);
      await pending.future;
      if (generation != _generation) return false;
      if (!state.connected || state.groupOwnerIp == null) {
        throw TimeoutException('No Wi-Fi Direct group formed', groupTimeout);
      }
      if (state.groupOwner != (peerAddress == null)) {
        throw StateError(
            'Unexpected group ownership. Disconnect and retry with one host.');
      }
      return true;
    } catch (failure) {
      if (generation == _generation) {
        error = 'Wi-Fi Direct connection failed: $failure';
        try {
          await platform.cancelConnect();
        } catch (_) {}
        try {
          await platform.disconnect();
        } catch (_) {}
      }
      return false;
    } finally {
      if (generation == _generation) {
        _deadline?.cancel();
        _deadline = null;
        _pendingGroup = null;
        busy = false;
        operation = null;
        notifyListeners();
      }
    }
  }

  /// Cancels setup or releases an owned/connected group without touching TCP LAN.
  Future<void> disconnect() async {
    ++_generation;
    _deadline?.cancel();
    _deadline = null;
    if (!(_pendingGroup?.isCompleted ?? true)) {
      _pendingGroup?.complete();
    }
    _pendingGroup = null;
    busy = false;
    operation = null;
    try {
      await platform.cancelConnect();
    } catch (_) {}
    try {
      await platform.disconnect();
    } catch (failure) {
      error = 'Unable to release Wi-Fi Direct group: $failure';
    }
    try {
      _onEvent(await platform.status());
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _deadline?.cancel();
    if (!(_pendingGroup?.isCompleted ?? true)) {
      _pendingGroup?.complete();
    }
    _subscription?.cancel();
    super.dispose();
  }
}
