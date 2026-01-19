import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/core.dart';

class ProgressScreen extends StatefulWidget {
  final bool isSending; // true = отправка (сервер), false = получение (клиент)

  const ProgressScreen({super.key, required this.isSending});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final Map<String, bool> _cancelledTransfers = {};

  bool get _showGoToMainMenu {
    final service = Provider.of<FileTransferService>(context, listen: true);
    final transfers = service.activeTransfers.values.toList();

    if (transfers.isEmpty) {
      return true; // Все передачи завершены или отменены
    }

    // Проверяем, все ли передачи завершены (прогресс = 100%)
    final allCompleted = transfers.every((t) => t.progress >= 100);
    return allCompleted;
  }

  bool get _allTransfersCancelled {
    final service = Provider.of<FileTransferService>(context, listen: true);
    final transfers = service.activeTransfers.values.toList();

    if (transfers.isEmpty) return false;

    // Проверяем, все ли передачи отменены (есть в карте _cancelledTransfers)
    final activeTransferIds = transfers.map((t) => t.transferId).toSet();
    final cancelledTransferIds = _cancelledTransfers.keys
        .where((id) => _cancelledTransfers[id] == true)
        .toSet();

    // Все активные передачи должны быть отменены
    return activeTransferIds.every((id) => cancelledTransferIds.contains(id));
  }

  void _cancelTransfer({
    required FileTransferService service,
    required String transferId,
  }) async {
    setState(() {
      _cancelledTransfers[transferId] = true;
    });

    await service.cancelTransfer(transferId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isSending ? 'Отправка отменена' : 'Прием отменена',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );

      // Если все передачи отменены, ждем немного и показываем кнопку
      if (_allTransfersCancelled) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);
    final transfers = service.activeTransfers.values.toList();

    // Автоматически показываем кнопку "В главное меню" при завершении
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showGoToMainMenu && transfers.isNotEmpty && mounted) {
        setState(() {});
      }
    });

    if (transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isSending ? Icons.upload : Icons.download,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              widget.isSending
                  ? 'Файлы для отправки не выбраны'
                  : 'Ожидание файлов от сервера',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            if (widget.isSending)
              Text(
                'Нажмите кнопку отправки в правом верхнем углу',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
    }

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

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Карточка для фото
                    if (photoTransfers.isNotEmpty)
                      _buildTransferCard(
                        service: service,
                        transfers: photoTransfers,
                        icon: Icons.photo,
                        label: 'Фотографии',
                        color: Colors.blue,
                        isPhoto: true,
                      ),

                    SizedBox(height: 16),

                    // Карточка для видео
                    if (videoTransfers.isNotEmpty)
                      _buildTransferCard(
                        service: service,
                        transfers: videoTransfers,
                        icon: Icons.videocam,
                        label: 'Видео',
                        color: Colors.green,
                        isPhoto: false,
                      ),

                    if (photoTransfers.isEmpty && videoTransfers.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 48,
                                  color: Colors.green,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Все передачи завершены',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Автоматический возврат...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    SizedBox(height: 16),

                    // Кнопка "В главное меню" показывается только при завершении всех передач
                    if (_showGoToMainMenu && transfers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: _buildGoToMainMenuButton(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard({
    required FileTransferService service,
    required List<FileTransfer> transfers,
    required IconData icon,
    required String label,
    required Color color,
    required bool isPhoto,
  }) {
    final progress = _calculateAverageProgress(transfers);
    final count = transfers.first.totalFiles;
    final transferId = transfers.first.transferId;
    final isCancelled = _cancelledTransfers[transferId] ?? false;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок и прогресс
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$label ($count файл${_getPluralEnding(count)})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${progress.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                if (progress < 100 && !isCancelled)
                  Icon(
                    widget.isSending ? Icons.upload : Icons.download,
                    color: color.withValues(alpha: 0.7),
                  ),
                if (isCancelled) Icon(Icons.cancel, color: Colors.red),
                if (progress >= 100 && !isCancelled)
                  Icon(Icons.check_circle, color: Colors.green),
              ],
            ),

            SizedBox(height: 12),

            // Прогресс бар
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCancelled
                    ? Colors.grey
                    : (progress >= 100 ? Colors.green : color),
              ),
              minHeight: 8,
            ),

            SizedBox(height: 8),

            // Детали прогресса
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _getProgressText(transfers),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                if (isCancelled)
                  Text(
                    'Отменено',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (progress >= 100 && !isCancelled)
                  Text(
                    'Завершено',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),

            SizedBox(height: 16),

            // Кнопка отмены (показываем только если передача не завершена и не отменена)
            if (progress < 100 && !isCancelled)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.cancel, size: 20),
                  label: Text(
                    widget.isSending ? 'Cancel sending' : 'Cancel receiving',
                    style: TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  onPressed: () {
                    _cancelTransfer(service: service, transferId: transferId);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoToMainMenuButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(Icons.home, size: 24),
        label: Text(
          'В главное меню',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          // Навигация в главное меню
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
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

  String _getPluralEnding(int count) {
    if (count % 10 == 1 && count % 100 != 11) return '';
    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'а';
    }
    return 'ов';
  }

  String _getProgressText(List<FileTransfer> transfers) {
    // Для групповых передач (image/mixed или video/mixed)
    if (transfers.length == 1 && transfers.first.totalFiles > 1) {
      final transfer = transfers.first;
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
      final bytesMB = bytes / (1024 * 1024);
      final totalMB = totalBytes / (1024 * 1024);
      return '${bytesMB.toStringAsFixed(2)} / ${totalMB.toStringAsFixed(2)} MB';
    } else if (totalBytes >= 1024) {
      final bytesKB = bytes / 1024;
      final totalKB = totalBytes / 1024;
      return '${bytesKB.toStringAsFixed(2)} / ${totalKB.toStringAsFixed(2)} KB';
    } else {
      return '$bytes / $totalBytes B';
    }
  }
}
