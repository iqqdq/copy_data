import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  Future<void> _sendFilesToServer() async {
    final service = Provider.of<FileTransferService>(context, listen: false);

    if (service.selectedFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Сначала добавьте файлы')));
      return;
    }

    if (!service.isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Сначала подключитесь к серверу')));
      return;
    }

    try {
      await service.sendFiles(service.selectedFiles);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Файлы отправлены')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e')));
      }
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
        title: Text('Клиент'),
        actions: [
          if (isConnected)
            IconButton(
              icon: Icon(Icons.send),
              onPressed: _sendFilesToServer,
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
      floatingActionButton: _showScanner
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FilePickerScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: Icon(Icons.add),
              label: Text('Добавить файлы'),
            ),
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
                    if (isConnected) ...[
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          service.disconnect();
                          _ipController.clear();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Отключиться'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        // Статус подключения
        if (isConnected && service.connectedServerName != null)
          Card(
            margin: EdgeInsets.symmetric(horizontal: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Подключено к:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          service.connectedServerName!,
                          style: TextStyle(color: Colors.blue),
                        ),
                        if (service.connectedServerIp != null)
                          Text(
                            'IP: ${service.connectedServerIp}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline),
                    onPressed: () {
                      _showConnectionInfo(service);
                    },
                    tooltip: 'Информация о подключении',
                  ),
                ],
              ),
            ),
          ),

        SizedBox(height: 10),

        // Статус передачи
        _buildStatusCard(service),

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
                      text: 'Файлы (${service.selectedFiles.length})',
                    ),
                    Tab(
                      icon: Icon(Icons.history),
                      text: 'Передачи (${service.activeTransfers.length})',
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Вкладка файлов
                      _buildFilesTab(service),

                      // Вкладка передач
                      _buildTransfersTab(service),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

  Widget _buildStatusCard(FileTransferService service) {
    final hasActiveTransfers = service.activeTransfers.isNotEmpty;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              service.isConnected ? Icons.check_circle : Icons.warning,
              color: service.isConnected ? Colors.green : Colors.orange,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.status,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (service.isConnected)
                    Text(
                      'IP: ${service.connectedServerIp ?? "неизвестен"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            if (hasActiveTransfers)
              Chip(
                label: Text(
                  '${service.activeTransfers.length} активных',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: Colors.blue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesTab(FileTransferService service) {
    if (service.selectedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
            SizedBox(height: 20),
            Text(
              'Нет файлов для отправки',
              style: TextStyle(fontSize: 18, color: Colors.grey[500]),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Добавить файлы'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FilePickerScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Панель управления
        // Панель информации
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          color: Theme.of(context).cardColor,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${service.selectedFiles.length} файлов выбрано',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Общий размер: ${_calculateTotalSize(service.selectedFiles)}',
                      style: TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed:
                              service.selectedFiles.isNotEmpty &&
                                  service.isConnected
                              ? _sendFilesToServer
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Отправить все'),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.clear_all),
                          onPressed: service.selectedFiles.isNotEmpty
                              ? () => service.clearFiles()
                              : null,
                          tooltip: 'Очистить все',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Список файлов
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: service.selectedFiles.length,
            itemBuilder: (context, index) {
              final file = service.selectedFiles[index];
              return FileItem(
                file: file,
                onRemove: () => service.removeFile(file.id),
                onOpen: file.status == FileTransferStatus.completed
                    ? () => _openFile(file)
                    : null,
                showProgress: true,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransfersTab(FileTransferService service) {
    if (service.activeTransfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload, size: 80, color: Colors.grey[300]),
            SizedBox(height: 20),
            Text(
              'Нет активных передач',
              style: TextStyle(fontSize: 18, color: Colors.grey[500]),
            ),
            SizedBox(height: 10),
            Text(
              'Начните отправку файлов,\nчтобы увидеть прогресс здесь',
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
          color: Colors.blue[50],
          child: Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.blue),
              SizedBox(width: 10),
              Text(
                'Активные передачи: ${service.activeTransfers.length}',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                  leading: Icon(
                    Icons.file_copy,
                    color: _getFileColor(transfer.file.mimeType),
                  ),
                  title: Text(
                    transfer.file.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: transfer.file.progress / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
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
                  trailing: IconButton(
                    icon: Icon(Icons.cancel, size: 20),
                    onPressed: () {
                      // TODO: Добавить отмену передачи
                    },
                    tooltip: 'Отменить',
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

  void _showConnectionInfo(FileTransferService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Информация о подключении'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              'Статус:',
              service.isConnected ? 'Подключено' : 'Не подключено',
            ),
            if (service.connectedServerIp != null)
              _buildInfoRow('IP сервера:', service.connectedServerIp!),
            if (service.connectedServerName != null)
              _buildInfoRow('Имя сервера:', service.connectedServerName!),
            _buildInfoRow('Статус сервиса:', service.status),
            SizedBox(height: 10),
            Divider(),
            SizedBox(height: 10),
            Text('Статистика:', style: TextStyle(fontWeight: FontWeight.bold)),
            _buildInfoRow('Выбрано файлов:', '${service.selectedFiles.length}'),
            _buildInfoRow(
              'Активных передач:',
              '${service.activeTransfers.length}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
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
    _ipController.dispose();
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
}
