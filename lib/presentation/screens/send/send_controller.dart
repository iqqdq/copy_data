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
         autoSendTriggered: false,
         isConnecting: false,
         isConnected: false,
         tabInitialized: {0: false, 1: false},
         isClientConnected: false,
       );

  // MARK: - State Updates

  void setSelectedIndex(int index) {
    _state = _state.copyWith(selectedIndex: index);
    notifyListeners();
  }

  void setAutoSendTriggered(bool value) {
    _state = _state.copyWith(autoSendTriggered: value);
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

  void checkConnectionStatus(FileTransferService service) {
    if (service.connectedClients.isNotEmpty) {
      setClientConnected(true);
      handleClientConnected();
    } else {
      setClientConnected(false);
      handleClientDisconnected();
    }

    // Автоматическая отправка при первом подключении
    if (service.connectedClients.isNotEmpty && !_state.autoSendTriggered) {
      triggerAutoSend();
    }
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
    setAutoSendTriggered(false);
    setConnecting(false);
  }

  Future<void> triggerAutoSend() async {
    if (_state.isConnecting) return;

    setAutoSendTriggered(true);
    await Future.delayed(const Duration(milliseconds: 500));
    await pickAndSendMedia();
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

      // Проверяем подписку на недельный лимит файлов
      late List<XFile> pickedFiles;

      if (isSubscribed.value) {
        pickedFiles = await ImagePicker().pickMultipleMedia();
      } else {
        final appSettings = AppSettingsService.instance;
        final remainingFileTransfers = appSettings.remainingFileTransfers;

        if (appSettings.isFileTransferLimitReached) {
          // Если достигунт недельный лимит файлов для передачи показываем paywall
          await navigateTo(AppRoutes.paywall);
          return;
        } else {
          // Иначе даем пользователю выбрать файлы
          pickedFiles = await ImagePicker().pickMultipleMedia();

          if (pickedFiles.isNotEmpty) {
            // Показываем paywall
            await navigateTo(AppRoutes.paywall);

            // Если пользователь не подписался - обрезаем кол-во выбранных файлов до недельного лимита
            // Максимальное кол-во в неделю - 10 файлов
            if (!isSubscribed.value) {
              pickedFiles = pickedFiles.take(remainingFileTransfers).toList();
            }
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
        return;
      } else {
        setAutoSendTriggered(false);
      }
    } catch (e) {
      showToast('There was an error while sending files');
      setAutoSendTriggered(false);
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
}
