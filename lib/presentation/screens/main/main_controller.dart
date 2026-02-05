import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class MainController extends ChangeNotifier {
  final ShowDialogCallback showSettingsDialog;
  final NavigateToCallback navigateTo;
  final ShowToastCallback showToast;

  MainState _state;
  MainState get state => _state;

  MainController({
    required this.showSettingsDialog,
    required this.navigateTo,
    required this.showToast,
  }) : _state = MainState(
         permissionStates: [false, false, false],
         isCheckingPermissions: false,
         showPermissionAlert: false,
         allPermissionsGranted: false,
         isRequestingPermission: false,
         currentPermissionIndex: Platform.isAndroid ? 1 : 0,
       ) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Проверяем разрешения
    await _checkPermissions();
  }

  Future<void> handleRoleSelection(int roleIndex) async {
    // Всегда проверяем разрешения перед выбором роли
    await _checkPermissions();

    // Проверяем, все ли разрешения получены
    bool allGranted = _state.permissionStates.every((state) => state);

    if (!allGranted) {
      // Если не все разрешения получены, показываем алерт
      int firstDeniedIndex = _state.permissionStates.indexWhere(
        (state) => !state,
      );

      _state = _state.copyWith(
        currentPermissionIndex: firstDeniedIndex,
        showPermissionAlert: true,
        allPermissionsGranted: false,
      );
      notifyListeners();

      return;
    }

    // Если все разрешения получены И алерт закрыт, переходим к экрану
    await navigateTo(roleIndex == 0 ? AppRoutes.send : AppRoutes.receive);
  }

  Future<void> requestNextPermission() async {
    if (_state.isRequestingPermission) return;

    _state = _state.copyWith(isRequestingPermission: true);
    notifyListeners();

    try {
      bool permissionGranted = false;

      switch (_state.currentPermissionIndex) {
        case 0: // Local Network/Wi-Fi
          permissionGranted = await _requestNetworkPermission();
          break;
        case 1: // Photos & Videos
          permissionGranted = await _requestMediaPermission();
          break;
        case 2: // Camera
          permissionGranted = await _requestCameraPermission();
          break;
      }

      // Обновляем состояние разрешения
      List<bool> updatedStates = List.from(_state.permissionStates);
      updatedStates[_state.currentPermissionIndex] = permissionGranted;

      // Проверяем, все ли разрешения теперь получены
      final allPermissionsGranted = updatedStates.every((state) => state);

      _state = _state.copyWith(
        permissionStates: updatedStates,
        isRequestingPermission: false,
        allPermissionsGranted: allPermissionsGranted,
      );
      notifyListeners();

      // Если разрешение не получено, показываем индивидуальный алерт
      if (!permissionGranted) {
        _showIndividualPermissionDialog(_state.currentPermissionIndex);

        // Находим следующее неподтвержденное разрешение
        int nextDeniedIndex = updatedStates.indexWhere((state) => !state);

        if (nextDeniedIndex != -1) {
          _state = _state.copyWith(currentPermissionIndex: nextDeniedIndex);
          notifyListeners();
        }

        return;
      }

      // Находим следующее неподтвержденное разрешение
      int nextDeniedIndex = updatedStates.indexWhere((state) => !state);

      if (nextDeniedIndex != -1) {
        // Есть еще неподтвержденные разрешения - переходим к следующему
        _state = _state.copyWith(
          currentPermissionIndex: nextDeniedIndex,
          allPermissionsGranted: false,
        );
        notifyListeners();
      } else {
        // Все разрешения получены - показываем оценку
        Future.delayed(const Duration(milliseconds: 300), () async {
          await _showRateAppDialog();
        });
      }
    } catch (e) {
      print('❌ Ошибка при запросе разрешения: $e');
      _state = _state.copyWith(isRequestingPermission: false);
      notifyListeners();
    }
  }

  void hidePermissionAlert() async {
    _state = _state.copyWith(
      showPermissionAlert: false,
      allPermissionsGranted: false,
    );
    notifyListeners();

    // После закрытия permission alert показываем оценку
    Future.delayed(const Duration(milliseconds: 300), () async {
      await _showRateAppDialog();
    });
  }

  Future<void> _checkPermissions() async {
    await Future.delayed(Duration(milliseconds: 300));

    if (_state.isCheckingPermissions) return;

    _state = _state.copyWith(isCheckingPermissions: true);
    notifyListeners();

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

      // Проверяем, все ли разрешения получены
      final allPermissionsGranted = newStates.every((state) => state);

      _state = _state.copyWith(
        permissionStates: newStates,
        isCheckingPermissions: false,
        showPermissionAlert: !allPermissionsGranted,
        allPermissionsGranted: allPermissionsGranted,
      );

      // Если есть неподтвержденные разрешения, находим первое
      if (!allPermissionsGranted) {
        final currentPermissionIndex = newStates.indexWhere((state) => !state);
        _state = _state.copyWith(
          currentPermissionIndex: currentPermissionIndex,
        );
      } else {
        // Если все разрешения есть при запуске - показываем оценку сразу
        await _showRateAppDialog();
      }

      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(isCheckingPermissions: false);
      notifyListeners();
      print('❌ Ошибка при запросе разрешений: $e');
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

    showSettingsDialog(title, message);
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

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }
}
