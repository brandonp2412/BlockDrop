import 'dart:io';

void main() async {
  final server = await ServerSocket.bind(InternetAddress.anyIPv4, 45679);
  print('TCP server listening on 0.0.0.0:${server.port}');
  print('Local IPs:');
  for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false)) {
    for (final addr in iface.addresses) {
      print('  ${iface.name}: ${addr.address}');
    }
  }
  print('Waiting for connections... (Ctrl+C to stop)');

  await for (final socket in server) {
    print('GOT CONNECTION from ${socket.remoteAddress.address}:${socket.remotePort}');
    socket.write('hello from windows\n');
    socket.close();
  }
}
