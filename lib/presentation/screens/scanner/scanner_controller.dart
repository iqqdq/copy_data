import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class ScannerController extends ChangeNotifier {
  final FileTransferService service;
  final ShowDialogCallback showOkDialog;
  final NavigateToCallback navigateTo;

  ScannerState _state;
  ScannerState get state => _state;

  QRViewController? qrController;

  ScannerController({
    required this.service,
    required this.showOkDialog,
    required this.navigateTo,
  }) : _state = const ScannerState(
         isConnecting: false,
         isConnected: false,
         isDialogShowing: false,
       ) {
    service.setOnSubscriptionRequiredCallback(
      () => handleSubscriptionRequired(service),
    );
  }

  // MARK: - State Updates

  void setConnecting(bool value) {
    _state = _state.copyWith(isConnecting: value);
    notifyListeners();
  }

  void setConnected(bool value) {
    _state = _state.copyWith(isConnected: value);
    notifyListeners();
  }

  void setDialogShowing(bool value) {
    _state = _state.copyWith(isDialogShowing: value);
    notifyListeners();
  }

  void setQrData(String? value) {
    _state = _state.copyWith(qrData: value);
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(connectionError: null);
    notifyListeners();
  }

  // MARK: - Business Logic

  void handleSubscriptionRequired(FileTransferService service) {
    if (_state.isDialogShowing) return;

    // Сбрасываем флаги подключения
    if (_state.isConnecting || _state.isConnected) {
      _state = _state.copyWith(isConnecting: false, isConnected: false);
      notifyListeners();
    }

    // Показываем диалог
    Future.delayed(
      Duration.zero,
      () => _showSubscriptionRequiredDialog(service),
    );
  }

  void removeSubscriptionCallback() =>
      service.removeOnSubscriptionRequiredCallback();

  Future<void> _showSubscriptionRequiredDialog(
    FileTransferService service,
  ) async {
    setDialogShowing(true);
    qrController?.pauseCamera();

    await showOkDialog(
      'Subscription Required',
      'To receive files, the connected iOS device must have an active Premium subscription. Please purchase it on the iOS device',
    );

    service.resetSubscriptionDialogFlag();
    setDialogShowing(false);

    // Возобновляем сканирование
    qrController?.resumeCamera();
  }

  void onQrViewCreated(QRViewController controller) {
    qrController = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (_state.isConnecting || _state.isDialogShowing) return;

      final qrData = scanData.code;
      if (qrData != null && qrData.isNotEmpty) {
        qrController?.pauseCamera();
        await validateAndConnect(qrData);
      }
    });
  }

  Future<void> validateAndConnect(String qrData) async {
    final isIosQr = qrData.startsWith('ios_');
    final isAndroidQr = qrData.startsWith('android_');
    final isCurrentIos = Platform.isIOS;
    final isCurrentAndroid = Platform.isAndroid;

    if ((isCurrentIos && !isIosQr) || (isCurrentAndroid && !isAndroidQr)) {
      await _showPlatformErrorDialog(isCurrentIos ? 'iOS' : 'Android');
      return;
    }

    final cleanData = qrData.replaceAll('android_', '').replaceAll('ios_', '');
    if (cleanData.isNotEmpty) {
      await connectFromQR(cleanData);
    } else {
      await _showInvalidQrDialog();
    }
  }

  Future<void> _showPlatformErrorDialog(String currentPlatform) async {
    setDialogShowing(true);

    await showOkDialog(
      'Wrong QR Code',
      'You are using $currentPlatform device. Please, scan QR-code for $currentPlatform',
    );

    setDialogShowing(false);
    qrController?.resumeCamera();
  }

  Future<void> _showInvalidQrDialog() async {
    setDialogShowing(true);

    await showOkDialog(
      'Invalid QR Code',
      'QR code does not contain valid connection data.',
    );

    setDialogShowing(false);
    qrController?.resumeCamera();
  }

  Future<void> _showConnectionErrorDialog() async {
    await showOkDialog(
      'Connection error',
      'Please, make sure both devices are connected to the same Wi-Fi network.',
    );

    Future.delayed(const Duration(seconds: 1), () {
      setConnecting(false);
      qrController?.resumeCamera();
    });
  }

  Future<void> connectFromQR(String qrData) async {
    setConnecting(true);
    setQrData(qrData);

    String serverIp;
    int port = FileTransferService.PORT;

    if (qrData.contains(':')) {
      final parts = qrData.split(':');
      serverIp = parts[0];
      if (parts.length > 1) {
        port = int.tryParse(parts[1]) ?? FileTransferService.PORT;
      }
    } else {
      serverIp = qrData;
    }

    try {
      // Подключение к серверу
      await service.connectToServer(serverIp, port: port);
    } catch (e) {
      print('❌ Ошибка подключения: $e');
      _showConnectionErrorDialog();

      return;
    }

    // Имитация загрузки
    await Future.delayed(const Duration(milliseconds: 500));

    // Проверяем, не установился ли флаг shouldShowSubscriptionDialog
    if (service.shouldShowSubscriptionDialog) {
      // Если флаг установлен - callback уже сработал или сработает
      // Просто выходим, не показывая ConnectionStatusAlert
      setConnecting(false);
      qrController?.resumeCamera();
      return;
    }

    // Имитация загрузки
    setConnecting(true);
    await Future.delayed(const Duration(seconds: 2));

    setConnected(true);

    Future.delayed(const Duration(seconds: 2), () {
      setConnecting(false);
      setConnected(false);

      final bool isSending = false;
      navigateTo(AppRoutes.progress, arguments: isSending);
    });
  }

  void toggleFlash() {
    qrController?.toggleFlash();
  }

  void pauseCamera() {
    if (Platform.isAndroid) {
      qrController?.pauseCamera();
    }
  }

  void resumeCamera() {
    if (Platform.isIOS) {
      qrController?.resumeCamera();
    }
  }

  @override
  void dispose() {
    removeSubscriptionCallback();
    qrController = null;
    super.dispose();
  }
}
