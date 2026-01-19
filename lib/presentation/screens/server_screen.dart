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
      appBar: AppBar(
        title: Text(_showProgress ? 'Отправка файлов' : 'Сервер'),
        backgroundColor: Colors.green,
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
            Card(
              margin: EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      hasClients
                          ? 'Клиент подключен!'
                          : 'Сканируйте QR-код на клиенте',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: hasClients ? Colors.green : Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),

                    // QR-код (показываем всегда)
                    QrImageView(
                      data: serverInfo,
                      version: QrVersions.auto,
                      size: 250,
                      backgroundColor: Colors.white,
                    ),

                    SizedBox(height: 20),

                    // Информация о сервере
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Информация о сервере:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Статус: ${service.status}',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          SelectableText(
                            'IP: ${service.localIp}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Порт: ${FileTransferService.PORT}',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            hasClients
                                ? '✅ Клиент подключен'
                                : '⏳ Ожидание подключения...',
                            style: TextStyle(
                              fontSize: 14,
                              color: hasClients ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Индикатор/статус подключения
                    if (hasClients)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Подключение установлено!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            if (_isSending)
                              Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Автоматический выбор файлов...',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                'Автоматически открывается выбор файлов...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.help, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Как подключиться:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '1. Откройте приложение на другом устройстве\n'
                              '2. Нажмите "Подключиться"\n'
                              '3. Наведите камеру на этот QR-код\n'
                              '4. Подключение произойдет автоматически',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
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
