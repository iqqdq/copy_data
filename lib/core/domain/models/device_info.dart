class DeviceInfo {
  final String id;
  final String ip;
  final String name;
  final int port;
  final String platform;
  final DateTime lastSeen;
  bool isConnected;

  DeviceInfo({
    required this.id,
    required this.ip,
    required this.name,
    this.port = 8080,
    required this.platform,
    required this.lastSeen,
    this.isConnected = false,
  });

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'],
      ip: json['ip'],
      name: json['name'],
      port: json['port'],
      platform: json['platform'],
      lastSeen: DateTime.parse(json['lastSeen']),
      isConnected: json['isConnected'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ip': ip,
      'name': name,
      'port': port,
      'platform': platform,
      'lastSeen': lastSeen.toIso8601String(),
      'isConnected': isConnected,
    };
  }

  String get connectionString => '$ip:$port';
}
