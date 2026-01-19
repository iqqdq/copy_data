import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/core.dart';

class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  bool _isSending = false;

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

    return Scaffold(
      appBar: AppBar(
        title: Text('Сервер'),
        backgroundColor: Colors.green,
        actions: [
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
            tooltip: 'Отправить файлы клиенту',
          ),
        ],
      ),
      body: Column(
        children: [
          // Поле с IP адресом сервера
          _buildServerInfoCard(service),

          SizedBox(height: 8),

          // Прогресс бары для отправки файлов клиенту
          _buildProgressBars(service),

          Expanded(child: Container()),
        ],
      ),
    );
  }

  Widget _buildServerInfoCard(FileTransferService service) {
    return Card(
      margin: EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                              'IP адрес сервера:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 2),
                            SelectableText(
                              service.localIp,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Порт: ${FileTransferService.PORT}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

    // ВСЕГДА показываем прогресс-бары
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Прогресс отправки файлов клиенту:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 12),

            // Прогресс для фото (ВСЕГДА показываем)
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

            // Прогресс для видео (ВСЕГДА показываем)
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
            if (count > 0)
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
        if (count > 0) ...[
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
        ] else ...[
          SizedBox(height: 4),
          Text(
            'Нет активных передач',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  String _getProgressText(List<FileTransfer> transfers) {
    // if (transfers.isEmpty) return 'Нет активных передач';

    // Для групповых передач (image/mixed или video/mixed) - ОРИГИНАЛЬНАЯ ЛОГИКА
    if (transfers.length == 1 && transfers.first.totalFiles > 1) {
      final transfer = transfers.first;
      return '${transfer.progressSizeFormatted} • ${transfer.completedFiles}/${transfer.totalFiles} файлов';
    }

    // Для одиночных файлов - ОРИГИНАЛЬНАЯ ЛОГИКА
    int totalReceived = 0;
    int totalSize = 0;
    int completed = 0;
    int total = transfers.length;

    for (final transfer in transfers) {
      totalReceived += transfer.receivedBytes;
      totalSize += transfer.fileSize;
      if (transfer.progress >= 100) completed++;
    }

    return '${_formatBytes(totalReceived)} / ${_formatBytes(totalSize)} • $completed/$total файлов';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  void dispose() {
    super.dispose();
  }
}
