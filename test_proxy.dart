import 'dart:io';
import 'package:socks5_proxy/socks_client.dart';

void main() async {
  final proxyHost = '103.166.253.92';
  final proxyPort = 1088;
  
  print("Testing SOCKS5 Proxy without auth...");
  try {
    final client = await SocksTCPClient.connect(
      [ProxySettings(InternetAddress(proxyHost), proxyPort)],
      InternetAddress('1.1.1.1', type: InternetAddressType.unix),
      80,
    );
    print("Success NO AUTH!");
    client.close();
  } catch (e) {
    print("NO AUTH FAILED: $e");
  }

  print("Testing SOCKS5 Proxy with test:test...");
  try {
    final client = await SocksTCPClient.connect(
      [ProxySettings(InternetAddress(proxyHost), proxyPort, username: 'test', password: 'test')],
      InternetAddress('1.1.1.1', type: InternetAddressType.unix),
      80,
    );
    print("Success test:test!");
    client.close();
  } catch (e) {
    print("test:test FAILED: $e");
  }

  print("Testing SOCKS5 Proxy with test:test and IPv4 type...");
  try {
    final client = await SocksTCPClient.connect(
      [ProxySettings(InternetAddress(proxyHost), proxyPort, username: 'test', password: 'test')],
      InternetAddress('1.1.1.1', type: InternetAddressType.IPv4),
      80,
    );
    print("Success test:test with IPv4!");
    client.close();
  } catch (e) {
    print("test:test IPv4 FAILED: $e");
  }
}
