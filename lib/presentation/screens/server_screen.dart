import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';

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
        ],
      ),
      body: Column(
        children: [
          // Статус сервера
          _buildStatusCard(service),

          SizedBox(height: 10),

          // Прогресс бары для принимаемых файлов
          _buildProgressBars(service),
        ],
      ),
    );
  }

  Widget _buildStatusCard(FileTransferService service) {
    final hasActiveTransfers = service.activeTransfers.isNotEmpty;

    // Считаем общий прогресс всех передач
    int totalBytesReceived = 0;
    int totalBytes = 0;

    if (hasActiveTransfers) {
      for (final transfer in service.activeTransfers.values) {
        totalBytesReceived += transfer.receivedBytes;
        totalBytes += transfer.fileSize;
      }
    }

    final totalProgress = totalBytes > 0
        ? (totalBytesReceived / totalBytes * 100)
        : 0;

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
                            SizedBox(height: 2),
                            SelectableText(
                              'ws://${service.localIp}:${FileTransferService.PORT}/ws',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      if (hasActiveTransfers) SizedBox(height: 4),
                      if (hasActiveTransfers)
                        Text(
                          'Общий прогресс приема: ${_formatBytes(totalBytesReceived)} / ${_formatBytes(totalBytes)} (${totalProgress.toStringAsFixed(1)}%)',
                          style: TextStyle(fontSize: 11, color: Colors.blue),
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
                    'Активных передач',
                    service.activeTransfers.length.toString(),
                    Colors.orange,
                  ),
                  _buildStatItem(
                    Icons.storage,
                    'Получено файлов',
                    service.receivedMedia.length.toString(),
                    Colors.purple,
                  ),
                  _buildStatItem(
                    Icons.memory,
                    'Порт',
                    FileTransferService.PORT.toString(),
                    Colors.blue,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBars(FileTransferService service) {
    final transfers = service.activeTransfers.values.toList();

    // Группируем по типу
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

    // Рассчитываем средний прогресс для каждой группы
    final photoProgress = _calculateAverageProgress(photoTransfers);
    final videoProgress = _calculateAverageProgress(videoTransfers);

    // Показываем только если есть активные передачи
    final hasActiveTransfers = photoProgress > 0 || videoProgress > 0;

    // if (!hasActiveTransfers) {
    //   return SizedBox.shrink();
    // }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Прогресс приема файлов:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 12),

            // Прогресс для фото
            if (photoTransfers.isNotEmpty)
              _buildProgressBar(
                icon: Icons.photo,
                label: 'Фотографии',
                count: photoTransfers.first.totalFiles,
                progress: photoProgress,
                color: Colors.blue,
                progressText: _getProgressText(photoTransfers),
              ),

            if (photoTransfers.isNotEmpty && videoTransfers.isNotEmpty)
              SizedBox(height: 8),

            // Прогресс для видео
            if (videoTransfers.isNotEmpty)
              _buildProgressBar(
                icon: Icons.videocam,
                label: 'Видео',
                count: videoTransfers.first.totalFiles,
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
                '$label ($count)',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ),
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
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress / 100,
          backgroundColor: color.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
        SizedBox(height: 4),
        // Строка с прогрессом в байтах
        Row(
          children: [
            Expanded(
              child: Text(
                progressText,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransferItem(FileTransfer transfer) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                transfer.fileType.startsWith('image/')
                    ? Icons.photo
                    : Icons.videocam,
                size: 16,
                color: transfer.fileType.startsWith('image/')
                    ? Colors.blue
                    : Colors.green,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  transfer.fileName,
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${transfer.progress.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: transfer.fileType.startsWith('image/')
                      ? Colors.blue
                      : Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          LinearProgressIndicator(
            value: transfer.progress / 100,
            backgroundColor: transfer.fileType.startsWith('image/')
                ? Colors.blue.withValues(alpha: 0.2)
                : Colors.green.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              transfer.fileType.startsWith('image/')
                  ? Colors.blue
                  : Colors.green,
            ),
            minHeight: 4,
          ),
          SizedBox(height: 4),
          Text(
            '${_formatBytes(transfer.receivedBytes)} / ${_formatBytes(transfer.fileSize)}',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
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

  // Вспомогательные методы для форматирования
  String _getProgressText(List<FileTransfer> transfers) {
    if (transfers.isEmpty) return '';

    // Для групповых передач
    if (transfers.length == 1 && transfers.first.totalFiles > 1) {
      final transfer = transfers.first;
      return '${transfer.progressSizeFormatted} • ${transfer.completedFiles}/${transfer.totalFiles} файлов';
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'только что';
    if (difference.inHours < 1) return '${difference.inMinutes} мин назад';
    if (difference.inDays < 1) return '${difference.inHours} час назад';
    if (difference.inDays < 7) return '${difference.inDays} дн назад';

    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  void dispose() {
    super.dispose();
  }
}
