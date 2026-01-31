import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _qrController;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _setupSubscriptionCallback();
  }

  void _setupSubscriptionCallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = Provider.of<FileTransferService>(context, listen: false);

      // Устанавливаем callback
      service.setOnSubscriptionRequiredCallback(() {
        _handleSubscriptionRequired(service);
      });
    });
  }

  void _handleSubscriptionRequired(FileTransferService service) {
    if (_isDialogShowing || !mounted) return;

    // Сбрасываем флаги подключения
    if (_isConnecting || _isConnected) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
      });
    }

    // Показываем диалог
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _showSubscriptionRequiredDialog(service);
      }
    });
  }

  @override
  void dispose() {
    // Удаляем callback при dispose
    final service = Provider.of<FileTransferService>(context, listen: false);
    service.removeOnSubscriptionRequiredCallback();

    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _qrController?.pauseCamera();
    } else if (Platform.isIOS) {
      _qrController?.resumeCamera();
    }
  }

  Future<void> _onQRViewCreated(QRViewController controller) async {
    _qrController = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (_isConnecting || _isDialogShowing) return;

      final qrData = scanData.code;
      if (qrData != null && qrData.isNotEmpty) {
        _qrController?.pauseCamera();
        await _validateAndConnect(qrData);
      }
    });
  }

  Future<void> _validateAndConnect(String qrData) async {
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
      await _connectFromQR(cleanData);
    } else {
      await _showInvalidQrDialog();
    }
  }

  Future<void> _showSubscriptionRequiredDialog(
    FileTransferService service,
  ) async {
    _isDialogShowing = true;
    _qrController?.pauseCamera();

    await OkDialog.show(
      context,
      title: 'Subscription Required',
      message:
          'To receive files, the connected iOS device must have an active Premium subscription. Please purchase it on the iOS device',
    );

    service.resetSubscriptionDialogFlag();
    _isDialogShowing = false;

    // Возобновляем сканирование
    _qrController?.resumeCamera();
  }

  Future<void> _showPlatformErrorDialog(String currentPlatform) async {
    _isDialogShowing = true;

    await OkDialog.show(
      context,
      title: 'Wrong QR Code',
      message:
          'You are using $currentPlatform device. Please, scan QR-code for $currentPlatform',
    );

    _isDialogShowing = false;
    _qrController?.resumeCamera();
  }

  Future<void> _showInvalidQrDialog() async {
    _isDialogShowing = true;

    await OkDialog.show(
      context,
      title: 'Invalid QR Code',
      message: 'QR code does not contain valid connection data.',
    );

    _isDialogShowing = false;
    _qrController?.resumeCamera();
  }

  Future<void> _connectFromQR(String qrData) async {
    setState(() => _isConnecting = true);

    try {
      final service = Provider.of<FileTransferService>(context, listen: false);

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

      // Подключение к серверу
      await service.connectToServer(serverIp, port: port);

      // КОРОТКАЯ задержка
      await Future.delayed(const Duration(milliseconds: 500));

      // Проверяем, не установился ли флаг shouldShowSubscriptionDialog
      if (service.shouldShowSubscriptionDialog) {
        // Если флаг установлен - callback уже сработал или сработает
        // Просто выходим, не показывая ConnectionStatusAlert
        setState(() => _isConnecting = false);
        _qrController?.resumeCamera();
        return;
      }

      // ДАЛЬНЕЙШАЯ ЛОГИКА ПОДКЛЮЧЕНИЯ ТОЛЬКО ЕСЛИ НЕ БЫЛО ОШИБКИ ПОДПИСКИ
      setState(() => _isConnecting = true);
      await Future.delayed(const Duration(seconds: 2));

      setState(() => _isConnected = true);

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _isConnected = false;
          });

          final bool isSending = false;
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.progress,
            arguments: isSending,
          );
        }
      });
    } catch (e) {
      print('❌ Ошибка подключения: $e');

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _isConnecting = false);
          _qrController?.resumeCamera();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: const Color.fromRGBO(255, 220, 19, 1),
              borderRadius: 32.0,
              borderLength: 44.0,
              borderWidth: 12.0,
              cutOutSize: 250,
            ),
          ),

          if (_isConnecting) ConnectionStatusAlert(isConnecting: !_isConnected),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Transform.scale(
                    scale: 1.5,
                    child: CustomIconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: SvgPicture.asset(
                        'assets/icons/cross.svg',
                        width: 20.0,
                        height: 20.0,
                      ),
                    ),
                  ),
                  CustomIconButton(
                    onPressed: () => _qrController?.toggleFlash(),
                    icon: SvgPicture.asset('assets/icons/flash.svg'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
