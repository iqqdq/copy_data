import 'dart:io';

import 'package:flutter/material.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

import 'widgets/widgets.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  bool _isCheckingPermissions = false;

  List<bool> _permissionStates = [false, false, false];
  bool _showPermissionAlert = false;

  // Текущий индекс разрешения для запроса
  int _currentPermissionIndex = 0;
  // Для отслеживания процесса запроса конкретного разрешения
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Запускаем проверку разрешений при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsWithDelay();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Проверяем разрешения, когда приложение возвращается из фона
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsWithDelay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: CustomAppBar(
            title: 'Copy data',
            automaticallyImplyLeading: false,
            actions: [
              CustomIconButton(
                onPressed: () {},
                icon: SvgPicture.asset(
                  'assets/icons/setting.svg',
                  colorFilter: ColorFilter.mode(
                    AppColors.black,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            children: [
              /// Кнопка сервера
              _buildRoleButton(
                context,
                icon: Icons.wifi,
                title: 'Send file',
                subtitle:
                    'Choose files and share them instantly with nearby devices',
                color: Colors.blue,
                onTap: () => _handleRoleSelection(0),
              ),
              const SizedBox(height: 32.0),

              /// Кнопка клиента
              _buildRoleButton(
                context,
                icon: Icons.phone_android,
                title: 'Receive file',
                subtitle: 'Receive files fast and safely from other devices',
                color: Colors.green,
                onTap: () => _handleRoleSelection(1),
              ),
            ],
          ),
        ),
        // Показываем PermissionAlert если есть неподтвержденные разрешения
        if (_showPermissionAlert)
          PermissionAlert(
            permissionStates: _permissionStates,
            currentPermissionIndex: _currentPermissionIndex,
            onNextPressed: _requestNextPermission,
            onNotNowPressed: () => setState(() => _showPermissionAlert = false),
            isRequestingPermission: _isRequestingPermission,
          ),
      ],
    );
  }

  Future<void> _handleRoleSelection(int roleIndex) async {
    // Всегда проверяем разрешения перед выбором роли
    await _checkPermissions();

    // Проверяем, все ли разрешения получены
    bool allGranted = _permissionStates.every((state) => state);

    if (!allGranted) {
      // Если не все разрешения получены, показываем алерт
      // Находим первый неподтвержденный разрешение
      int firstDeniedIndex = _permissionStates.indexWhere((state) => !state);
      setState(() {
        _currentPermissionIndex = firstDeniedIndex;
        _showPermissionAlert = true;
      });
      return;
    }

    // Если все разрешения получены, переходим к экрану
    if (roleIndex == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ServerScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ClientScreen()),
      );
    }
  }

  Future<void> _checkPermissionsWithDelay() async {
    await Future.delayed(Duration(milliseconds: 500));
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (_isCheckingPermissions) return;

    setState(() => _isCheckingPermissions = true);

    try {
      print('🔐 Начинаю проверку разрешений...');

      List<bool> newStates = [];

      // 1. NSLocalNetworkUsageDescription (iOS) и WiFi разрешения для Android
      if (Platform.isIOS) {
        try {
          final connectivity = Connectivity();
          final connectivityResult = await connectivity.checkConnectivity();
          final hasWifi = connectivityResult.contains(ConnectivityResult.wifi);

          if (hasWifi) {
            newStates.add(true);
            print('📡 iOS: Подключено к Wi-Fi');
          } else {
            newStates.add(false);
            print('📡 iOS: Нет Wi-Fi подключения или доступ запрещен');
          }
        } catch (e) {
          print('⚠️ Ошибка при проверке сети на iOS: $e');
          newStates.add(false);
        }
      } else if (Platform.isAndroid) {
        try {
          final connectivity = Connectivity();
          final connectivityResult = await connectivity.checkConnectivity();
          final hasNetworkAccess =
              connectivityResult.isNotEmpty &&
              connectivityResult.any(
                (result) => result != ConnectivityResult.none,
              );

          if (Platform.isAndroid &&
              await DeviceInfoPlugin().androidInfo.then(
                (info) => info.version.sdkInt >= 31,
              )) {
            // Android 12+ (API 31+)
            final wifiStateStatus = await Permission.nearbyWifiDevices.status;
            final hasWifiPermission = wifiStateStatus.isGranted;
            newStates.add(hasWifiPermission && hasNetworkAccess);
            print(
              '📡 Android 12+ WiFi статус: $wifiStateStatus, Network доступ: $hasNetworkAccess',
            );
          } else {
            // Старые версии Android
            newStates.add(hasNetworkAccess);
            print('📡 Android <12 Network доступ: $hasNetworkAccess');
          }
        } catch (e) {
          print('⚠️ Не удалось проверить WiFi разрешение: $e');
          newStates.add(false);
        }
      }

      // 2. Photos & Videos
      if (Platform.isAndroid) {
        final storageStatus = await Permission.storage.status;
        newStates.add(storageStatus.isGranted);
        print('🖼 Android Storage статус: $storageStatus');
      } else if (Platform.isIOS) {
        final photosStatus = await Permission.photos.status;
        newStates.add(photosStatus.isGranted);
        print('📱 iOS Photos статус: $photosStatus');
      }

      // 3. Camera
      final cameraStatus = await Permission.camera.status;
      newStates.add(cameraStatus.isGranted);
      print('📸 Camera статус: $cameraStatus');

      setState(() {
        _permissionStates = newStates;
        _isCheckingPermissions = false;

        // Проверяем, все ли разрешения получены
        bool allGranted = _permissionStates.every((state) => state);
        _showPermissionAlert = !allGranted;

        // Если есть неподтвержденные разрешения, находим первое
        if (!allGranted) {
          _currentPermissionIndex = _permissionStates.indexWhere(
            (state) => !state,
          );
        }
      });
    } catch (e) {
      setState(() => _isCheckingPermissions = false);
      print('❌ Ошибка при запросе разрешений: $e');
    }
  }

  Future<void> _requestNextPermission() async {
    if (_isRequestingPermission) return;

    setState(() {
      _isRequestingPermission = true;
    });

    try {
      bool permissionGranted = false;

      switch (_currentPermissionIndex) {
        case 0: // Local Network/Wi-Fi
          print('📡 Запрашиваю Network разрешение...');
          permissionGranted = await _requestNetworkPermission();
          break;

        case 1: // Photos & Videos
          print('🖼 Запрашиваю доступ к медиа...');
          permissionGranted = await _requestMediaPermission();
          break;

        case 2: // Camera
          print('📸 Запрашиваю доступ к камере...');
          permissionGranted = await _requestCameraPermission();
          break;
      }

      // Обновляем состояние разрешения
      List<bool> updatedStates = List.from(_permissionStates);
      updatedStates[_currentPermissionIndex] = permissionGranted;

      setState(() {
        _permissionStates = updatedStates;
        _isRequestingPermission = false;
      });

      // Проверяем статус разрешения
      if (!permissionGranted) {
        // Если разрешение не получено, показываем индивидуальный алерт
        _showIndividualPermissionDialog(_currentPermissionIndex);
      }

      // Находим следующее неподтвержденное разрешение
      int nextDeniedIndex = _permissionStates.indexWhere((state) => !state);

      if (nextDeniedIndex != -1) {
        // Есть еще неподтвержденные разрешения
        setState(() {
          _currentPermissionIndex = nextDeniedIndex;
        });
      } else {
        // Все разрешения получены
        setState(() {
          _showPermissionAlert = false;
        });
        print('✅ Все разрешения получены!');
      }
    } catch (e, stackTrace) {
      print('❌ Ошибка при запросе разрешения: $e');
      print('Stack: $stackTrace');
      setState(() {
        _isRequestingPermission = false;
      });
    }
  }

  Future<bool> _requestNetworkPermission() async {
    if (Platform.isIOS) {
      // Для iOS: пытаемся инициировать сетевой запрос
      try {
        final connectivity = Connectivity();
        final connectivityResult = await connectivity.checkConnectivity();
        final hasWifi = connectivityResult.contains(ConnectivityResult.wifi);

        if (hasWifi) {
          // На iOS не можем программно запросить, просто возвращаем true
          // так как пользователь должен включить в настройках
          return true;
        } else {
          return false;
        }
      } catch (e) {
        print('📡 iOS: Ошибка при проверке сети: $e');
        return false;
      }
    } else {
      // Для Android
      try {
        final connectivity = Connectivity();
        final connectivityResult = await connectivity.checkConnectivity();
        final hasNetworkAccess =
            connectivityResult.isNotEmpty &&
            connectivityResult.any(
              (result) => result != ConnectivityResult.none,
            );

        if (Platform.isAndroid &&
            await DeviceInfoPlugin().androidInfo.then(
              (info) => info.version.sdkInt >= 31,
            )) {
          // Android 12+
          final wifiStatus = await Permission.nearbyWifiDevices.request();
          return wifiStatus.isGranted && hasNetworkAccess;
        } else {
          // Старые Android
          return hasNetworkAccess;
        }
      } catch (e) {
        print('⚠️ Не удалось запросить WiFi разрешение: $e');
        return false;
      }
    }
  }

  Future<bool> _requestMediaPermission() async {
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    } else if (Platform.isIOS) {
      final photosStatus = await Permission.photos.request();
      return photosStatus.isGranted;
    }
    return false;
  }

  Future<bool> _requestCameraPermission() async {
    final cameraStatus = await Permission.camera.request();
    return cameraStatus.isGranted;
  }

  void _showIndividualPermissionDialog(int permissionIndex) {
    String title = '';
    String message = '';

    switch (permissionIndex) {
      case 0: // Local Network
        title = 'No access to Local Network';
        message =
            'The app uses the local network to search for devices. '
            'Please go to the settings and allow access.';
        break;
      case 1: // Photos
        title = 'No access to Photos';
        message =
            'To transfer your data, the app needs access to your Photos. '
            'Please go to settings and allow access.';
        break;
      case 2: // Camera
        title = 'No access to Camera';
        message =
            'To transfer your data, the app needs access to your Camera. '
            'Please go to settings and allow access.';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Open Settings'),
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
