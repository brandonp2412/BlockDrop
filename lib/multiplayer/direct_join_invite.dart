import 'dart:math';
import 'dart:io';

/// The local-only invitation used by a direct TCP guest.
class DirectJoinInvite {
  /// Version understood by this app's direct-join protocol.
  static const int protocolVersion = 1;

  /// Address a joining player must be able to reach over TCP.
  final String host;
  final int port;

  /// Short-lived bearer capability; never publish it in diagnostics.
  final String token;
  final int version;

  /// Optional display-only host name, never used for name resolution.
  final String? displayName;

  /// Host-provided expiration to warn scanners before they connect.
  final DateTime? expiresAt;

  const DirectJoinInvite({
    required this.host,
    required this.port,
    required this.token,
    this.version = protocolVersion,
    this.displayName,
    this.expiresAt,
  });

  /// Encodes the address, port and token for a future QR or manual UI.
  Uri toUri() => Uri(
        scheme: 'blockdrop',
        host: 'join',
        queryParameters: {
          'v': '$version',
          'host': host,
          'port': '$port',
          'token': token,
          if (displayName != null) 'name': displayName!,
          if (expiresAt != null)
            'exp': (expiresAt!.millisecondsSinceEpoch ~/ 1000).toString(),
        },
      );

  /// Parses a scanned invitation without opening a network connection.
  factory DirectJoinInvite.fromUri(String text) {
    final uri = Uri.parse(text);
    if (uri.scheme != 'blockdrop' ||
        uri.host != 'join' ||
        uri.path.isNotEmpty ||
        uri.queryParametersAll.values.any((values) => values.length != 1)) {
      throw const FormatException('Invalid BlockDrop invitation');
    }
    final version = int.tryParse(uri.queryParameters['v'] ?? '');
    final port = int.tryParse(uri.queryParameters['port'] ?? '');
    final invite = DirectJoinInvite(
      host: uri.queryParameters['host'] ?? '',
      port: port ?? 0,
      token: uri.queryParameters['token'] ?? '',
      version: version ?? 0,
      displayName: uri.queryParameters['name'],
      expiresAt: uri.queryParameters['exp'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (int.tryParse(uri.queryParameters['exp']!) ?? -1) * 1000,
            ),
    );
    invite.validate();
    return invite;
  }

  /// Validates the connection data before attempting TCP.
  void validate() {
    if (version != protocolVersion ||
        InternetAddress.tryParse(host)?.type != InternetAddressType.IPv4 ||
        (displayName != null && displayName!.length > 64) ||
        (expiresAt != null && expiresAt!.millisecondsSinceEpoch <= 0) ||
        port < 1 ||
        port > 65535 ||
        !RegExp(r'^[0-9a-f]{48}$').hasMatch(token)) {
      throw const FormatException('Invalid or unsupported join invitation');
    }
  }

  /// Generates a 192-bit unpredictable capability with the platform CSPRNG.
  static String generateToken() {
    final random = Random.secure();
    return List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// Compares equal-length capabilities without content-dependent early exit.
  static bool matchesToken(String candidate, String expected) {
    if (candidate.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= candidate.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return difference == 0;
  }
}
