import 'package:block_drop/multiplayer/lan_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('directed broadcast respects actual Wi-Fi prefix lengths', () {
    expect(const LanAddress(ip: '192.168.1.42', prefixLength: 24).broadcast,
        '192.168.1.255');
    expect(const LanAddress(ip: '192.168.2.42', prefixLength: 23).broadcast,
        '192.168.3.255');
    expect(const LanAddress(ip: '10.30.7.8', prefixLength: 20).broadcast,
        '10.30.15.255');
    expect(const LanAddress(ip: '172.16.22.7', prefixLength: 16).broadcast,
        '172.16.255.255');
  });

  test('invalid address falls back to limited broadcast', () {
    expect(const LanAddress(ip: 'not-an-ip', prefixLength: 24).broadcast,
        '255.255.255.255');
  });
}
