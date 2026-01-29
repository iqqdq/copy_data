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
  bool _isConnecting = false;
  QRViewController? _qrController;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

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
      if (_isConnecting) return;

      final qrData = scanData.code
          ?.replaceAll('android_', '')
          .replaceAll('ios_', '');
      if (qrData != null && qrData.isNotEmpty) {
        _qrController?.pauseCamera();
        await _connectFromQR(qrData);
      }
    });
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

      // Задержка 2 секунды перед установкой флага подключения
      await Future.delayed(const Duration(seconds: 2));

      // Переход на ProgressScreen
      if (mounted) {
        setState(() => _isConnecting = true);

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            final bool isSending = false;
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.progress,
              arguments: isSending,
            );
          }
        });
      }
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
          if (_isConnecting) ConnectionStatusAlert(isConnecting: _isConnecting),

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
