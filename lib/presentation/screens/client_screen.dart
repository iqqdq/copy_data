import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/core.dart';
import '../presentation.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  bool _isConnecting = false;
  bool _isSending = false;
  bool _showScanner = true;
  bool _isConnected = false;
  bool _hasCameraPermission = false;
  QRViewController? _qrController;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    setState(() {
      _hasCameraPermission = status.isGranted;
    });

    if (!status.isGranted) {
      final result = await Permission.camera.request();
      setState(() {
        _hasCameraPermission = result.isGranted;
      });
    }
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Успешно подключено к $serverIp:$port'),
          backgroundColor: Colors.green,
        ),
      );
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
    if (!_hasCameraPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.close_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'Необходим доступ к камере',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Разрешите доступ к камере в настройках',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              child: Text('Открыть настройки'),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: _checkCameraPermission,
              child: Text('Проверить снова'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        QRView(
          key: qrKey,
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: Colors.blue,
            borderRadius: 10,
            borderLength: 30,
            borderWidth: 8,
            cutOutSize: 250,
          ),
        ),

        // Индикатор сканирования
        if (_isConnecting)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
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
        Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          left: 20,
          right: 20,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сканирование QR-кода',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Наведите камеру на QR-код сервера',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Нижняя панель с инструкцией
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Инструкция:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '1. Убедитесь, что сервер запущен\n'
                  '2. Наведите камеру на QR-код сервера\n'
                  '3. Подключение произойдет автоматически',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // Кнопка ручного ввода
        Positioned(
          bottom: 100,
          right: 20,
          child: FloatingActionButton(
            onPressed: _showManualInputDialog,
            child: Icon(Icons.keyboard),
            backgroundColor: Colors.blue,
            mini: true,
          ),
        ),
      ],
    );
  }

  Future<void> _showManualInputDialog() async {
    final TextEditingController inputController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ручной ввод'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Введите IP адрес сервера:'),
            SizedBox(height: 16),
            TextField(
              controller: inputController,
              decoration: InputDecoration(
                hintText: '192.168.1.100:8080',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, inputController.text.trim()),
            child: Text('Подключиться'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _qrController?.pauseCamera();
      await _connectFromQR(result);
    }
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
      appBar: AppBar(
        title: Text(_showScanner ? 'Сканер QR-кода' : 'Получение файлов'),
        backgroundColor: _showScanner ? Colors.blue : Colors.green,
        actions: _showScanner
            ? [
                IconButton(
                  icon: Icon(Icons.flash_on),
                  onPressed: () {
                    _qrController?.toggleFlash();
                  },
                  tooltip: 'Вспышка',
                ),
              ]
            : [
                if (service.isConnected)
                  IconButton(
                    icon: _isSending
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          )
                        : Icon(Icons.send),
                    onPressed: () async {
                      setState(() => _isSending = true);
                      await Future.delayed(Duration(seconds: 1));
                      setState(() => _isSending = false);
                    },
                    tooltip: 'Отправить файлы',
                  ),
              ],
      ),
      body: _showScanner
          ? _buildScannerView()
          : ProgressScreen(isSending: false),
    );
  }
}
