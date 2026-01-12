import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/core.dart';
import '../presentation.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  bool _showQR = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startServer();
    });
  }

  Future<void> _startServer() async {
    final service = Provider.of<FileTransferService>(context, listen: false);
    if (!service.isServerRunning) {
      await service.startServer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Сервер'),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code),
            onPressed: () => setState(() => _showQR = !_showQR),
            tooltip: 'Показать QR код',
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => _showServerInfo(service),
            tooltip: 'Информация о сервере',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _restartServer(service),
            tooltip: 'Перезапустить сервер',
          ),
        ],
      ),
      body: Column(
        children: [
          // Статус сервера
          _buildStatusCard(service),

          SizedBox(height: 10),

          // QR код (если показан)
          if (_showQR && service.localIp.isNotEmpty) _buildQrCard(service),

          SizedBox(height: 10),

          // Вкладки
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(
                        icon: Icon(Icons.insert_drive_file),
                        text:
                            'Полученные файлы (${service.selectedFiles.length})',
                      ),
                      Tab(
                        icon: Icon(Icons.cloud_upload),
                        text:
                            'Активные передачи (${service.activeTransfers.length})',
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Вкладка полученных файлов
                        _buildFilesTab(service),

                        // Вкладка активных передач
                        _buildTransfersTab(service),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: service.isServerRunning
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FilePickerScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: Icon(Icons.folder_open),
              label: Text('Просмотреть файлы'),
            )
          : FloatingActionButton.extended(
              onPressed: _startServer,
              icon: Icon(Icons.play_arrow),
              label: Text('Запустить сервер'),
            ),
    );
  }

  Widget _buildStatusCard(FileTransferService service) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  service.isServerRunning ? Icons.check_circle : Icons.error,
                  color: service.isServerRunning ? Colors.green : Colors.red,
                  size: 32,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.status,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (service.localIp.isNotEmpty && service.isServerRunning)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              'WebSocket URL:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            SelectableText(
                              'ws://${service.localIp}:${FileTransferService.PORT}${FileTransferService.SERVER_PATH}',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    service.isServerRunning ? 'АКТИВЕН' : 'ОСТАНОВЛЕН',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: service.isServerRunning
                      ? Colors.green
                      : Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ],
            ),
            if (service.isServerRunning) ...[
              SizedBox(height: 12),
              Divider(height: 1),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.cloud_download,
                    'Получено файлов',
                    service.selectedFiles.length.toString(),
                    Colors.blue,
                  ),
                  _buildStatItem(
                    Icons.trending_up,
                    'Активных передач',
                    service.activeTransfers.length.toString(),
                    Colors.orange,
                  ),
                  _buildStatItem(
                    Icons.memory,
                    'Порт',
                    FileTransferService.PORT.toString(),
                    Colors.purple,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQrCard(FileTransferService service) {
    final wsUrl =
        'ws://${service.localIp}:${FileTransferService.PORT}${FileTransferService.SERVER_PATH}';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.qr_code_2, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'QR код для подключения',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: wsUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('URL скопирован в буфер обмена'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Копировать URL',
                  iconSize: 20,
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: wsUrl,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.blue,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.blue[800]!,
                ),
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                wsUrl,
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Отсканируйте QR код на клиентском устройстве',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesTab(FileTransferService service) {
    // На сервере показываем ВСЕ файлы, а не только completed
    final allFiles = service.selectedFiles;

    // Или показываем только успешно полученные файлы
    final receivedFiles = service.selectedFiles
        .where((file) => file.status == FileTransferStatus.completed)
        .toList();

    if (receivedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_download, size: 80, color: Colors.grey[300]),
            SizedBox(height: 20),
            Text(
              'Нет полученных файлов',
              style: TextStyle(fontSize: 18, color: Colors.grey[500]),
            ),
            SizedBox(height: 10),
            Text(
              'Файлы, отправленные с клиентов,\nбудут отображаться здесь',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 20),
            // Кнопка для отладки
            ElevatedButton(
              onPressed: () {
                print('=== Отладка списка файлов ===');
                print('Всего файлов: ${allFiles.length}');
                for (var file in allFiles) {
                  print(
                    '  - ${file.name} (${file.status}, transferId: ${file.transferId})',
                  );
                }
              },
              child: Text('Отладка'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Панель информации
        Container(
          padding: EdgeInsets.all(12),
          color: Colors.green[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Получено файлов: ${receivedFiles.length}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Всего файлов в списке: ${allFiles.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {
                  setState(() {});
                },
                tooltip: 'Обновить список',
              ),
            ],
          ),
        ),

        // Список файлов
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: receivedFiles.length,
            itemBuilder: (context, index) {
              final file = receivedFiles[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getFileColor(file.mimeType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        _getFileIcon(file.mimeType),
                        color: _getFileColor(file.mimeType),
                        size: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    file.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_formatFileSize(file.size)} • ${_getFileType(file.mimeType)}',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Статус: ${_getStatusText(file.status)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: _getStatusColor(file.status),
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.open_in_new, size: 18),
                        onPressed: () => _openFile(file),
                        tooltip: 'Открыть файл',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Добавьте вспомогательные методы:
  String _getStatusText(FileTransferStatus status) {
    switch (status) {
      case FileTransferStatus.pending:
        return 'Ожидание';
      case FileTransferStatus.transferring:
        return 'Передача';
      case FileTransferStatus.completed:
        return 'Получен';
      case FileTransferStatus.failed:
        return 'Ошибка';
      case FileTransferStatus.paused:
        return 'Пауза';
      case FileTransferStatus.cancelled:
        return 'Отменен';
    }
  }

  Color _getStatusColor(FileTransferStatus status) {
    switch (status) {
      case FileTransferStatus.completed:
        return Colors.green;
      case FileTransferStatus.transferring:
        return Colors.blue;
      case FileTransferStatus.failed:
        return Colors.red;
      case FileTransferStatus.pending:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTransfersTab(FileTransferService service) {
    if (service.activeTransfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sync, size: 80, color: Colors.grey[300]),
            SizedBox(height: 20),
            Text(
              'Нет активных передач',
              style: TextStyle(fontSize: 18, color: Colors.grey[500]),
            ),
            SizedBox(height: 10),
            Text(
              'Когда клиенты будут отправлять файлы,\nздесь отобразится прогресс',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Заголовок
        Container(
          padding: EdgeInsets.all(12),
          color: Colors.orange[50],
          child: Row(
            children: [
              Icon(Icons.sync, color: Colors.orange),
              SizedBox(width: 10),
              Text(
                'Активные передачи: ${service.activeTransfers.length}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Text(
                'Скачивание файлов...',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),

        // Список передач
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: service.activeTransfers.length,
            itemBuilder: (context, index) {
              final transfer = service.activeTransfers.values.elementAt(index);
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircularProgressIndicator(
                    value: transfer.file.progress / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                  title: Text(
                    transfer.file.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: transfer.file.progress / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${transfer.file.progress.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            _formatFileSize(transfer.file.size),
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      transfer.file.status == FileTransferStatus.transferring
                          ? 'Загрузка...'
                          : 'Завершено',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    backgroundColor:
                        transfer.file.status == FileTransferStatus.transferring
                        ? Colors.orange
                        : Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _calculateTotalSize(List<FileInfo> files) {
    final totalBytes = files.fold<int>(0, (sum, file) => sum + file.size);
    return _formatFileSize(totalBytes);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} д. назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ч. назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} мин. назад';
    } else {
      return 'Только что';
    }
  }

  Color _getFileColor(String mimeType) {
    if (mimeType.startsWith('image/')) return Colors.red;
    if (mimeType.startsWith('video/')) return Colors.purple;
    if (mimeType.startsWith('audio/')) return Colors.blue;
    if (mimeType.contains('pdf')) return Colors.red;
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Colors.blue;
    }
    if (mimeType.contains('excel') || mimeType.contains('sheet')) {
      return Colors.green;
    }
    return Colors.grey;
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) {
      return Icons.description;
    }
    if (mimeType.contains('excel') || mimeType.contains('sheet')) {
      return Icons.table_chart;
    }
    if (mimeType.contains('zip') || mimeType.contains('rar')) {
      return Icons.archive;
    }
    return Icons.insert_drive_file;
  }

  String _getFileType(String mimeType) {
    if (mimeType.startsWith('image/')) return 'Изображение';
    if (mimeType.startsWith('video/')) return 'Видео';
    if (mimeType.startsWith('audio/')) return 'Аудио';
    if (mimeType.contains('pdf')) return 'PDF';
    if (mimeType.contains('word')) return 'Документ Word';
    if (mimeType.contains('excel')) return 'Таблица Excel';
    if (mimeType.contains('zip')) return 'Архив';
    return 'Файл';
  }

  void _showServerInfo(FileTransferService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 10),
            Text('Информация о сервере'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              'Статус:',
              service.isServerRunning ? 'Активен' : 'Остановлен',
            ),
            if (service.isServerRunning) ...[
              _buildInfoRow('Локальный IP:', service.localIp),
              _buildInfoRow('Порт:', FileTransferService.PORT.toString()),
              _buildInfoRow('WebSocket путь:', FileTransferService.SERVER_PATH),
              SizedBox(height: 10),
              Divider(),
              SizedBox(height: 10),
              Text(
                'Статистика:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildInfoRow(
                'Получено файлов:',
                service.selectedFiles.length.toString(),
              ),
              _buildInfoRow(
                'Активных передач:',
                service.activeTransfers.length.toString(),
              ),
              SizedBox(height: 10),
              Divider(),
              SizedBox(height: 10),
              Text(
                'Как подключиться:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                '1. На клиентском устройстве введите IP: ${service.localIp}',
              ),
              Text('2. Порт: ${FileTransferService.PORT}'),
              Text('3. Нажмите "Подключиться"'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Закрыть'),
          ),
          if (service.isServerRunning)
            TextButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text:
                        'ws://${service.localIp}:${FileTransferService.PORT}${FileTransferService.SERVER_PATH}',
                  ),
                );
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('URL скопирован')));
                Navigator.pop(context);
              },
              child: Text('Копировать URL'),
            ),
        ],
      ),
    );
  }

  Future<void> _restartServer(FileTransferService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Перезапустить сервер?'),
        content: Text('Текущие подключения будут разорваны.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Перезапустить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await service.stopServer();
      await Future.delayed(Duration(milliseconds: 500));
      await service.startServer();
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _openFile(FileInfo file) async {
    try {
      // Запрашиваем разрешения (если нужно)
      final hasPermission = await FileOpener.requestStoragePermission();

      if (!hasPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Необходимо разрешение на доступ к файлам')),
        );
        return;
      }

      // Проверяем, существует ли файл
      final fileObj = File(file.path);
      if (!await fileObj.exists() && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Файл не найден: ${file.name}')));
        return;
      }

      // Проверяем, поддерживается ли тип файла
      if (!FileOpener.isFileTypeSupported(file.path) && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Предупреждение'),
            content: Text(
              'Этот тип файла может не поддерживаться. Продолжить?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Продолжить'),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      await FileOpener.openFile(file.path);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Закрываем диалог загрузки
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка открытия файла: $e')));
      }
    }
  }

  Future<void> _shareFile(FileInfo file) async {
    // TODO: Реализовать шаринг файла
    // Можно использовать пакет share_plus: ^6.3.0
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Шаринг файлов будет реализован в следующей версии'),
      ),
    );
  }
}
