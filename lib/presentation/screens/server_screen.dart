import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/core.dart';
import '../presentation.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  int _selectedIndex = 0;
  bool _isSending = false;
  bool _showProgress = false;
  bool _autoSendTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startServer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Слушаем изменения в FileTransferService
    final service = Provider.of<FileTransferService>(context);

    // Когда появляются подключенные клиенты и еще не было автоматической отправки
    if (service.connectedClients.isNotEmpty &&
        !_autoSendTriggered &&
        !_showProgress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerAutoSend(service);
      });
    }
  }

  Future<void> _startServer() async {
    final service = Provider.of<FileTransferService>(context, listen: false);
    if (!service.isServerRunning) {
      await service.startServer();
    }
  }

  Future<void> _triggerAutoSend(FileTransferService service) async {
    setState(() {
      _showProgress = true;
      _autoSendTriggered = true;
    });

    // Небольшая задержка перед автоматической отправкой
    await Future.delayed(Duration(milliseconds: 500));

    // Автоматически запускаем выбор и отправку файлов
    await _pickAndSendMedia();
  }

  Future<void> _pickAndSendMedia() async {
    final service = Provider.of<FileTransferService>(context, listen: false);

    if (service.connectedClients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Нет подключенных клиентов')));
      }
      return;
    }

    setState(() => _isSending = true);

    try {
      final pickedFiles = await ImagePicker().pickMultipleMedia();
      final files = <File>[];

      for (final image in pickedFiles) {
        files.add(File(image.path));
      }

      if (files.isNotEmpty) {
        await service.sendFilesToConnectedClient(files);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${files.length} файл(ов) отправлено клиенту'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Если пользователь не выбрал файлы, возвращаемся к QR-коду
        setState(() {
          _showProgress = false;
          _autoSendTriggered = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // При ошибке тоже возвращаемся к QR-коду
      setState(() {
        _showProgress = false;
        _autoSendTriggered = false;
      });
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: _showProgress ? 'Sending files' : 'Send file',
        leading: _showProgress
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _showProgress = false;
                    _autoSendTriggered = false;
                  });
                },
              )
            : null,
      ),
      body: _showProgress
          ? ProgressScreen(isSending: true)
          : _buildQrCodeCard(service),
    );
  }

  Widget _buildQrCodeCard(FileTransferService service) {
    final serverInfo = '${service.localIp}:${FileTransferService.PORT}';
    final hasClients = service.connectedClients.isNotEmpty;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomTabBar(
              tabs: ['Transfer to IOS', 'Transfer to Android'],
              selectedIndex: _selectedIndex,
              onTabSelected: (index) => setState(() => _selectedIndex = index),
            ),
            Card(
              margin: EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      'Tap Receive and scan the QR code on the sending device to get the files',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),

                    // QR-код (показываем всегда)
                    QrImageView(
                      data: serverInfo,
                      version: QrVersions.auto,
                      size: 250,
                      backgroundColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
