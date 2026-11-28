import 'dart:js_interop';

@JS('blockDropInvite')
external JSString? get _invite;

/// Invitation captured before Flutter initializes its browser router.
String? get initialOnlineInvite => _invite?.toDart;

@JS('blockDropOnline')
external _BrowserConnection _connect(
  JSString endpoint,
  JSString turnEndpoint,
  JSString room,
  JSBoolean host,
  JSFunction event,
);

extension type _BrowserConnection(JSObject _) implements JSObject {
  external void send(JSString message);
  external void close();
}

/// A reliable, ordered WebRTC data channel negotiated by the signalling Worker.
class OnlineConnection {
  static const _endpoint = String.fromEnvironment(
    'BLOCKDROP_SIGNAL_URL',
    defaultValue: 'wss://blockdrop-signal.blockdrop.workers.dev',
  );
  static const _turnEndpoint = String.fromEnvironment('BLOCKDROP_TURN_URL');
  final _BrowserConnection _connection;

  OnlineConnection(String room, bool host, void Function(String, String) event)
      : _connection = _connect(
          _endpoint.toJS,
          _turnEndpoint.toJS,
          room.toJS,
          host.toJS,
          ((JSString type, JSString data) => event(type.toDart, data.toDart))
              .toJS,
        );

  void send(String message) => _connection.send(message.toJS);
  void close() => _connection.close();
}
