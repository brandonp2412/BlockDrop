/// Browser invitation associated with this launch.
String? get initialOnlineInvite => null;

/// A browser peer connected through the online signalling service.
class OnlineConnection {
  OnlineConnection(
      String room, bool host, void Function(String, String) event) {
    throw UnsupportedError('Online multiplayer is available in the browser.');
  }

  void send(String message) {}
  void close() {}
}
