import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../presentation.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
  }

  Future<void> _checkPermissions() async {
    bool _hasStoragePermission = false;

    try {
      print('🔐 Проверка разрешений...');

      if (Platform.isAndroid) {
        // Для Android
        var status = await Permission.storage.status;

        if (!status.isGranted) {
          print('📱 Android: Запрашиваю разрешение на доступ к хранилищу');
          status = await Permission.storage.request();

          // Для Android 10+ может потребоваться доступ к медиа
          if (Platform.isAndroid && await Permission.storage.isGranted) {
            final mediaStatus = await Permission.accessMediaLocation.status;
            if (!mediaStatus.isGranted) {
              await Permission.accessMediaLocation.request();
            }
          }
        }

        _hasStoragePermission = status.isGranted;
        print(
          '📱 Android: Разрешение на хранилище: ${status.isGranted ? "✅" : "❌"}',
        );
      } else if (Platform.isIOS) {
        // Для iOS
        var photosStatus = await Permission.photos.status;

        if (!photosStatus.isGranted) {
          print('📱 iOS: Запрашиваю доступ к фотогалерее');
          photosStatus = await Permission.photos.request();
        }

        // Для iOS также может потребоваться доступ к медиабиблиотеке
        final mediaLibraryStatus = await Permission.mediaLibrary.status;
        if (!mediaLibraryStatus.isGranted) {
          // await Permission.mediaLibrary.request(); // TODO: CHECK
        }

        _hasStoragePermission = photosStatus.isGranted;
        print(
          '📱 iOS: Доступ к фотогалерее: ${photosStatus.isGranted ? "✅" : "❌"}',
        );
        print(
          '📱 iOS: Доступ к медиабиблиотеке: ${mediaLibraryStatus.isGranted ? "✅" : "❌"}',
        );
      }

      // Логируем итоговый статус
      print(
        '🔐 Итоговый статус разрешений: ${_hasStoragePermission ? "✅ Есть доступ" : "❌ Нет доступа"}',
      );
    } catch (e, stackTrace) {
      print('❌ Ошибка при запросе разрешений: $e');
      print('Stack: $stackTrace');
      _hasStoragePermission = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Local File Transfer'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Text(
            'Выберите режим работы',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: 10),

          Text(
            'Вы можете быть сервером для приема файлов или клиентом для отправки',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),

          SizedBox(height: 40),

          // Кнопка сервера
          _buildRoleButton(
            context,
            icon: Icons.wifi,
            title: 'Быть Сервером',
            subtitle: 'Принимать файлы от других устройств',
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ServerScreen()),
              );
            },
          ),

          SizedBox(height: 20),

          // Кнопка клиента
          _buildRoleButton(
            context,
            icon: Icons.phone_android,
            title: 'Быть Клиентом',
            subtitle: 'Подключиться к серверу и отправить файлы',
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ClientScreen()),
              );
            },
          ),

          SizedBox(height: 40),

          // Инструкция
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Text(
                    'Как это работает:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Одно устройство запускает сервер\n'
                    '2. Другое устройство подключается как клиент\n'
                    '3. Выбираете файлы и отправляете\n'
                    '4. Все работает по локальной сети Wi-Fi',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(15),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
