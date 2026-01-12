import 'package:flutter/material.dart';

import '../../core/core.dart';

class DeviceTile extends StatelessWidget {
  final DeviceInfo device;
  final VoidCallback? onTap;
  final bool isSelected;

  const DeviceTile({
    super.key,
    required this.device,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: _buildDeviceIcon(),
        title: Text(
          device.name,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('IP: ${device.ip}'),
            Text('Платформа: ${_getPlatformName(device.platform)}'),
            if (device.isConnected)
              Chip(
                label: Text('Подключен', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.green,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        trailing: onTap != null
            ? IconButton(
                icon: Icon(Icons.send, color: Colors.blue),
                onPressed: onTap,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildDeviceIcon() {
    final icon = device.platform.toLowerCase().contains('android')
        ? Icons.android
        : device.platform.toLowerCase().contains('ios')
        ? Icons.phone_iphone
        : Icons.device_unknown;

    return CircleAvatar(
      backgroundColor: _getPlatformColor(device.platform),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  String _getPlatformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      default:
        return platform;
    }
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Colors.green;
      case 'ios':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }
}
