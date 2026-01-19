import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../presentation.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with WidgetsBindingObserver {
  bool _isCheckingPermissions = false;
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Проверяем разрешения, когда приложение возвращается из фона
    if (state == AppLifecycleState.resumed && !_permissionsChecked) {
      _checkPermissionsWithDelay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Local File Transfer'), centerTitle: true),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Если проверяем разрешения, показываем индикатор
    if (_isCheckingPermissions) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Проверка разрешений...'),
          ],
        ),
      );
    }

    return ListView(
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
        // Кнопка для ручной проверки разрешений
        if (!_permissionsChecked)
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: ElevatedButton(
              onPressed: () {
                _checkPermissions();
              },
              child: Text('Проверить разрешения'),
            ),
          ),
      ],
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Запускаем проверку разрешений после построения виджета
    if (!_permissionsChecked && !_isCheckingPermissions) {
      _checkPermissionsWithDelay();
    }
  }

  Future<void> _checkPermissionsWithDelay() async {
    // Добавляем задержку, чтобы избежать deadlock
    await Future.delayed(Duration(milliseconds: 500));
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Защита от повторного вызова
    if (_isCheckingPermissions) return;

    setState(() {
      _isCheckingPermissions = true;
    });

    try {
      print('🔐 Начинаю проверку разрешений...');

      // Для iOS: сначала проверяем, есть ли уже разрешения
      if (Platform.isIOS) {
        final photosStatus = await Permission.photos.status;
        print('📱 iOS: Текущий статус фотогалереи: $photosStatus');

        // Если разрешение уже есть или в состоянии "denied", не запрашиваем автоматически
        if (photosStatus.isPermanentlyDenied) {
          print(
            '📱 iOS: Разрешение навсегда отклонено, нужна настройка вручную',
          );
          _showIOSPermissionDialog();
        } else if (photosStatus.isDenied) {
          // Запрашиваем с задержкой
          await Future.delayed(Duration(milliseconds: 300));
          print('📱 iOS: Запрашиваю доступ к фотогалерее...');
          final newStatus = await Permission.photos.request();
          print('📱 iOS: Новый статус фотогалереи: $newStatus');
        }
      }

      // Для Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          await Future.delayed(Duration(milliseconds: 300));
          status = await Permission.storage.request();
        }
      }

      print('🔐 Проверка разрешений завершена');
    } catch (e, stackTrace) {
      print('❌ Ошибка при запросе разрешений: $e');
      print('Stack: $stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPermissions = false;
          _permissionsChecked = true;
        });
      }
    }
  }

  void _showIOSPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Требуется доступ'),
        content: Text(
          'Для отправки файлов необходимо предоставить доступ к фотогалерее. '
          'Пожалуйста, разрешите доступ в настройках приложения.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Позже'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Открыть настройки'),
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
