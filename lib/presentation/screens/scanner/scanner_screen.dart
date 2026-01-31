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
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _qrController?.pauseCamera();
    } else if (Platform.isIOS) {
      _qrController?.resumeCamera();
    }
  }

  Future<void> _onQRViewCreated(QRViewController controller) async {
    controller.scannedDataStream.listen((scanData) async {
      // Игнорируем новые сканы если идет подключение или показывается диалог
      if (_isConnecting || _isDialogShowing) return;

      final qrData = scanData.code;
      if (qrData != null && qrData.isNotEmpty) {
        _qrController?.pauseCamera();
        await _validateAndConnect(qrData);
      }
    });
  }

  Future<void> _validateAndConnect(String qrData) async {
    // Проверяем префикс платформы
    final isIosQr = qrData.startsWith('ios_');
    final isAndroidQr = qrData.startsWith('android_');

    // Получаем текущую платформу
    final isCurrentIos = Platform.isIOS;
    final isCurrentAndroid = Platform.isAndroid;

    if ((isCurrentIos && !isIosQr) || (isCurrentAndroid && !isAndroidQr)) {
      // Сканируется QR-код для той же платформы - показываем ошибку
      await _showPlatformErrorDialog(isCurrentIos ? 'iOS' : 'Android');
      return;
    }

    // Если QR-код без префикса (старый формат) - обрабатываем
    final cleanData = qrData.replaceAll('android_', '').replaceAll('ios_', '');

    if (cleanData.isNotEmpty) {
      await _connectFromQR(cleanData);
    } else {
      await _showInvalidQrDialog();
    }
  }

  Future<void> _showPlatformErrorDialog(String currentPlatform) async {
    _isDialogShowing = true;

    await OkDialog.show(
      context,
      title: 'Wrong QR Code',
      message:
          'You are using $currentPlatform device.\n'
          'Please, scan QR-code for $currentPlatform',
    );

    _isDialogShowing = false;

    // Возобновляем камеру после закрытия диалога
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

    // Возобновляем камеру после закрытия диалога
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

      // Задержка 2 сек перед установкой флага подключения
      setState(() => _isConnecting = true);
      await Future.delayed(const Duration(seconds: 2));

      // Задержка для показа флага подключения
      setState(() => _isConnected = true);

      // Переход на ProgressScreen
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _isConnecting = false;
          _isConnected = false;
        });

        if (mounted) {
          final bool isSending = false;
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.progress,
            arguments: isSending,
          );
        }
      });
    } catch (e) {
      // Возобновляем сканирование при ошибке
      Future.delayed(const Duration(seconds: 2), () {
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

          // ConnectionStatusAlert при подключении к серверу
          if (_isConnecting) ConnectionStatusAlert(isConnecting: !_isConnected),

          // Верхняя панель
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
