import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/core.dart';
import '../presentation.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _isConnecting = false;
  bool _isSending = false;

  Future<void> _connectToServer() async {
    if (_ipController.text.isEmpty) return;

    setState(() => _isConnecting = true);

    try {
      final service = Provider.of<FileTransferService>(context, listen: false);
      await service.connectToServer(_ipController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Успешно подключено')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка подключения: $e')));
      }
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<void> _pickAndSendMedia() async {
    final service = Provider.of<FileTransferService>(context, listen: false);

    if (!service.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сначала подключитесь к серверу')),
        );
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
              content: Text('${files.length} файл(ов) отправлено'),
              duration: Duration(seconds: 2),
            ),
          );
        }
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
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);
    final isConnected = service.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text('Files received'),
        backgroundColor: Colors.blue,
        actions: [
          if (isConnected)
            IconButton(
              icon: _isSending
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.send),
              onPressed: _isSending ? null : _pickAndSendMedia,
              tooltip: 'Отправить файлы',
            ),
        ],
      ),
      body: _buildMainContent(service, isConnected),
    );
  }

  Widget _buildMainContent(FileTransferService service, bool isConnected) {
    return Column(
      children: [
        // Поле ввода IP адреса и кнопка подключения
        Card(
          margin: EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: 'IP адрес сервера',
                    hintText: '192.168.1.100',
                    prefixIcon: Icon(Icons.wifi),
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: _isConnecting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(isConnected ? Icons.check : Icons.link),
                  label: Text(
                    _isConnecting
                        ? 'Подключение...'
                        : isConnected
                        ? 'Подключено'
                        : 'Подключиться',
                  ),
                  onPressed: _isConnecting ? null : _connectToServer,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 8),

        // Прогресс бары для получения файлов от сервера
        _buildProgressBars(service),

        // Добавляем Flexible чтобы прогресс бары занимали оставшееся место
        Expanded(child: Container()),
      ],
    );
  }

  Widget _buildProgressBars(FileTransferService service) {
    final transfers = service.activeTransfers.values.toList();

    // Группируем по типу - ОРИГИНАЛЬНАЯ ЛОГИКА
    final photoTransfers = transfers
        .where(
          (t) => t.fileType.startsWith('image/') || t.fileType == 'image/mixed',
        )
        .toList();

    final videoTransfers = transfers
        .where(
          (t) => t.fileType.startsWith('video/') || t.fileType == 'video/mixed',
        )
        .toList();

    // Рассчитываем средний прогресс для каждой группы - ОРИГИНАЛЬНАЯ ЛОГИКА
    final photoProgress = _calculateAverageProgress(photoTransfers);
    final videoProgress = _calculateAverageProgress(videoTransfers);

    // ВСЕГДА показываем прогресс-бары (убираем проверку на hasActiveTransfers)
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Прогресс получения файлов от сервера:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 12),

            // Прогресс для фото
            _buildProgressBar(
              icon: Icons.photo,
              label: 'Фотографии',
              count: photoTransfers.isEmpty
                  ? 0
                  : photoTransfers.first.totalFiles,
              progress: photoProgress,
              color: Colors.blue,
              progressText: _getProgressText(photoTransfers),
            ),

            SizedBox(height: 8),

            // Прогресс для видео
            _buildProgressBar(
              icon: Icons.videocam,
              label: 'Видео',
              count: videoTransfers.isEmpty
                  ? 0
                  : videoTransfers.first.totalFiles,
              progress: videoProgress,
              color: Colors.green,
              progressText: _getProgressText(videoTransfers),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateAverageProgress(List<FileTransfer> transfers) {
    if (transfers.isEmpty) return 0.0;
    final total = transfers.fold(
      0.0,
      (sum, transfer) => sum + transfer.progress,
    );
    return total / transfers.length;
  }

  Widget _buildProgressBar({
    required IconData icon,
    required String label,
    required int count,
    required double progress,
    required Color color,
    required String progressText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                count > 0 ? '$label ($count)' : label,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ),
            // if (count > 0)
            Text(
              '${progress.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
        // if (count > 0) ...[
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress / 100,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
        SizedBox(height: 4),
        Text(
          progressText,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        // ] else ...[
        //   SizedBox(height: 4),
        //   Text(
        //     'Нет активных передач',
        //     style: TextStyle(
        //       fontSize: 11,
        //       color: Colors.grey[600],
        //       fontStyle: FontStyle.italic,
        //     ),
        //   ),
        // ],
      ],
    );
  }

  String _getProgressText(List<FileTransfer> transfers) {
    // Для групповых передач (image/mixed или video/mixed)
    if (transfers.length == 1 && transfers.first.totalFiles > 1) {
      final transfer = transfers.first;
      // Отображаем прогресс даже если нет завершенных файлов
      final completed = transfer.completedFiles;
      final total = transfer.totalFiles;
      return '${transfer.progressSizeFormatted} • $completed/$total файлов';
    }

    // Для одиночных файлов
    int totalReceived = 0;
    int totalSize = 0;
    int completed = 0;
    int total = transfers.length;

    for (final transfer in transfers) {
      totalReceived += transfer.receivedBytes;
      totalSize += transfer.fileSize;
      if (transfer.progress >= 100) completed++;
    }

    return '${_formatBytes(totalReceived, totalSize)} • $completed/$total файлов';
  }

  String _formatBytes(int bytes, int totalBytes) {
    // Синхронизируем единицы измерения на основе общего размера
    if (totalBytes >= 1024 * 1024) {
      // Для больших файлов используем MB
      final bytesMB = bytes / (1024 * 1024);
      final totalMB = totalBytes / (1024 * 1024);
      return '${bytesMB.toStringAsFixed(2)} / ${totalMB.toStringAsFixed(2)} MB';
    } else if (totalBytes >= 1024) {
      // Для средних файлов используем KB
      final bytesKB = bytes / 1024;
      final totalKB = totalBytes / 1024;
      return '${bytesKB.toStringAsFixed(2)} / ${totalKB.toStringAsFixed(2)} KB';
    } else {
      // Для маленьких файлов используем байты
      return '$bytes / $totalBytes B';
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }
}
