class Peer {
  final String id;
  String name;
  final String ip;
  final int port;
  DateTime lastSeen;

  Peer({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.lastSeen,
  });
}
