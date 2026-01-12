// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:crypto/crypto.dart';
import 'package:local_websocket/local_websocket.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/core.dart';

class FileTransferService extends ChangeNotifier {
  static const int CHUNK_SIZE = 32 * 1024; // 32KB
  static const int PORT = 8080;
  static const String SERVER_PATH = '/ws';

  // Состояние
  bool _isServerRunning = false;
  String _localIp = '';
  final List<FileInfo> _selectedFiles = [];
  final Map<String, FileTransfer> _activeTransfers = {};
  String _status = 'Готов';

  // WebSocket
  Server? _server;
  Client? _client;
  String? _connectedServerIp; // IP подключенного сервера
  String? _connectedServerName; // Имя подключенного сервера

  // Getters
  bool get isServerRunning => _isServerRunning;
  String get localIp => _localIp;
  String get status => _status;
  String? get connectedServerIp => _connectedServerIp;
  String? get connectedServerName => _connectedServerName;
  bool get isConnected => _client != null && _client!.isConnected;
  List<FileInfo> get selectedFiles => List.from(_selectedFiles);
  Map<String, FileTransfer> get activeTransfers => Map.from(_activeTransfers);

  // Серверные методы
  Future<void> startServer() async {
    try {
      _status = 'Запуск сервера...';
      notifyListeners();

      // Получаем локальный IP
      _localIp = await _getLocalIp();

      print('🔄 Запуск сервера на $_localIp:$PORT');

      // Создаем сервер
      _server = Server(
        echo: false,
        details: {
          'name': await _getDeviceName(),
          'type': 'file-transfer-server',
          'platform': Platform.operatingSystem,
        },
        clientConnectionDelegate: _ServerConnectionHandler(),
      );

      // Запускаем сервер на всех интерфейсах
      await _server!.start('0.0.0.0', port: PORT);

      print('✅ Сервер запущен на порту $PORT');

      // Настраиваем обработчики сообщений
      _setupServerMessageHandler();

      _isServerRunning = true;
      _status = 'Сервер запущен. IP: $_localIp:$PORT';

      notifyListeners();
    } catch (e) {
      _status = 'Ошибка запуска сервера: $e';
      _isServerRunning = false;
      notifyListeners();
      print('❌ Ошибка запуска сервера: $e');
      rethrow;
    }
  }

  Future<void> stopServer() async {
    try {
      await _server?.stop();
      _server = null;
      _isServerRunning = false;
      _status = 'Сервер остановлен';

      notifyListeners();
    } catch (e) {
      _status = 'Ошибка остановки сервера: $e';
      notifyListeners();
    }
  }

  // Клиентские методы
  Future<void> connectToServer(String serverIp, {int port = PORT}) async {
    try {
      _status = 'Подключение к $serverIp:$port...';
      notifyListeners();

      // Отключаемся от предыдущего сервера
      await disconnect();

      print('🔄 Подключение к серверу $serverIp:$port');

      // Создаем клиент
      _client = Client(
        details: {
          'name': await _getDeviceName(),
          'type': 'file-transfer-client',
          'platform': Platform.operatingSystem,
        },
      );

      // Формируем URL для подключения
      final serverUrl = 'ws://$serverIp:$port$SERVER_PATH';
      print('📡 URL подключения: $serverUrl');

      // Подключаемся
      await _client!.connect(serverUrl);

      // Сохраняем информацию о сервере
      _connectedServerIp = serverIp;
      _connectedServerName = 'Сервер $serverIp';

      // Настраиваем обработчики
      _setupClientMessageHandler();

      // Отправляем handshake
      _sendMessage({
        'type': 'handshake',
        'clientInfo': {
          'name': await _getDeviceName(),
          'platform': Platform.operatingSystem,
        },
      });

      _status = 'Подключено к серверу $serverIp';

      notifyListeners();

      print('✅ Успешно подключено к серверу');
    } catch (e) {
      _status = 'Ошибка подключения: $e';
      _client = null;
      _connectedServerIp = null;
      _connectedServerName = null;
      notifyListeners();
      print('❌ Ошибка подключения: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      if (_client != null && _client!.isConnected) {
        await _client!.disconnect();
      }
      _client = null;
      _connectedServerIp = null;
      _connectedServerName = null;
      _status = 'Отключено';
      notifyListeners();
    } catch (e) {
      _status = 'Ошибка отключения: $e';
      notifyListeners();
    }
  }

  // Передача файлов
  Future<void> sendFiles(List<FileInfo> files) async {
    if (_client == null || !_client!.isConnected) {
      throw Exception('Нет подключения к серверу');
    }

    if (_connectedServerIp == null) {
      throw Exception('Не подключено к серверу');
    }

    for (final file in files) {
      final transferId = '${DateTime.now().millisecondsSinceEpoch}_${file.id}';

      final transfer = FileTransfer(
        file: file,
        transferId: transferId,
        onProgress: (progress) {
          file.progress = progress;
          notifyListeners();
        },
        onComplete: () {
          file.status = FileTransferStatus.completed;
          _activeTransfers.remove(transferId);
          notifyListeners();
        },
        onError: (error) {
          file.status = FileTransferStatus.failed;
          _activeTransfers.remove(transferId);
          _status = 'Ошибка: $error';
          notifyListeners();
        },
      );

      _activeTransfers[transferId] = transfer;
      file.status = FileTransferStatus.transferring;
      file.transferId = transferId;
      file.destinationDevice = _connectedServerIp;

      notifyListeners();

      // Запускаем передачу
      await transfer.start(_client!);
    }
  }

  // Вспомогательные методы
  void addFiles(List<FileInfo> files) {
    _selectedFiles.addAll(files);
    notifyListeners();
  }

  void removeFile(String fileId) {
    _selectedFiles.removeWhere((file) => file.id == fileId);
    notifyListeners();
  }

  void clearFiles() {
    _selectedFiles.clear();
    notifyListeners();
  }

  // Приватные методы
  Future<String> _getLocalIp() async {
    try {
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final first = int.parse(parts[0]);
              // Проверяем локальные IP
              if (first == 192 ||
                  first == 10 ||
                  (first == 172 && int.parse(parts[1]) >= 16)) {
                return addr.address;
              }
            }
          }
        }
      }

      // Если не нашли локальный IP
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Ошибка получения IP: $e');
    }

    return '127.0.0.1';
  }

  void _setupServerMessageHandler() {
    if (_server == null) return;

    _server!.messageStream.listen((message) {
      _processIncomingMessage(message);
    });
  }

  void _setupClientMessageHandler() {
    if (_client == null) return;

    _client!.messageStream.listen((message) {
      _processIncomingMessage(message);
    });

    _client!.connectionStream.listen((status) {
      if (!status.isConnected) {
        _status = 'Соединение с сервером разорвано';
        _connectedServerIp = null;
        _connectedServerName = null;
        notifyListeners();
      }
    });
  }

  void _processIncomingMessage(dynamic message) {
    try {
      String jsonString;

      // Преобразуем входящее сообщение в строку
      if (message is String) {
        jsonString = message;
      } else if (message is Uint8List) {
        jsonString = utf8.decode(message);
      } else if (message is List<int>) {
        jsonString = utf8.decode(Uint8List.fromList(message));
      } else {
        print('Неподдерживаемый тип сообщения: ${message.runtimeType}');
        return;
      }

      final data = jsonDecode(jsonString);

      final type = data['type'] as String?;
      if (type == null) return;

      switch (type) {
        case 'handshake':
          _handleHandshake(data);
          break;

        case 'handshake_ack':
          _handleHandshakeAck(data);
          break;

        case 'file_metadata':
          _prepareFileReceival(data);
          break;

        case 'file_chunk':
          _receiveFileChunk(data);
          break;

        case 'transfer_complete':
          _completeFileTransfer(data);
          break;

        case 'chunk_ack':
          _handleChunkAck(data);
          break;

        case 'file_received':
          _handleFileReceived(data);
          break;

        case 'metadata_ack':
          print('Получено подтверждение метаданных: $data');
          break;

        case 'transfer_error':
          print('Ошибка на сервере: $data');
          break;
      }
    } catch (e) {
      print('Ошибка обработки сообщения: $e');
      print('Полученное сообщение: $message');
    }
  }

  Future<void> _handleHandshake(Map<String, dynamic> data) async {
    // Сервер получает handshake от клиента
    if (_isServerRunning && _server != null) {
      final clientInfo = data['clientInfo'];
      print('Клиент подключился: ${clientInfo['name']}');

      // Отправляем подтверждение
      _server!.send(
        jsonEncode({
          'type': 'handshake_ack',
          'message': 'Добро пожаловать',
          'serverInfo': {
            'name': await _getDeviceName(),
            'platform': Platform.operatingSystem,
          },
        }),
      );
    }
  }

  void _handleHandshakeAck(Map<String, dynamic> data) {
    // Клиент получает подтверждение от сервера
    print('Подтверждение от сервера: ${data['message']}');
    _status = 'Подключено: ${data['message']}';

    // Получаем имя сервера
    final serverInfo = data['serverInfo'];
    if (serverInfo != null) {
      _connectedServerName = '${serverInfo['name']} ($_connectedServerIp)';
    }

    notifyListeners();
  }

  void _handleFileReceived(Map<String, dynamic> data) {
    // Клиент получает подтверждение от сервера о получении файла
    final transferId = data['transferId'];
    final fileName = data['fileName'];
    final success = data['success'] ?? false;
    final isTemporary = data['isTemporary'] ?? false;
    final filePath = data['filePath'] as String?;

    if (success) {
      print('✅ Сервер получил файл: $fileName (transferId: $transferId)');

      // Обновляем статус файла на клиенте
      final file = _selectedFiles.firstWhere((f) => f.transferId == transferId);

      file.status = FileTransferStatus.completed;
      file.progress = 100;

      if (isTemporary) {
        print('⚠️ Файл сохранен во временной директории: $filePath');
        file.path = filePath ?? file.path;
      }

      notifyListeners();

      _status = 'Файл "$fileName" доставлен на сервер';
    } else {
      print('❌ Ошибка получения файла на сервере: $fileName');

      // Обновляем статус файла на клиенте
      final file = _selectedFiles.firstWhere((f) => f.transferId == transferId);

      file.status = FileTransferStatus.failed;
      notifyListeners();

      _status = 'Ошибка доставки файла "$fileName"';
    }

    notifyListeners();
  }

  // Прием файлов
  final Map<String, FileReceiver> _fileReceivers = {};

  void _prepareFileReceival(Map<String, dynamic> data) {
    final transferId = data['transferId'];
    final fileName = data['fileName'];
    final fileSize = data['fileSize'];
    final totalChunks = data['totalChunks'];

    print('Начинаем прием файла: $fileName ($fileSize bytes)');

    _fileReceivers[transferId] = FileReceiver(
      fileName: fileName,
      fileSize: fileSize,
      totalChunks: totalChunks,
    );

    // Отправляем подтверждение
    _sendMessage({
      'type': 'metadata_ack',
      'transferId': transferId,
      'status': 'ready',
    });
  }

  void _receiveFileChunk(Map<String, dynamic> data) async {
    final transferId = data['transferId'];
    final chunkIndex = data['chunkIndex'];
    final chunkData = base64Decode(data['data']);
    final isLast = data['isLast'] ?? false;

    final receiver = _fileReceivers[transferId];
    if (receiver != null) {
      await receiver.addChunk(chunkIndex, chunkData);

      // Отправляем подтверждение приема чанка
      _sendMessage({
        'type': 'chunk_ack',
        'transferId': transferId,
        'chunkIndex': chunkIndex,
        'progress': (receiver.receivedChunks / receiver.totalChunks * 100)
            .toInt(),
      });

      if (isLast || receiver.receivedChunks == receiver.totalChunks) {
        print('Получен последний чанк для $transferId');
        await _saveReceivedFile(receiver, transferId);
        _fileReceivers.remove(transferId);
      }
    }
  }

  void _handleChunkAck(Map<String, dynamic> data) {
    // Обработка подтверждения чанка (для отправителя)
    final transferId = data['transferId'];
    final progress = data['progress'];

    final transfer = _activeTransfers[transferId];
    if (transfer != null) {
      print('Чанк подтвержден для $transferId, прогресс: $progress%');
    }
  }

  Future<void> _saveReceivedFile(
    FileReceiver receiver,
    String transferId,
  ) async {
    try {
      print('💾 Начинаю сохранение файла: ${receiver.fileName}');

      // 1. Получаем безопасную директорию (без разрешений)
      final directory = await _getSaveDirectory();
      print('Директория для сохранения: ${directory.path}');

      // 2. Проверяем, что директория существует и доступна для записи
      if (!await directory.exists()) {
        print('Директория не существует, создаю...');
        await directory.create(recursive: true);
      }

      // 3. Создаем безопасное имя файла
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeFileName = _createSafeFileName(receiver.fileName, timestamp);
      final filePath = '${directory.path}/$safeFileName';

      print('Полный путь к файлу: $filePath');

      // 4. Собираем файл из чанков
      print('Собираю файл из ${receiver.totalChunks} чанков...');
      final fileBytes = receiver.assembleFile();
      print('Собран файл размером: ${fileBytes.length} байт');

      // 5. Сохраняем файл
      final file = File(filePath);
      print('Записываю файл на диск...');
      await file.writeAsBytes(fileBytes);

      // 6. Проверяем, что файл сохранен
      final savedSize = await file.length();
      print('Проверка: размер сохраненного файла = $savedSize байт');

      if (savedSize != fileBytes.length) {
        print(
          '⚠️ Внимание: размер не совпадает! Ожидалось: ${fileBytes.length}, получено: $savedSize',
        );
      }

      // 7. Создаем FileInfo
      final fileInfo = FileInfo(
        id: transferId,
        name: receiver.fileName,
        path: filePath,
        size: receiver.fileSize,
        hash: md5.convert(fileBytes).toString(),
        mimeType: lookupMimeType(filePath) ?? 'application/octet-stream',
        modifiedDate: DateTime.now(),
        status: FileTransferStatus.completed,
        progress: 100,
      );

      _selectedFiles.add(fileInfo);

      // 8. Отправляем подтверждение
      _sendMessage({
        'type': 'file_received',
        'transferId': transferId,
        'fileName': receiver.fileName,
        'fileSize': receiver.fileSize,
        'filePath': filePath,
        'success': true,
      });

      print('✅ Файл успешно сохранен: $filePath');
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ КРИТИЧЕСКАЯ ОШИБКА сохранения файла: $e');
      print('Stack trace: $stackTrace');
    }
  }

  String _createSafeFileName(String originalName, int timestamp) {
    // Убираем все небезопасные символы
    var safeName = originalName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    safeName = safeName.replaceAll(RegExp(r'\s+'), '_');

    // Ограничиваем длину имени
    const maxNameLength = 100;
    if (safeName.length > maxNameLength) {
      final extension = safeName.contains('.')
          ? safeName.substring(safeName.lastIndexOf('.'))
          : '';
      final nameWithoutExt = safeName.contains('.')
          ? safeName.substring(0, safeName.lastIndexOf('.'))
          : safeName;

      if (nameWithoutExt.length > maxNameLength - extension.length - 10) {
        safeName =
            '${nameWithoutExt.substring(0, maxNameLength - extension.length - 10)}_$timestamp$extension';
      }
    }

    // Добавляем timestamp для уникальности
    if (!safeName.contains(timestamp.toString())) {
      safeName = '${timestamp}_$safeName';
    }

    return safeName;
  }

  Future<Directory> _getSaveDirectoryViaSAF() async {
    if (Platform.isAndroid) {
      // Пробуем разные директории по порядку
      final directories = [
        // 1. Внешнее хранилище приложения
        await getExternalStorageDirectory(),
        // 2. Downloads директория приложения
        await getDownloadsDirectory(),
        // 3. Documents директория
        await getApplicationDocumentsDirectory(),
        // 4. Temporary директория
        await getTemporaryDirectory(),
      ];

      for (final dir in directories) {
        if (dir != null) {
          try {
            final testDir = Directory('${dir.path}/ReceivedFiles');
            if (!await testDir.exists()) {
              await testDir.create(recursive: true);
            }

            // Проверяем возможность записи
            final testFile = File('${testDir.path}/test.tmp');
            await testFile.writeAsString('test');
            await testFile.delete();

            print('✅ Используем директорию: ${testDir.path}');
            return testDir;
          } catch (e) {
            print('Не могу использовать ${dir.path}: $e');
            continue;
          }
        }
      }

      // Если ничего не сработало, используем временную директорию
      final tempDir = await getTemporaryDirectory();
      return Directory('${tempDir.path}/ReceivedFiles');
    }

    // Для iOS и других платформ
    final appDocDir = await getApplicationDocumentsDirectory();
    return Directory('${appDocDir.path}/ReceivedFiles');
  }

  Future<void> _saveFileAlternative(
    FileReceiver receiver,
    String transferId,
  ) async {
    // Альтернативный способ через MediaStore или временное хранение
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_$transferId');

    final fileBytes = receiver.assembleFile();
    await tempFile.writeAsBytes(fileBytes);

    print('⚠️ Файл сохранен во временную директорию: ${tempFile.path}');

    // Создаем FileInfo с временным путем
    final fileInfo = FileInfo(
      id: transferId,
      name: receiver.fileName,
      path: tempFile.path,
      size: receiver.fileSize,
      hash: md5.convert(fileBytes).toString(),
      mimeType: lookupMimeType(tempFile.path) ?? 'application/octet-stream',
      modifiedDate: DateTime.now(),
      status: FileTransferStatus.completed,
      progress: 100,
    );

    _selectedFiles.add(fileInfo);

    // Отправляем подтверждение с предупреждением
    _sendMessage({
      'type': 'file_received',
      'transferId': transferId,
      'fileName': receiver.fileName,
      'fileSize': receiver.fileSize,
      'filePath': tempFile.path,
      'isTemporary': true,
      'success': true,
    });

    notifyListeners();
  }

  Future<Directory> _getSaveDirectory() async {
    try {
      print('🔍 Получаем директорию для сохранения...');

      // ВАЖНО: НИКОГДА не используем /storage/emulated/0/Download на Android 10+
      // Вместо этого используем внутреннюю директорию приложения

      if (Platform.isAndroid) {
        // На Android используем Application Documents Directory
        // Это приватная директория приложения, не требует разрешений
        final appDocDir = await getApplicationDocumentsDirectory();
        final receivedDir = Directory('${appDocDir.path}/ReceivedFiles');

        print('Android: Application Documents Directory = ${appDocDir.path}');

        // Создаем подпапку по дате для организации
        final now = DateTime.now();
        final dateDir = Directory(
          '${receivedDir.path}/${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        );

        if (!await dateDir.exists()) {
          print('Создаем директорию: ${dateDir.path}');
          await dateDir.create(recursive: true);
        }

        print('✅ Буду сохранять в: ${dateDir.path}');
        return dateDir;
      } else if (Platform.isIOS) {
        // На iOS также используем Application Documents
        final appDocDir = await getApplicationDocumentsDirectory();
        final receivedDir = Directory('${appDocDir.path}/ReceivedFiles');

        print('iOS: Application Documents Directory = ${appDocDir.path}');

        if (!await receivedDir.exists()) {
          print('Создаем директорию: ${receivedDir.path}');
          await receivedDir.create(recursive: true);
        }

        print('✅ Буду сохранять в: ${receivedDir.path}');
        return receivedDir;
      }

      // Для других платформ
      final appDocDir = await getApplicationDocumentsDirectory();
      return Directory('${appDocDir.path}/ReceivedFiles');
    } catch (e) {
      print('❌ Ошибка получения директории: $e');

      // Fallback: временная директория (всегда доступна)
      final tempDir = await getTemporaryDirectory();
      print('⚠️ Использую временную директорию как fallback: ${tempDir.path}');
      return tempDir;
    }
  }
  // Создание безопасного имени файла
  // String _createSafeFileName(String originalName) {
  //   // Убираем небезопасные символы из имени файла
  //   final safeName = originalName.replaceAll(RegExp(r'[^\w\.\-]'), '_');

  //   // Добавляем timestamp для уникальности
  //   final timestamp = DateTime.now().millisecondsSinceEpoch;

  //   // Если имя слишком длинное, обрезаем его
  //   if (safeName.length > 100) {
  //     final extension = safeName.split('.').last;
  //     final nameWithoutExt = safeName.substring(
  //       0,
  //       safeName.length - extension.length - 1,
  //     );
  //     final shortenedName =
  //         '${nameWithoutExt.substring(0, 50)}_$timestamp.$extension';
  //     return shortenedName;
  //   }

  //   return '${timestamp}_$safeName';
  // }

  void _completeFileTransfer(Map<String, dynamic> data) {
    final transferId = data['transferId'];
    final fileName = data['fileName'];

    print('Передача завершена: $fileName ($transferId)');

    // Удаляем из активных передач
    _activeTransfers.remove(transferId);

    // На КЛИЕНТЕ очищаем transferId у файла
    if (!_isServerRunning) {
      final file = _selectedFiles.firstWhere((f) => f.transferId == transferId);

      // Очищаем transferId, чтобы файл остался в списке
      file.transferId = null;
    }

    notifyListeners();
  }

  void _sendMessage(Map<String, dynamic> message) {
    try {
      final jsonMessage = jsonEncode(message);

      if (_isServerRunning && _server != null) {
        _server!.send(jsonMessage);
      } else if (_client != null && _client!.isConnected) {
        _client!.send(jsonMessage);
      }
    } catch (e) {
      print('Ошибка отправки сообщения: $e');
    }
  }

  Future<String> _getDeviceName() async {
    if (Platform.isAndroid) {
      return 'Android Устройство';
    } else if (Platform.isIOS) {
      return 'iPhone';
    }
    return 'Устройство';
  }

  @override
  void dispose() {
    stopServer();
    disconnect();
    super.dispose();
  }
}

// Обработчик подключений для сервера
class _ServerConnectionHandler implements ClientConnectionDelegate {
  _ServerConnectionHandler();

  @override
  Future<void> onClientConnected(Client client) async {
    print('✅ Клиент подключился: ${client.details}');
  }

  @override
  Future<void> onClientDisconnected(Client client) async {
    print('❌ Клиент отключился');
  }
}

class FileTransfer {
  final FileInfo file;
  final String transferId;
  final Function(double) onProgress;
  final Function() onComplete;
  final Function(String) onError;

  FileTransfer({
    required this.file,
    required this.transferId,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  });

  Future<void> start(Client client) async {
    try {
      print('Начинаем передачу файла: ${file.name}');

      final fileData = await File(file.path).readAsBytes();
      final totalChunks = (fileData.length / FileTransferService.CHUNK_SIZE)
          .ceil();

      print('Размер файла: ${fileData.length} bytes, чанков: $totalChunks');

      // Отправляем метаданные - ВАЖНО: преобразуем Map в JSON строку
      client.send(
        jsonEncode({
          'type': 'file_metadata',
          'transferId': transferId,
          'fileName': file.name,
          'fileSize': fileData.length,
          'totalChunks': totalChunks,
          'mimeType': file.mimeType,
          'hash': file.hash,
        }),
      );

      await Future.delayed(Duration(milliseconds: 100));

      // Отправляем чанки
      for (var i = 0; i < totalChunks; i++) {
        final start = i * FileTransferService.CHUNK_SIZE;
        final end = start + FileTransferService.CHUNK_SIZE < fileData.length
            ? start + FileTransferService.CHUNK_SIZE
            : fileData.length;

        final chunk = fileData.sublist(start, end);

        // Отправляем чанк - ВАЖНО: преобразуем Map в JSON строку
        client.send(
          jsonEncode({
            'type': 'file_chunk',
            'transferId': transferId,
            'chunkIndex': i,
            'data': base64Encode(chunk),
            'isLast': i == totalChunks - 1,
          }),
        );

        final progress = ((i + 1) / totalChunks * 100);
        onProgress(progress);

        // Небольшая задержка для стабильности
        await Future.delayed(Duration(milliseconds: 10));
      }

      // Завершение передачи - ВАЖНО: преобразуем Map в JSON строку
      client.send(
        jsonEncode({
          'type': 'transfer_complete',
          'transferId': transferId,
          'fileName': file.name,
          'fileSize': fileData.length,
        }),
      );

      print('Передача завершена: ${file.name}');
      onComplete();
    } catch (e) {
      print('Ошибка передачи файла ${file.name}: $e');
      onError(e.toString());
    }
  }
}

class FileReceiver {
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final List<Uint8List?> chunks;
  int receivedChunks = 0;

  FileReceiver({
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
  }) : chunks = List.filled(totalChunks, null);

  Future<void> addChunk(int index, Uint8List data) async {
    if (index < totalChunks) {
      chunks[index] = data;
      receivedChunks++;
    }
  }

  Uint8List assembleFile() {
    final buffer = BytesBuilder();
    for (final chunk in chunks) {
      if (chunk != null) {
        buffer.add(chunk);
      }
    }
    return buffer.toBytes();
  }
}
