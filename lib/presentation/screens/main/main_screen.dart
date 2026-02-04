import 'dart:io';

import 'package:flutter/material.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  List<bool> _permissionStates = [false, false, false];
  bool _isCheckingPermissions = false;
  bool _showPermissionAlert = false;
  bool _allPermissionsGranted = false;
  bool _isRequestingPermission = false;
  int _currentPermissionIndex = Platform.isAndroid ? 1 : 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appSettings = AppSettingsService.instance;
      if (!appSettings.isTutorialSkipped) {
        await Navigator.pushNamed(context, AppRoutes.tutorial);
      }

      await _checkPermissions();
      await _showRateAppDialog();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
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
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.settings),
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
              Padding(
                padding: EdgeInsets.only(bottom: 32.0),
                child: MainTile.send(onPressed: () => _handleRoleSelection(0)),
              ),

              MainTile.receive(onPressed: () => _handleRoleSelection(1)),
            ],
          ),
        ),

        if (_showPermissionAlert)
          PermissionAlert(
            permissionStates: _permissionStates,
            currentPermissionIndex: _currentPermissionIndex,
            isRequestingPermission: _isRequestingPermission,
            allPermissionsGranted: _allPermissionsGranted,
            onNextPressed: _requestNextPermission,
            onNotNowPressed: () {
              setState(() {
                _showPermissionAlert = false;
                _allPermissionsGranted = false;
              });
            },
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
      int firstDeniedIndex = _permissionStates.indexWhere((state) => !state);
      setState(() {
        _currentPermissionIndex = firstDeniedIndex;
        _showPermissionAlert = true;
        _allPermissionsGranted = false; // Сбрасываем флаг
      });
      return;
    }

    // Проверяем, был ли нажат Next после получения всех разрешений
    if (_showPermissionAlert && _allPermissionsGranted) {
      // Если алерт еще показывается, но все разрешения получены,
      // значит пользователь еще не нажал "Next" - ничего не делаем
      print('⚠️ Все разрешения получены, но алерт еще не закрыт');
      return;
    }

    // Если все разрешения получены И алерт закрыт, переходим к экрану
    if (mounted) {
      Navigator.pushNamed(
        context,
        roleIndex == 0 ? AppRoutes.send : AppRoutes.receive,
      );
    }
  }

  Future<void> _showRateAppDialog() async {
    final appSettings = AppSettingsService.instance;
    if (!appSettings.isAppRated) {
      if (Platform.isIOS && await InAppReview.instance.isAvailable()) {
        await InAppReview.instance.requestReview();
        await appSettings.rateApp();
      }
    }
  }

  Future<void> _checkPermissions() async {
    await Future.delayed(Duration(milliseconds: 300));

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
          newStates.add(true);
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
        _allPermissionsGranted = _permissionStates.every((state) => state);
        _showPermissionAlert = !_allPermissionsGranted;

        // Если есть неподтвержденные разрешения, находим первое
        if (!_allPermissionsGranted) {
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

        // Проверяем, все ли разрешения теперь получены
        _allPermissionsGranted = _permissionStates.every((state) => state);
      });

      // Если разрешение не получено, показываем индивидуальный алерт
      if (!permissionGranted) {
        _showIndividualPermissionDialog(_currentPermissionIndex);

        // Находим следующее неподтвержденное разрешение
        int nextDeniedIndex = _permissionStates.indexWhere((state) => !state);

        if (nextDeniedIndex != -1) {
          setState(() {
            _currentPermissionIndex = nextDeniedIndex;
          });
        }

        return;
      }

      // Находим следующее неподтвержденное разрешение
      int nextDeniedIndex = _permissionStates.indexWhere((state) => !state);

      if (nextDeniedIndex != -1) {
        // Есть еще неподтвержденные разрешения - переходим к следующему
        setState(() {
          _currentPermissionIndex = nextDeniedIndex;
          _allPermissionsGranted = false;
        });
      } else {
        // Все разрешения получены
        setState(() => _allPermissionsGranted = true);
      }
    } catch (e, _) {
      print('❌ Ошибка при запросе разрешения: $e');
      setState(() => _isRequestingPermission = false);
    }
  }

  Future<bool> _requestNetworkPermission() async {
    if (Platform.isIOS) {
      try {
        final connectivity = Connectivity();
        final connectivityResult = await connectivity.checkConnectivity();
        final hasWifi = connectivityResult.contains(ConnectivityResult.wifi);
        return hasWifi;
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

    SettingsDialog.show(context, title: title, message: message);
  }
}
