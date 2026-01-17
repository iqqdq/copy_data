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
  bool _showScanner = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _ipController.addListener(_onIpChanged);
  }

  void _onIpChanged() {
    setState(() {});
  }

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

  Future<void> _sendFilesToServer(List<File> files) async {
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
      await service.sendFiles(files);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${files.length} файл(ов) отправлено'),
            duration: Duration(seconds: 2),
          ),
        );
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

    try {
      final pickedFiles = await ImagePicker().pickMultipleMedia();
      final files = <File>[];

      for (final image in pickedFiles) {
        files.add(File(image.path));
      }

      if (files.isNotEmpty) {
        await _sendFilesToServer(files);
      }
    } catch (e) {
      print('Ошибка выбора файлов: $e');
    }
  }

  void _toggleScanner() {
    setState(() {
      _showScanner = !_showScanner;
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);
    final isConnected = service.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(service.status),
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
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _showScanner
          ? _buildQrScanner()
          : _buildMainContent(service, isConnected),
    );
  }

  Widget _buildMainContent(FileTransferService service, bool isConnected) {
    return Column(
      children: [
        // Подключение к серверу
        Card(
          margin: EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ipController,
                        decoration: InputDecoration(
                          labelText: 'IP адрес сервера',
                          hintText: '192.168.1.100',
                          prefixIcon: Icon(Icons.wifi),
                          border: OutlineInputBorder(),
                          suffixIcon: _ipController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear),
                                  onPressed: () => _ipController.clear(),
                                )
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner),
                      onPressed: _toggleScanner,
                      tooltip: 'Сканировать QR',
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isConnecting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 10),

        // Кнопка отправки
        if (isConnected) _buildQuickActions(),

        SizedBox(height: 10),

        // Прогресс бары для фото и видео
        _buildProgressBars(service),

        // Добавим место для скролла, если контент не помещается
        Expanded(child: Container()),
      ],
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

    if (!hasActiveTransfers) {
      return SizedBox.shrink(); // Не показываем, если нет активных передач
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Прогресс передачи:',
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

  String _getProgressText(List<FileTransfer> transfers) {
    if (transfers.isEmpty) return '';

    // Для групповых передач (image/mixed или video/mixed)
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

  Widget _buildQuickActions() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Отправка файлов:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.photo, size: 20),
                    label: Text(_isSending ? 'Отправка...' : 'Выбрать файлы'),
                    onPressed: _isSending ? null : _pickAndSendMedia,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrScanner() {
    return Column(
      children: [
        AppBar(
          title: Text('Сканирование QR'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _toggleScanner,
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner, size: 100, color: Colors.grey[300]),
                SizedBox(height: 20),
                Text('QR сканер в разработке', style: TextStyle(fontSize: 18)),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _toggleScanner,
                  child: Text('Вернуться'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }
}
