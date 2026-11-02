class Peer {
  final String id;
  String name;
  final String ip;
  final int port;
  final String? token;
  DateTime lastSeen;

  Peer({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    this.token,
    required this.lastSeen,
  });
}
