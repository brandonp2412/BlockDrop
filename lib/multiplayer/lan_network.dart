import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// An IPv4 interface and its actual network prefix for LAN discovery.
class LanAddress {
  final String ip;
  final int prefixLength;

  /// Creates an IPv4 LAN address with a prefix length between 0 and 32.
  const LanAddress({required this.ip, required this.prefixLength});

  /// Directed broadcast calculated from the network prefix.
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

/// Discovers physical LAN IPv4 and a verified prefix; never assumes /24.
class LanNetwork {
  static const _channel = MethodChannel('com.blockdrop.game/device');

  /// Returns a physical Wi-Fi or Ethernet IPv4, or null if undetermined.
  static Future<LanAddress?> detect() async {
    if (Platform.isAndroid) {
      try {
        final details =
            await _channel.invokeMapMethod<String, dynamic>('lanAddress');
        final ip = details?['ip'];
        final prefix = details?['prefixLength'];
        if (ip is String && prefix is int && _valid(ip, prefix)) {
          return LanAddress(ip: ip, prefixLength: prefix);
        }
      } on MissingPluginException {
        return null;
      } on PlatformException {
        return null;
      }
      return null;
    }
    try {
      if (Platform.isLinux) {
        final result = await Process.run(
          'ip',
          ['-j', '-4', 'addr', 'show', 'up'],
        );
        if (result.exitCode == 0) {
          return fromLinuxIpJson(result.stdout as String);
        }
      } else if (Platform.isWindows) {
        const script =
            r"Get-NetAdapter -Physical | Where-Object Status -eq 'Up' | Get-NetIPAddress -AddressFamily IPv4 | Select-Object IPAddress,PrefixLength | ConvertTo-Json -Compress";
        final result = await Process.run(
          'powershell.exe',
          ['-NoProfile', '-NonInteractive', '-Command', script],
        );
        if (result.exitCode == 0) {
          final data = jsonDecode(result.stdout as String);
          for (final entry in data is List ? data : [data]) {
            if (entry is! Map) continue;
            final ip = entry['IPAddress'];
            final prefix = entry['PrefixLength'];
            if (ip is String && prefix is int && _valid(ip, prefix)) {
              return LanAddress(ip: ip, prefixLength: prefix);
            }
          }
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run('ifconfig', ['-a']);
        if (result.exitCode == 0) {
          return fromMacIfconfig(result.stdout as String);
        }
      }
    } on ProcessException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
    return null;
  }

  /// Extracts an up physical interface with a real CIDR prefix from iproute2.
  static LanAddress? fromLinuxIpJson(String output) {
    final data = jsonDecode(output);
    if (data is! List) return null;
    for (final entry in data) {
      if (entry is! Map) continue;
      final name = entry['ifname'];
      final flags = entry['flags'];
      if (name is! String ||
          !RegExp(r'^(en|eth|wl)').hasMatch(name) ||
          flags is! List ||
          !flags.contains('LOWER_UP')) {
        continue;
      }
      final addresses = entry['addr_info'];
      if (addresses is! List) continue;
      for (final info in addresses) {
        if (info is! Map || info['scope'] != 'global') continue;
        final ip = info['local'];
        final prefix = info['prefixlen'];
        if (ip is String && prefix is int && _valid(ip, prefix)) {
          return LanAddress(ip: ip, prefixLength: prefix);
        }
      }
    }
    return null;
  }

  /// Parses active macOS Ethernet/Wi-Fi interfaces and hexadecimal masks.
  static LanAddress? fromMacIfconfig(String output) {
    for (final block in output.split(RegExp(r'(?=^en\d+:)', multiLine: true))) {
      if (!RegExp(r'^en\d+:').hasMatch(block) ||
          !block.contains('status: active')) {
        continue;
      }
      final match = RegExp(
        r'\binet (\d+\.\d+\.\d+\.\d+) netmask 0x([0-9a-fA-F]+)',
      ).firstMatch(block);
      if (match == null) continue;
      final mask = int.tryParse(match.group(2)!, radix: 16);
      if (mask == null) continue;
      final prefix = mask.toRadixString(2).replaceAll('0', '').length;
      if (((0xffffffff << (32 - prefix)) & 0xffffffff) != mask) continue;
      final ip = match.group(1)!;
      if (_valid(ip, prefix)) {
        return LanAddress(ip: ip, prefixLength: prefix);
      }
    }
    return null;
  }

  static bool _valid(String ip, int prefix) {
    final address = InternetAddress.tryParse(ip);
    return address?.type == InternetAddressType.IPv4 &&
        prefix >= 1 &&
        prefix <= 32 &&
        !address!.isLoopback &&
        !address.isLinkLocal;
  }

  /// Keeps Android Wi-Fi multicast reception enabled during UDP discovery.
  static Future<void> setMulticastEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setDiscoveryMulticastLock', enabled);
    } on MissingPluginException {
      // No Android multicast manager in desktop/test embeddings.
    } on PlatformException {
      // UDP discovery is optional and must not prevent direct TCP hosting.
    }
  }
}
