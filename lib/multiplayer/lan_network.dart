import 'dart:io';

import 'package:flutter/services.dart';

/// An IPv4 interface and its actual network prefix for LAN discovery.
class LanAddress {
  final String ip;
  final int prefixLength;

  /// Creates an IPv4 LAN address with a prefix length between 0 and 32.
  const LanAddress({required this.ip, required this.prefixLength});

  /// Directed broadcast calculated from the network prefix, not an assumed /24.
  String get broadcast {
    final address = InternetAddress.tryParse(ip);
    if (address == null || address.type != InternetAddressType.IPv4) {
      return '255.255.255.255';
    }

    final octets = address.rawAddress;
    final value =
        (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
    final prefix = prefixLength.clamp(0, 32);
    final mask = (0xffffffff << (32 - prefix)) & 0xffffffff;
    final broadcast = (value & mask) | (~mask & 0xffffffff);
    return [
      (broadcast >> 24) & 255,
      (broadcast >> 16) & 255,
      (broadcast >> 8) & 255,
      broadcast & 255,
    ].join('.');
  }
}

/// Resolves an actual Wi-Fi/Ethernet interface before falling back to Dart.
class LanNetwork {
  static const _channel = MethodChannel('com.blockdrop.game/device');

  /// Returns the physical LAN even when a VPN is the default Android network.
  static Future<LanAddress?> detect() async {
    if (Platform.isAndroid) {
      try {
        final details = await _channel.invokeMapMethod<String, dynamic>(
          'lanAddress',
        );
        final ip = details?['ip'];
        final prefix = details?['prefixLength'];
        if (ip is String && prefix is int) {
          final address = InternetAddress.tryParse(ip);
          if (address?.type == InternetAddressType.IPv4) {
            return LanAddress(ip: ip, prefixLength: prefix);
          }
        }
      } on MissingPluginException {
        // Other Flutter embeddings can use the interface fallback.
      } on PlatformException {
        // The local interface fallback still works on non-standard Android.
      }
    }

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      final addresses = interfaces.expand((iface) => iface.addresses).toList();
      if (addresses.isEmpty) return null;
      addresses
          .sort((a, b) => _priority(b.address).compareTo(_priority(a.address)));
      return LanAddress(ip: addresses.first.address, prefixLength: 24);
    } on SocketException {
      return null;
    }
  }

  static int _priority(String ip) {
    if (ip.startsWith('192.168.')) return 3;
    if (ip.startsWith('10.')) return 2;
    if (RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip)) {
      return 1;
    }
    return 0;
  }

  /// Keep Wi-Fi multicast reception enabled while discovery is active.
  static Future<void> setMulticastEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setDiscoveryMulticastLock', enabled);
    } on MissingPluginException {
      // Desktop or test embeddings do not expose Android's Wi-Fi manager.
    } on PlatformException {
      // Failure to acquire a lock must not prevent ordinary UDP discovery.
    }
  }
}
