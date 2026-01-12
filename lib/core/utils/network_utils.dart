import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtils {
  static final NetworkInfo _networkInfo = NetworkInfo();

  static Future<String> getLocalIp() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final wifiIp = await _networkInfo.getWifiIP();
        if (wifiIp != null && wifiIp != '0.0.0.0') {
          return wifiIp;
        }
      }

      // Резервный метод
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Ошибка получения IP: $e');
    }
    return '127.0.0.1';
  }

  static Future<String?> getWifiName() async {
    try {
      return await _networkInfo.getWifiName();
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getGatewayIP() async {
    try {
      return await _networkInfo.getWifiGatewayIP();
    } catch (e) {
      return null;
    }
  }

  static Future<String> generateConnectionString() async {
    final ip = await getLocalIp();
    return 'ws://$ip:8080';
  }

  static bool isValidIp(String ip) {
    final regex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );
    return regex.hasMatch(ip);
  }

  static Future<bool> isOnSameNetwork(String ip1, String ip2) async {
    try {
      final parts1 = ip1.split('.');
      final parts2 = ip2.split('.');

      if (parts1.length != 4 || parts2.length != 4) return false;

      // Проверяем первые три октета
      return parts1[0] == parts2[0] &&
          parts1[1] == parts2[1] &&
          parts1[2] == parts2[2];
    } catch (e) {
      return false;
    }
  }

  static Future<String> generateWebSocketUrl(
    String ip, {
    int port = 8080,
  }) async {
    return 'ws://$ip:$port/ws';
  }
}
