import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  bool _isConnecting = false;
  bool _showScanner = true;
  bool _isConnected = false;
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
    _qrController = controller;

    // Обработка разрешений
    controller.scannedDataStream.listen((scanData) async {
      if (_isConnecting || _isConnected) return;

      final qrData = scanData.code;
      if (qrData != null && qrData.isNotEmpty) {
        _qrController?.pauseCamera();
        await _connectFromQR(qrData);
      }
    });

    // Проверка фонарика
    controller.getFlashStatus().then((isFlashOn) {
      // Можно добавить управление вспышкой
    });
  }

  Future<void> _connectFromQR(String qrData) async {
    setState(() {
      _isConnecting = true;
    });

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

      await service.connectToServer(serverIp, port: port);

      // Добавляем небольшую задержку для лучшего UX
      await Future.delayed(Duration(milliseconds: 500));

      setState(() {
        _isConnected = true;
        _showScanner = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Успешно подключено к $serverIp:$port'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка подключения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // Возобновляем сканирование при ошибке
      Future.delayed(Duration(seconds: 2), () {
        _qrController?.resumeCamera();
      });

      setState(() {
        _isConnected = false;
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        QRView(
          key: qrKey,
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: Color.fromRGBO(255, 220, 19, 1),
            borderRadius: 32.0,
            borderLength: 44.0,
            borderWidth: 12.0,
            cutOutSize: 250,
          ),
        ),

        // Индикатор сканирования
        if (_isConnecting)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Подключение...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Верхняя панель
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);

    // Проверяем подключение и переключаемся на прогресс
    if (service.isConnected && _showScanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _showScanner = false;
          _isConnected = true;
        });
      });
    }

    return Scaffold(
      appBar: _showScanner ? null : CustomAppBar(title: 'Receiving files'),
      body: _showScanner
          ? _buildScannerView()
          : ProgressScreen(isSending: false),
    );
  }
}
