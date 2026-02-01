import 'dart:io';

class DeviceUtils {
  DeviceUtils._();

  static Future<String> getDeviceName() async {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iPhone';
    return 'Unknown';
  }
}
