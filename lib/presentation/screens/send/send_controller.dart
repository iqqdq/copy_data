import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:image_picker/image_picker.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class SendController extends ChangeNotifier {
  final FileTransferService service;
  final ShowPremiumDialogCallback showPremiumDialog;
  final ShowToastCallback showToast;
  final NavigateToCallback navigateTo;

  SendState _state;
  SendState get state => _state;

  String get getQrData {
    final prefix = _state.selectedIndex == 0 ? 'ios_' : 'android_';
    return '$prefix${service.localIp}:${FileTransferService.PORT}';
  }

  String get title => _state.selectedIndex == 0
      ? 'Send file to IOS device'
      : 'Send file to Android device';

  SendController({
    required this.service,
    required this.showPremiumDialog,
    required this.showToast,
    required this.navigateTo,
  }) : _state = SendState(
         selectedIndex: 0,
         isConnecting: false,
         isConnected: false,
         tabInitialized: {0: false, 1: false},
         isClientConnected: false,
       ) {
    // Слушаем изменения в сервисе
    _setupConnectionListeners();
  }

  // MARK: - Настройка слушателей

  void _setupConnectionListeners() => service.addListener(_onServiceChanged);

  void _onServiceChanged() => _checkConnectionStatus();

  // MARK: - State Updates

  void setSelectedIndex(int index) {
    _state = _state.copyWith(selectedIndex: index);
    notifyListeners();
  }

  void setConnecting(bool value) {
    _state = _state.copyWith(isConnecting: value);
    notifyListeners();
  }

  void setConnected(bool value) {
    _state = _state.copyWith(isConnected: value);
    notifyListeners();
  }

  void setTabInitialized(int index, bool value) {
    final newTabInitialized = Map<int, bool>.from(_state.tabInitialized);
    newTabInitialized[index] = value;
    _state = _state.copyWith(tabInitialized: newTabInitialized);
    notifyListeners();
  }

  void setClientConnected(bool value) {
    _state = _state.copyWith(isClientConnected: value);
    notifyListeners();
  }

  void setSendError(String? error) {
    _state = _state.copyWith(sendError: error);
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(sendError: null);
    notifyListeners();
  }

  // MARK: - Business Logic

  Future<void> startServer() async {
    if (!service.isServerRunning) {
      await service.startServer();
    }
  }

  Future<void> stopServer() async {
    if (service.isServerRunning) {
      await service.stopServer();
    }
  }

  void _checkConnectionStatus() {
    if (service.connectedClients.isNotEmpty) {
      setClientConnected(true);
      handleClientConnected();
    } else {
      setClientConnected(false);
      handleClientDisconnected();
    }

    // Автоматическая отправка при первом подключении
    // if (service.connectedClients.isNotEmpty && !_state.autoSendTriggered) {
    //   triggerAutoSend();
    // }
  }

  Future<void> handleClientConnected() async {
    if (_state.isConnecting) return;

    // Задержка 2 сек перед установкой флага подключения
    setConnecting(true);
    await Future.delayed(const Duration(seconds: 2));

    // Задержка для показа флага подключения
    setConnected(true);

    // Открытие галереи
    Future.delayed(const Duration(seconds: 2), () async {
      setConnecting(false);
      setConnected(false);

      await pickAndSendMedia();
    });
  }

  void handleClientDisconnected() {
    print('🔌 Клиент отключился');
    setConnecting(false);
    setConnected(false);
  }

  Future<void> pickAndSendMedia() async {
    try {
      // Проверяем подписку при подключении Android к iOS
      if (_state.selectedIndex == 1 && !isSubscribed.value) {
        await showPremiumDialog(
          'Premium Required',
          'Sending files to Android devices is available only with a Premium subscription',
          () => navigateTo(AppRoutes.paywall),
        );
        return;
      }

      final appSettings = AppSettingsService.instance;
      final remainingFileTransfers = appSettings.remainingFileTransfers;
      late List<XFile> pickedFiles;

      // Если пользователь уже подписан - просто выбираем файлы
      if (isSubscribed.value) {
        pickedFiles = await ImagePicker().pickMultipleMedia();
      }
      // Если пользователь не подписан
      else {
        // Проверяем, достигнут ли лимит
        if (appSettings.isFileTransferLimitReached) {
          // Лимит достигнут - показываем paywall
          await navigateTo(AppRoutes.paywall);

          // Проверяем статус подписки после paywall
          if (!isSubscribed.value) {
            // Пользователь не подписался - выходим
            return;
          } else {
            // Пользователь подписался - выбираем файлы без ограничений
            pickedFiles = await ImagePicker().pickMultipleMedia();
          }
        } else {
          // Лимит НЕ достигнут - показываем paywall сразу
          await navigateTo(AppRoutes.paywall);

          // Выбираем файлы после paywall
          pickedFiles = await ImagePicker().pickMultipleMedia();

          // Если пользователь не подписался - обрезаем до лимита
          if (!isSubscribed.value && pickedFiles.isNotEmpty) {
            pickedFiles = pickedFiles.take(remainingFileTransfers).toList();
          }
        }
      }

      final files = <File>[];
      for (final image in pickedFiles) {
        files.add(File(image.path));
      }

      if (files.isNotEmpty) {
        navigateTo(AppRoutes.progress, arguments: true);
        await service.sendFilesToConnectedClient(files);
      }
    } catch (e) {
      showToast('There was an error while sending files');
      setSendError(e.toString());
    }
  }

  void onTabSelected(int index) {
    if (!_state.tabInitialized[index]!) {
      setSelectedIndex(index);
      setTabInitialized(index, true);
    } else {
      setSelectedIndex(index);
    }
  }

  @override
  void dispose() {
    service.removeListener(_onServiceChanged);
    super.dispose();
  }
}
