// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';

import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

class FileTransferService extends ChangeNotifier {
  static const int CHUNK_SIZE = 32 * 1024; // 32KB
  static const int PORT = 8080;

  // Состояние
  bool _isServerRunning = false;
  String _localIp = '';
  final Map<String, FileTransfer> _activeTransfers = {};
  String _status = 'Готов';

  // WebSocket сервер
  HttpServer? _httpServer;
  final List<WebSocket> _connectedClients = [];

  // WebSocket клиент
  WebSocketChannel? _clientChannel;
  String? _connectedServerIp;
  String? _connectedServerName;

  final Map<String, FileReceiver> _fileReceivers = {};
  final String _receivedFilesDir = 'ReceivedFiles';
  Directory? _appDocumentsDirectory;
  bool _hasStoragePermission = false;

  bool _isProgressListenerActive = false;
  StreamSubscription? _ffmpegLogSubscription;

  // Getters
  bool get isServerRunning => _isServerRunning;
  String get localIp => _localIp;
  String get status => _status;
  String? get connectedServerIp => _connectedServerIp;
  String? get connectedServerName => _connectedServerName;
  bool get isConnected => _clientChannel != null;
  Map<String, FileTransfer> get activeTransfers => Map.from(_activeTransfers);
  List<ReceivedMedia> get receivedMedia => _receivedMedia;

  // Список полученных медиафайлов
  final List<ReceivedMedia> _receivedMedia = [];

  FileTransferService() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkPermissions();
    await _initializeDirectories();
    _loadReceivedMedia();
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid || Platform.isIOS) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      _hasStoragePermission = status.isGranted;

      if (Platform.isAndroid) {
        final mediaStatus = await Permission.accessMediaLocation.status;
        if (!mediaStatus.isGranted) {
          await Permission.accessMediaLocation.request();
        }
      }
    }
  }

  Future<void> _initializeDirectories() async {
    _appDocumentsDirectory = await getApplicationDocumentsDirectory();
    final receivedDir = Directory(
      path.join(_appDocumentsDirectory!.path, _receivedFilesDir),
    );
    if (!await receivedDir.exists()) {
      await receivedDir.create(recursive: true);
    }
  }

  Future<void> _loadReceivedMedia() async {
    try {
      final mediaDir = Directory(
        path.join(_appDocumentsDirectory!.path, _receivedFilesDir),
      );

      if (await mediaDir.exists()) {
        final files = await mediaDir.list().toList();
        _receivedMedia.clear();

        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            final mimeType =
                lookupMimeType(file.path) ?? 'application/octet-stream';

            if (mimeType.startsWith('image/') ||
                mimeType.startsWith('video/')) {
              _receivedMedia.add(
                ReceivedMedia(
                  file: file,
                  fileName: path.basename(file.path),
                  fileSize: stat.size,
                  mimeType: mimeType,
                  receivedAt: stat.modified,
                ),
              );
            }
          }
        }

        _receivedMedia.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
        notifyListeners();
      }
    } catch (e) {
      print('❌ Ошибка загрузки списка медиа: $e');
    }
  }

  // =========== СЕРВЕРНЫЕ МЕТОДЫ ===========

  Future<void> startServer() async {
    try {
      print('🚀 ЗАПУСК НАТИВНОГО WEB SOCKET СЕРВЕРА');

      _status = 'Запуск сервера...';
      notifyListeners();

      _localIp = await _getLocalIp();
      print('📱 IP адрес сервера: $_localIp');

      bool serverStarted = false;

      for (var port in [PORT, 8081, 8082, 8083, 8084]) {
        try {
          print('🔄 Пробую запустить на порту $port...');

          _httpServer = await HttpServer.bind(
            InternetAddress.anyIPv4,
            port,
            shared: true,
          );

          print('✅ HTTP сервер запущен на порту $port');

          _httpServer!.listen(_handleWebSocket);

          serverStarted = true;

          _isServerRunning = true;
          _status = 'Сервер запущен ✅\nIP: $_localIp\nПорт: $port';

          print('🎉 WEB SOCKET СЕРВЕР ЗАПУЩЕН!');
          print('   Подключитесь: ws://$_localIp:$port');

          notifyListeners();
          break;
        } catch (e) {
          print('❌ Порт $port занят: $e');

          if (_httpServer != null) {
            await _httpServer!.close();
            _httpServer = null;
          }

          await Future.delayed(Duration(milliseconds: 100));
        }
      }

      if (!serverStarted) {
        throw Exception('Не удалось запустить сервер ни на одном порту');
      }
    } catch (e, stackTrace) {
      print('💥 ОШИБКА ЗАПУСКА СЕРВЕРА: $e');
      print('Stack: $stackTrace');

      _status = 'Ошибка: $e';
      _isServerRunning = false;
      notifyListeners();
    }
  }

  void _handleWebSocket(HttpRequest request) async {
    try {
      print('🔗 Входящее подключение: ${request.uri}');

      if (request.uri.path == '/ws') {
        final webSocket = await WebSocketTransformer.upgrade(request);
        print('✅ WebSocket клиент подключен');

        _connectedClients.add(webSocket);

        final clientName =
            request.headers.value('client-name') ?? 'Неизвестный';
        print('👤 Клиент: $clientName');

        webSocket.listen(
          (message) => _handleServerMessage(webSocket, message),
          onDone: () {
            print('❌ Клиент отключился');
            _connectedClients.remove(webSocket);
            _cleanupDisconnectedClient(webSocket);
          },
          onError: (error) {
            print('⚠️ Ошибка от клиента: $error');
            _connectedClients.remove(webSocket);
            _cleanupDisconnectedClient(webSocket);
          },
        );
      } else {
        request.response.statusCode = 404;
        request.response.write('WebSocket endpoint: /ws');
        await request.response.close();
      }
    } catch (e) {
      print('❌ Ошибка обработки подключения: $e');
    }
  }

  void _cleanupDisconnectedClient(WebSocket socket) {
    // Удаляем все приемники файлов для этого клиента
    final receiversToRemove = <String>[];
    _fileReceivers.forEach((key, receiver) {
      // Здесь можно добавить логику для определения, какой приемник связан с каким сокетом
      // В текущей реализации все приемники могут быть связаны с любым сокетом
      // Но если нужно, можно добавить поле socket в FileReceiver
    });

    for (final key in receiversToRemove) {
      _fileReceivers.remove(key);
      _activeTransfers.remove(key);
    }
  }

  void _handleServerMessage(WebSocket socket, dynamic message) {
    try {
      final data = jsonDecode(message.toString());
      final type = data['type'] as String?;

      if (type == null) return;

      switch (type) {
        case 'handshake':
          _handleClientHandshake(socket, data);
          break;
        case 'file_metadata':
          _handleFileMetadata(socket, data);
          break;
        case 'file_chunk':
          _handleFileChunk(socket, data);
          break;
        case 'progress_update': // ДОБАВЛЯЕМ ОБРАБОТКУ ПРОГРЕССА
          _handleProgressUpdate(socket, data);
          break;
      }
    } catch (e) {
      print('❌ Ошибка обработки сообщения сервером: $e');
    }
  }

  void _handleProgressUpdate(WebSocket socket, Map<String, dynamic> data) {
    try {
      final transferId = data['transferId'] as String?;
      final progress = data['progress'] as double?;
      final receivedBytes = data['receivedBytes'] as int?;
      final totalBytes = data['totalBytes'] as int?;

      if (transferId != null &&
          progress != null &&
          receivedBytes != null &&
          totalBytes != null) {
        print(
          '📈 Прогресс от клиента: $transferId - ${progress.toStringAsFixed(1)}% '
          '(${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)})',
        );

        // Проверяем корректность данных
        if (progress > 100.0) {
          print('⚠️ ВНИМАНИЕ: Прогресс превышает 100%: $progress%');
        }
        if (receivedBytes > totalBytes) {
          print(
            '⚠️ ВНИМАНИЕ: Получено байт больше общего размера: '
            '${_formatBytes(receivedBytes)} > ${_formatBytes(totalBytes)}',
          );
        }

        // ОГРАНИЧИВАЕМ ПРОГРЕСС НА СЕРВЕРЕ
        final clampedProgress = progress.clamp(0.0, 100.0);
        final clampedReceivedBytes = receivedBytes.clamp(0, totalBytes);

        // Находим соответствующую передачу на сервере
        FileTransfer? serverTransfer;

        // Прямой поиск
        if (_activeTransfers.containsKey(transferId)) {
          serverTransfer = _activeTransfers[transferId];
        }
        // Поиск групповой передачи
        else {
          // Проверяем все передачи для отладки
          for (final key in _activeTransfers.keys) {
            print('   Доступная передача: $key');
          }

          // Попробуем найти по частичному совпадению
          for (final key in _activeTransfers.keys) {
            if (transferId.contains(key) || key.contains(transferId)) {
              serverTransfer = _activeTransfers[key];
              print('🔍 Найдена передача по частичному совпадению: $key');
              break;
            }
          }
        }

        if (serverTransfer != null) {
          // Обновляем прогресс на сервере
          serverTransfer.receivedBytes = clampedReceivedBytes;
          serverTransfer.fileSize = totalBytes;

          // Обновляем UI
          notifyListeners();

          print(
            '✅ Обновлен прогресс на сервере: ${serverTransfer.fileName} - '
            '${serverTransfer.progress.toStringAsFixed(1)}% '
            '(получено: ${clampedProgress.toStringAsFixed(1)}%)',
          );
        } else {
          print('⚠️ Передача не найдена для прогресса: $transferId');
          print('   Создаем временную передачу для отображения прогресса...');

          // Создаем временную передачу для отображения прогресса
          final tempTransfer = FileTransfer(
            transferId: transferId,
            fileName: transferId.startsWith('photos_') ? 'Фотографии' : 'Видео',
            fileSize: totalBytes,
            fileType: transferId.startsWith('photos_')
                ? 'image/mixed'
                : 'video/mixed',
            file: File(''),
            targetPath: '',
            onProgress: (progress) {
              notifyListeners();
            },
            onComplete: (file) {},
            onError: (error) {},
            sendMessage: (message) {},
            totalFiles: 1,
            completedFiles: 0,
          );

          tempTransfer.receivedBytes = clampedReceivedBytes;
          _activeTransfers[transferId] = tempTransfer;
          notifyListeners();
        }
      }
    } catch (e) {
      print('❌ Ошибка обработки прогресса: $e');
    }
  }

  // Вспомогательный метод для форматирования байт
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

  Future<void> _handleClientHandshake(
    WebSocket socket,
    Map<String, dynamic> data,
  ) async {
    print('🤝 Handshake от клиента: ${data['clientInfo']}');

    socket.add(
      jsonEncode({
        'type': 'handshake_ack',
        'message': 'Добро пожаловать',
        'serverInfo': {
          'name': await _getDeviceName(),
          'platform': Platform.operatingSystem,
          'ip': _localIp,
        },
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<void> stopServer() async {
    try {
      print('🛑 Останавливаю сервер...');

      // Закрываем все активные файловые потоки
      for (final receiver in _fileReceivers.values) {
        await receiver.close();
      }
      _fileReceivers.clear();

      for (final client in _connectedClients) {
        try {
          await client.close();
        } catch (e) {
          print('⚠️ Ошибка закрытия клиента: $e');
        }
      }
      _connectedClients.clear();

      if (_httpServer != null) {
        await _httpServer!.close();
        _httpServer = null;
      }

      _isServerRunning = false;
      _status = 'Сервер остановлен';

      print('✅ Сервер остановлен');
      notifyListeners();
    } catch (e) {
      print('❌ Ошибка остановки сервера: $e');
    }
  }

  // =========== КЛИЕНТСКИЕ МЕТОДЫ ===========

  Future<void> connectToServer(String serverIp, {int port = PORT}) async {
    try {
      print('📱 ПОДКЛЮЧЕНИЕ К СЕРВЕРУ: $serverIp:$port');

      await disconnect();

      _status = 'Подключение...';
      notifyListeners();

      final uri = Uri.parse('ws://$serverIp:$port/ws');
      final channel = IOWebSocketChannel.connect(
        uri,
        connectTimeout: Duration(seconds: 10),
      );

      _clientChannel = channel;

      channel.stream.listen(
        (message) => _handleClientMessage(message),
        onDone: () {
          print('❌ Соединение с сервером разорвано');
          _status = 'Отключено от сервера';
          _clientChannel = null;
          _connectedServerIp = null;
          notifyListeners();
        },
        onError: (error) {
          print('⚠️ Ошибка соединения: $error');
          _status = 'Ошибка: $error';
          notifyListeners();
        },
      );

      _sendClientMessage({
        'type': 'handshake',
        'clientInfo': {
          'name': await _getDeviceName(),
          'platform': Platform.operatingSystem,
          'version': '1.0.0',
        },
        'timestamp': DateTime.now().toIso8601String(),
      });

      _connectedServerIp = serverIp;
      _connectedServerName = 'Сервер $serverIp';

      await Future.delayed(Duration(seconds: 1));

      _status = 'Подключено к серверу';
      print('🎉 УСПЕШНО ПОДКЛЮЧЕНО!');
      notifyListeners();
    } catch (e) {
      print('💥 ОШИБКА ПОДКЛЮЧЕНИЯ: $e');

      _status = 'Ошибка: ${e.toString().split('\n').first}';
      _clientChannel = null;
      _connectedServerIp = null;

      notifyListeners();

      if (port == PORT) {
        print('🔄 Пробую порт 8081...');
        await Future.delayed(Duration(seconds: 1));
        await connectToServer(serverIp, port: 8080);
      }
    }
  }

  void _handleClientMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());
      final type = data['type'] as String?;

      if (type == null) return;

      switch (type) {
        case 'handshake_ack':
          final serverInfo = data['serverInfo'];
          if (serverInfo != null) {
            _connectedServerName =
                '${serverInfo['name']} (${serverInfo['ip']})';
            notifyListeners();
          }
          break;
        case 'metadata_ack':
          print('✅ Сервер готов принимать файл');
          break;
        case 'chunk_ack':
          _handleChunkAck(data);
          break;
        case 'file_received':
          _handleFileReceived(data);
          break;
        case 'progress_update': // ДОБАВЛЯЕМ ОБРАБОТКУ ПРОГРЕССА
          _handleProgressFromServer(data);
          break;
      }
    } catch (e) {
      print('❌ Ошибка обработки сообщения клиентом: $e');
    }
  }

  void _handleProgressFromServer(Map<String, dynamic> data) {
    final transferId = data['transferId'] as String?;
    final progress = data['progress'] as double?;
    final receivedBytes = data['receivedBytes'] as int?;
    final totalBytes = data['totalBytes'] as int?;

    if (transferId != null &&
        progress != null &&
        receivedBytes != null &&
        totalBytes != null) {
      print(
        '📈 Прогресс от сервера: $transferId - ${progress.toStringAsFixed(1)}%',
      );

      // Находим соответствующую передачу на клиенте
      final transfer = _activeTransfers[transferId];
      if (transfer != null) {
        transfer.receivedBytes = receivedBytes;
        transfer.fileSize = totalBytes;
        transfer.onProgress(progress);
        notifyListeners();
      }
    }
  }

  void _sendClientMessage(Map<String, dynamic> message) {
    try {
      if (_clientChannel != null) {
        _clientChannel!.sink.add(jsonEncode(message));
      }
    } catch (e) {
      print('❌ Ошибка отправки сообщения: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      if (_clientChannel != null) {
        await _clientChannel!.sink.close();
        _clientChannel = null;
      }

      _connectedServerIp = null;
      _connectedServerName = null;
      _status = 'Отключено';

      notifyListeners();
    } catch (e) {
      print('❌ Ошибка отключения: $e');
    }
  }

  // =========== ПЕРЕДАЧА ФАЙЛОВ (КЛИЕНТ) ===========

  Future<void> sendFiles(List<File> files) async {
    if (_clientChannel == null) {
      throw Exception('Нет подключения к сервера');
    }

    // Очищаем старые передачи перед началом новых
    _activeTransfers.clear();
    notifyListeners();

    // Создаем отдельные передачи для фото и видео
    final photoFiles = files.where((file) {
      final mimeType = lookupMimeType(file.path) ?? '';
      return mimeType.startsWith('image/');
    }).toList();

    final videoFiles = files.where((file) {
      final mimeType = lookupMimeType(file.path) ?? '';
      return mimeType.startsWith('video/');
    }).toList();

    // Создаем передачи для фото
    String? photoTransferId;
    if (photoFiles.isNotEmpty) {
      photoTransferId = 'photos_${DateTime.now().millisecondsSinceEpoch}';

      // Рассчитываем общий размер фото
      int totalPhotoSize = 0;
      for (final file in photoFiles) {
        totalPhotoSize += await file.length();
      }

      _activeTransfers[photoTransferId] = FileTransfer(
        transferId: photoTransferId,
        fileName: '${photoFiles.length} фото',
        fileSize: totalPhotoSize,
        fileType: 'image/mixed',
        file: photoFiles.first,
        targetPath: '',
        onProgress: (progress) {
          notifyListeners();
        },
        onComplete: (file) {
          print('✅ Все фото отправлены');
          Future.delayed(Duration(seconds: 3), () {
            _activeTransfers.remove(photoTransferId);
            notifyListeners();
          });
        },
        onError: (error) {
          print('❌ Ошибка отправки фото: $error');
          _activeTransfers.remove(photoTransferId);
          notifyListeners();
        },
        sendMessage: (message) {
          _sendClientMessage(message);
        },
        // ДОБАВЛЯЕМ totalFiles и completedFiles
        totalFiles: photoFiles.length,
        completedFiles: 0,
      );

      print(
        '📸 Создана групповая передача фото: ${photoFiles.length} файлов, '
        'общий размер: ${(totalPhotoSize / (1024 * 1024)).toStringAsFixed(2)} MB',
      );
    }

    // Создаем передачи для видео
    String? videoTransferId;
    if (videoFiles.isNotEmpty) {
      videoTransferId = 'videos_${DateTime.now().millisecondsSinceEpoch}';

      // Рассчитываем общий размер видео
      int totalVideoSize = 0;
      for (final file in videoFiles) {
        totalVideoSize += await file.length();
      }

      _activeTransfers[videoTransferId] = FileTransfer(
        transferId: videoTransferId,
        fileName: '${videoFiles.length} видео',
        fileSize: totalVideoSize,
        fileType: 'video/mixed',
        file: videoFiles.first,
        targetPath: '',
        onProgress: (progress) {
          notifyListeners();
        },
        onComplete: (file) {
          print('✅ Все видео отправлены');
          Future.delayed(Duration(seconds: 3), () {
            _activeTransfers.remove(videoTransferId);
            notifyListeners();
          });
        },
        onError: (error) {
          print('❌ Ошибка отправки видео: $error');
          _activeTransfers.remove(videoTransferId);
          notifyListeners();
        },
        sendMessage: (message) {
          _sendClientMessage(message);
        },
        // ДОБАВЛЯЕМ totalFiles и completedFiles
        totalFiles: videoFiles.length,
        completedFiles: 0,
      );

      print(
        '🎥 Создана групповая передача видео: ${videoFiles.length} файлов, '
        'общий размер: ${(totalVideoSize / (1024 * 1024)).toStringAsFixed(2)} MB',
      );
    }

    notifyListeners();

    // Отправляем файлы группами
    if (photoFiles.isNotEmpty) {
      print('🚀 Начинаю отправку ${photoFiles.length} фото...');
      await _sendFileGroup(photoFiles, photoTransferId!, isVideoGroup: false);
    }

    if (videoFiles.isNotEmpty) {
      print('🚀 Начинаю отправку ${videoFiles.length} видео...');
      await _sendFileGroup(videoFiles, videoTransferId!, isVideoGroup: true);
    }

    print('🎯 Все групповые передачи запущены');
  }

  Future<void> _sendFileGroup(
    List<File> files,
    String groupTransferId, {
    required bool isVideoGroup,
  }) async {
    final transfer = _activeTransfers[groupTransferId];
    if (transfer == null) {
      print('⚠️ Групповая передача $groupTransferId не найдена');
      return;
    }

    int totalBytesSent = 0;
    final int totalGroupSize = transfer.fileSize;

    print(
      '📊 Начинаю отправку группы: ${files.length} файлов, '
      'общий размер: ${(totalGroupSize / (1024 * 1024)).toStringAsFixed(2)} MB',
    );

    // Начальный прогресс
    transfer.receivedBytes = 0;
    transfer.onProgress(0.0);
    // ОТПРАВЛЯЕМ НАЧАЛЬНЫЙ ПРОГРЕСС НА СЕРВЕР СРАЗУ
    _sendProgressUpdate(groupTransferId, 0.0, 0, totalGroupSize);

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = path.basename(file.path);
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final fileSize = await file.length();

      File fileToSend = file;
      String fileType = mimeType;

      print(
        '📦 ${isVideoGroup ? 'Видео' : 'Фото'} ${i + 1}/${files.length}: $fileName '
        '(${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB)',
      );

      // Точная доля этого файла в общей группе
      final fileShare = fileSize.toDouble() / totalGroupSize.toDouble();

      // Прогресс до начала этого файла (в процентах)
      final progressBeforeThisFile =
          (totalBytesSent.toDouble() / totalGroupSize.toDouble()) * 100.0;

      // Для видео: конвертация (40%) + передача (60%)
      // Для фото: только передача (100%)
      final conversionWeight = isVideoGroup ? 40.0 : 0.0;
      final transferWeight = isVideoGroup ? 60.0 : 100.0;

      if (isVideoGroup && mimeType.startsWith('video/') && _isMovFile(file)) {
        print('🎬 Конвертация .mov в .mp4...');

        // Прогресс на начало конвертации этого файла
        transfer.onProgress(progressBeforeThisFile);
        // ОТПРАВЛЯЕМ ПРОГРЕСС КОНВЕРТАЦИИ НА СЕРВЕР
        _sendProgressUpdate(
          groupTransferId,
          progressBeforeThisFile,
          totalBytesSent,
          totalGroupSize,
        );

        final convertedFile = await _convertMovToMp4(file, (
          conversionProgress,
        ) {
          // conversionProgress от 0 до 100

          // Доля конвертации в общем прогрессе (от 0 до fileShare * 0.4)
          final conversionShareInGroup =
              (conversionProgress / 100.0) *
              conversionWeight *
              fileShare /
              100.0;

          // Общий прогресс группы = прогресс до этого файла + прогресс конвертации
          final groupProgress =
              progressBeforeThisFile + (conversionShareInGroup * 100.0);

          // ОГРАНИЧИВАЕМ ПРОГРЕСС, ЧТОБЫ НЕ ПРЕВЫШАЛ 100%
          final clampedProgress = groupProgress.clamp(0.0, 100.0);

          transfer.receivedBytes = (clampedProgress / 100.0 * totalGroupSize)
              .toInt();
          transfer.onProgress(clampedProgress);
          // ОТПРАВЛЯЕМ ПРОГРЕСС КОНВЕРТАЦИИ НА СЕРВЕР
          _sendProgressUpdate(
            groupTransferId,
            clampedProgress,
            transfer.receivedBytes,
            totalGroupSize,
          );

          print(
            '🔄 Прогресс видео ${i + 1}: конвертация ${conversionProgress.toStringAsFixed(1)}%, '
            'общий прогресс: ${clampedProgress.toStringAsFixed(1)}%',
          );
        });

        if (convertedFile != null) {
          fileToSend = convertedFile;
          fileType = 'video/mp4';
        }
      } else if (isVideoGroup) {
        // Для видео без конвертации сразу отправляем прогресс начала файла
        _sendProgressUpdate(
          groupTransferId,
          progressBeforeThisFile,
          totalBytesSent,
          totalGroupSize,
        );
      }

      // После конвертации (или сразу для фото) устанавливаем прогресс на начало передачи
      final progressBeforeTransfer =
          progressBeforeThisFile + (conversionWeight * fileShare);
      final clampedProgressBeforeTransfer = progressBeforeTransfer.clamp(
        0.0,
        100.0,
      );

      transfer.receivedBytes =
          (clampedProgressBeforeTransfer / 100.0 * totalGroupSize).toInt();
      transfer.onProgress(clampedProgressBeforeTransfer);
      // ОТПРАВЛЯЕМ ПРОГРЕСС НАЧАЛА ПЕРЕДАЧИ НА СЕРВЕР
      _sendProgressUpdate(
        groupTransferId,
        clampedProgressBeforeTransfer,
        transfer.receivedBytes,
        totalGroupSize,
      );

      // Отправка текущего файла
      print(
        '📤 Отправка ${isVideoGroup ? 'видео' : 'фото'} ${i + 1}/${files.length}',
      );

      final fileTransferId = '${groupTransferId}_$i';
      final currentFileSize = await fileToSend.length();

      final metadata = {
        'type': 'file_metadata',
        'transferId': fileTransferId,
        'fileName': fileName,
        'fileSize': currentFileSize,
        'fileType': fileType,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _sendClientMessage(metadata);
      await Future.delayed(Duration(milliseconds: 300));

      final stream = fileToSend.openRead();
      var chunkIndex = 0;
      var fileSentBytes = 0;

      await for (final chunk in stream) {
        final chunkMessage = {
          'type': 'file_chunk',
          'transferId': fileTransferId,
          'chunkIndex': chunkIndex,
          'chunkData': base64Encode(chunk),
          'isLast': false,
          'timestamp': DateTime.now().toIso8601String(),
        };

        _sendClientMessage(chunkMessage);
        fileSentBytes += chunk.length;
        chunkIndex++;

        // Рассчитываем прогресс передачи для этого файла (0-1)
        final fileTransferProgress =
            fileSentBytes.toDouble() / currentFileSize.toDouble();

        // Доля передачи в общем прогрессе группы
        final transferShareInGroup =
            fileTransferProgress * transferWeight * fileShare / 100.0;

        // Общий прогресс группы = прогресс до передачи этого файла + прогресс передачи
        final groupProgress =
            progressBeforeTransfer + (transferShareInGroup * 100.0);

        // ОГРАНИЧИВАЕМ ПРОГРЕСС
        final clampedGroupProgress = groupProgress.clamp(0.0, 100.0);

        transfer.receivedBytes = (clampedGroupProgress / 100.0 * totalGroupSize)
            .toInt();
        transfer.onProgress(clampedGroupProgress);

        // ОТПРАВЛЯЕМ ПРОГРЕСС НА СЕРВЕР КАЖДЫЕ 5% ИЛИ ПРИ ЗНАЧИТЕЛЬНЫХ ИЗМЕНЕНИЯХ
        // if (chunkIndex % 5 == 0 || fileSentBytes == currentFileSize) {
        if (chunkIndex % 20 == 0 || fileSentBytes == currentFileSize) {
          _sendProgressUpdate(
            groupTransferId,
            clampedGroupProgress,
            transfer.receivedBytes,
            totalGroupSize,
          );
        }

        await Future.delayed(Duration(milliseconds: 10));
      }

      // Финальное сообщение для файла
      final finalMessage = {
        'type': 'file_chunk',
        'transferId': fileTransferId,
        'chunkIndex': chunkIndex,
        'chunkData': '',
        'isLast': true,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _sendClientMessage(finalMessage);

      // Обновляем общий счетчик отправленных байт
      totalBytesSent += fileSize;

      // Устанавливаем ТОЧНЫЙ прогресс после завершения файла
      // Для видео: конвертация (40%) + передача (60%) = 100% от доли файла
      // Для фото: передача (100%) = 100% от доли файла
      final exactGroupProgress =
          (totalBytesSent.toDouble() / totalGroupSize.toDouble()) * 100.0;
      // ОГРАНИЧИВАЕМ 100%
      final clampedExactProgress = exactGroupProgress.clamp(0.0, 100.0);

      transfer.receivedBytes = (clampedExactProgress / 100.0 * totalGroupSize)
          .toInt();
      transfer.onProgress(clampedExactProgress);
      // ОТПРАВЛЯЕМ ФИНАЛЬНЫЙ ПРОГРЕСС ДЛЯ ЭТОГО ФАЙЛА
      _sendProgressUpdate(
        groupTransferId,
        clampedExactProgress,
        transfer.receivedBytes,
        totalGroupSize,
      );

      // УВЕЛИЧИВАЕМ СЧЕТЧИК ЗАВЕРШЕННЫХ ФАЙЛОВ
      transfer.completedFiles++;

      print(
        '✅ ${isVideoGroup ? 'Видео' : 'Фото'} ${i + 1}/${files.length} отправлено '
        '(${transfer.completedFiles}/${transfer.totalFiles} файлов, '
        '${clampedExactProgress.toStringAsFixed(1)}%)',
      );

      // Удаляем временный конвертированный файл
      if (fileToSend.path != file.path && await fileToSend.exists()) {
        try {
          await fileToSend.delete();
          print('🗑️ Удален временный конвертированный файл');
        } catch (e) {
          print('⚠️ Не удалось удалить временный файл: $e');
        }
      }
    }

    // Завершаем прогресс группы - ТОЧНО 100%
    transfer.receivedBytes = totalGroupSize;
    transfer.onProgress(100.0);
    _sendProgressUpdate(groupTransferId, 100.0, totalGroupSize, totalGroupSize);
    transfer.onComplete(files.first);

    print(
      '🎉 Все ${files.length} ${isVideoGroup ? 'видео' : 'фото'} отправлены! '
      '(100%, ${transfer.completedFiles}/${transfer.totalFiles} файлов)',
    );
  }

  // В класс FileTransferService добавьте метод
  void _sendProgressUpdate(
    String transferId,
    double progress,
    int receivedBytes,
    int totalBytes,
  ) {
    try {
      final progressMessage = {
        'type': 'progress_update',
        'transferId': transferId,
        'progress': progress,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _sendClientMessage(progressMessage);
    } catch (e) {
      print('❌ Ошибка отправки прогресса: $e');
    }
  }

  // Проверяем, является ли файл .mov
  bool _isMovFile(File file) {
    final fileName = path.basename(file.path).toLowerCase();
    return fileName.endsWith('.mov') || fileName.endsWith('.quicktime');
  }

  Future<File?> _convertMovToMp4(File file, Function(double) onProgress) async {
    try {
      print('🎬 Конвертация HEVC (iPhone) в H.264 (Android)...');

      if (!await file.exists()) {
        print('❌ Файл не найден');
        onProgress(100.0);
        return null;
      }

      final fileSize = await file.length();
      print('📊 Размер: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Получаем информацию о видео (длительность)
      final duration = await _getVideoDuration(file);
      if (duration == null) {
        print('⚠️ Не удалось получить длительность видео');
        onProgress(100.0);
        return null;
      }

      print('⏱️ Длительность видео: ${duration} секунд');
      onProgress(0.0); // Начинаем с 0%

      // Создаем временный файл
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = path.join(
        tempDir.path,
        'android_compatible_$timestamp.mp4',
      );

      print('📁 Выходной файл: $outputPath');

      // Команда FFmpeg для конвертации
      final conversionCommand =
          '''
      -i "${file.path}" \
      -c:v libx264 \
      -preset faster \
      -crf 24 \
      -profile:v high \
      -level 4.2 \
      -pix_fmt yuv420p \
      -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" \
      -movflags +faststart \
      -c:a aac \
      -b:a 128k \
      -ac 2 \
      -ar 44100 \
      -y "$outputPath"
    '''
              .replaceAll(RegExp(r'\s+'), ' ');

      print('🚀 Команда конвертации: $conversionCommand');

      final completer = Completer<File?>();

      // Храним последний отправленный прогресс
      double lastSentProgress = -1.0;

      // ВКЛЮЧАЕМ СЛУШАТЕЛЬ ПРОГРЕССА ПЕРЕД НАЧАЛОМ
      _setupFfmpegProgressListener((progress) {
        // progress от 0 до 100
        // ОТПРАВЛЯЕМ ПРОГРЕСС ТОЛЬКО ПРИ ЗНАЧИТЕЛЬНОМ ИЗМЕНЕНИИ (минимум 1%)
        if (progress - lastSentProgress >= 1.0 || progress >= 100.0) {
          onProgress(progress);
          lastSentProgress = progress;
        }
      }, duration);

      // Запускаем FFmpeg
      FFmpegKit.executeAsync(conversionCommand, (session) async {
        try {
          final returnCode = await session.getReturnCode();

          // ОТКЛЮЧАЕМ СЛУШАТЕЛЬ ПОСЛЕ ЗАВЕРШЕНИЯ
          _disableFfmpegProgressListener();

          if (ReturnCode.isSuccess(returnCode)) {
            final outputFile = File(outputPath);

            if (await outputFile.exists()) {
              final convertedSize = await outputFile.length();

              print('✅ Конвертация успешна!');
              print(
                '📊 Новый размер: ${(convertedSize / 1024 / 1024).toStringAsFixed(2)} MB',
              );

              onProgress(100.0); // Завершаем с 100%
              completer.complete(outputFile);
            } else {
              onProgress(100.0); // Завершаем с 100%
              completer.complete(null);
            }
          } else {
            final output = await session.getOutput();
            print('❌ Конвертация не удалась: $output');
            onProgress(100.0); // Завершаем с 100%
            completer.complete(null);
          }
        } catch (e) {
          // ОТКЛЮЧАЕМ СЛУШАТЕЛЬ ПРИ ОШИБКЕ
          _disableFfmpegProgressListener();
          print('💥 Ошибка при конвертации: $e');
          onProgress(100.0); // Завершаем с 100%
          completer.complete(null);
        }
      });

      return await completer.future.timeout(
        Duration(minutes: 10),
        onTimeout: () {
          // ОТКЛЮЧАЕМ СЛУШАТЕЛЬ ПРИ ТАЙМАУТЕ
          _disableFfmpegProgressListener();
          print('⏱️ Конвертация превысила лимит времени');
          onProgress(100.0); // Завершаем с 100%
          return null;
        },
      );
    } catch (e, stackTrace) {
      // ОТКЛЮЧАЕМ СЛУШАТЕЛЬ ПРИ ОШИБКЕ
      _disableFfmpegProgressListener();
      print('💥 Ошибка при конвертации: $e');
      print('Stack: $stackTrace');
      onProgress(100.0); // Всегда завершаем прогресс
      return null;
    }
  }

  void _setupFfmpegProgressListener(
    Function(double) onProgress,
    double totalDuration,
  ) {
    if (_isProgressListenerActive) return;

    _isProgressListenerActive = true;

    print('🎯 Включаю слушатель прогресса FFmpeg');

    // Включаем callback для логов FFmpeg
    FFmpegKitConfig.enableLogCallback((log) {
      if (!_isProgressListenerActive) return;

      final message = log.getMessage();

      // Парсим прогресс из сообщений FFmpeg
      if (message.contains('time=')) {
        final progress = _parseProgressFromFfmpegOutput(message, totalDuration);
        if (progress != null && progress >= 0 && progress <= 100) {
          onProgress(progress);
        }
      }
    });
  }

  void _disableFfmpegProgressListener() {
    if (!_isProgressListenerActive) return;

    print('🎯 Отключаю слушатель прогресса FFmpeg');
    _isProgressListenerActive = false;

    // Отключаем callback
    FFmpegKitConfig.enableLogCallback(null);
  }

  // Метод для парсинга прогресса
  double? _parseProgressFromFfmpegOutput(String output, double totalDuration) {
    try {
      // Ищем время в формате time=00:00:09.38
      final timeMatch = RegExp(
        r'time=(\d{2}):(\d{2}):(\d{2}\.\d{2})',
      ).firstMatch(output);
      if (timeMatch != null) {
        final hours = int.parse(timeMatch.group(1)!);
        final minutes = int.parse(timeMatch.group(2)!);
        final seconds = double.parse(timeMatch.group(3)!);
        final currentTime = hours * 3600 + minutes * 60 + seconds;

        if (totalDuration > 0) {
          final progress = (currentTime / totalDuration) * 100.0;
          return progress;
        }
      }

      // Альтернативный формат: frame=  543 fps= 42 q=32.0 size=    5632kB time=00:00:09.38
      final altMatch = RegExp(
        r'time=(\d+):(\d+):(\d+\.\d+)',
      ).firstMatch(output);
      if (altMatch != null) {
        final hours = int.parse(altMatch.group(1)!);
        final minutes = int.parse(altMatch.group(2)!);
        final seconds = double.parse(altMatch.group(3)!);
        final currentTime = hours * 3600 + minutes * 60 + seconds;

        if (totalDuration > 0) {
          final progress = (currentTime / totalDuration) * 100.0;
          return progress;
        }
      }

      return null;
    } catch (e) {
      print('⚠️ Ошибка парсинга времени FFmpeg: $e');
      return null;
    }
  }

  // Метод для получения длительности видео
  Future<double?> _getVideoDuration(File videoFile) async {
    try {
      // Пробуем через FFprobe
      final command =
          '-i "${videoFile.path}" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1';
      final session = await FFprobeKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        if (output != null && output.trim().isNotEmpty) {
          final durationStr = output.trim();
          final duration = double.tryParse(durationStr);
          if (duration != null) {
            return duration;
          }
        }
      }

      // Альтернативный способ через FFmpeg
      final ffmpegCommand = '-i "${videoFile.path}" 2>&1 | grep Duration';
      final ffmpegSession = await FFmpegKit.execute(ffmpegCommand);
      final ffmpegOutput = await ffmpegSession.getOutput();

      if (ffmpegOutput != null) {
        final durationMatch = RegExp(
          r'Duration:\s+(\d+):(\d+):(\d+\.\d+)',
        ).firstMatch(ffmpegOutput);
        if (durationMatch != null) {
          final hours = int.parse(durationMatch.group(1)!);
          final minutes = int.parse(durationMatch.group(2)!);
          final seconds = double.parse(durationMatch.group(3)!);
          return hours * 3600 + minutes * 60 + seconds;
        }
      }

      return null;
    } catch (e) {
      print('⚠️ Не удалось получить длительность видео: $e');
      return null;
    }
  }

  // =========== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ===========

  Future<String> _getLocalIp() async {
    try {
      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final ip = addr.address;
            if (ip.startsWith('192.168.') ||
                ip.startsWith('10.') ||
                ip.startsWith('172.16.')) {
              return ip;
            }
          }
        }
      }

      for (final interface in await NetworkInterface.list()) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('⚠️ Ошибка получения IP: $e');
    }

    return '127.0.0.1';
  }

  Future<String> _getDeviceName() async {
    if (Platform.isAndroid) return 'Android Устройство';
    if (Platform.isIOS) return 'iPhone';
    return 'Устройство';
  }

  // =========== ОБРАБОТКА ПРИЕМА ФАЙЛОВ НА СЕРВЕРЕ ===========

  void _handleFileMetadata(WebSocket socket, Map<String, dynamic> data) async {
    try {
      final transferId = data['transferId'] as String;
      final fileName = data['fileName'] as String;
      final fileSize = data['fileSize'] as int;
      final fileType = data['fileType'] as String;

      print('📥 Метаданные файла: $fileName ($fileSize байт, $fileType)');

      // Проверяем, поддерживаем ли мы этот тип файла
      if (!fileType.startsWith('image/') && !fileType.startsWith('video/')) {
        print('⚠️ Неподдерживаемый тип файла: $fileType');
        socket.add(
          jsonEncode({
            'type': 'error',
            'transferId': transferId,
            'message': 'Поддерживаются только фото и видео',
          }),
        );
        return;
      }

      // Определяем, является ли это групповой передачей
      // Если transferId содержит "_" и последняя часть - число, это файл в группе
      final isGroupFile =
          transferId.contains('_') && RegExp(r'_\d+$').hasMatch(transferId);
      String groupTransferId = transferId;
      int fileIndex = 0;

      if (isGroupFile) {
        // Извлекаем ID группы и индекс файла
        final parts = transferId.split('_');
        fileIndex = int.tryParse(parts.last) ?? 0;
        groupTransferId = parts.sublist(0, parts.length - 1).join('_');

        print('📦 Файл в группе: $groupTransferId, индекс: $fileIndex');
      }

      // Создаем временный файл для приема
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s.-]'), '_');
      final tempPath = path.join(
        _appDocumentsDirectory!.path,
        _receivedFilesDir,
        'temp_${timestamp}_$safeFileName',
      );

      // Проверяем, существует ли уже групповая передача
      FileTransfer? groupTransfer;
      if (isGroupFile && _activeTransfers.containsKey(groupTransferId)) {
        groupTransfer = _activeTransfers[groupTransferId];
        print('📊 Найдена групповая передача: ${groupTransfer!.fileName}');
      }

      final receiver = FileReceiver(
        transferId: transferId,
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
        tempFile: File(tempPath),
        socket: socket,
        onProgress: (progress) {
          print(
            '📥 Прогресс приема $fileName: ${progress.toStringAsFixed(1)}%',
          );
        },
        onComplete: (file) async {
          await _saveToGallery(file, fileType, fileName);
          _fileReceivers.remove(transferId);

          // Обновляем счетчик завершенных файлов в групповой передаче
          if (isGroupFile && groupTransfer != null) {
            groupTransfer.completedFiles++;
            if (groupTransfer.completedFiles >= groupTransfer.totalFiles) {
              print('🎉 Вся группа завершена: ${groupTransfer.fileName}');
              _activeTransfers.remove(groupTransferId);
            }
            notifyListeners();
          } else {
            // Для одиночных файлов удаляем передачу
            _activeTransfers.remove(transferId);
            notifyListeners();
          }

          final media = ReceivedMedia(
            file: file,
            fileName: fileName,
            fileSize: fileSize,
            mimeType: fileType,
            receivedAt: DateTime.now(),
          );
          _receivedMedia.insert(0, media);
          notifyListeners();
        },
        onError: (error) {
          print('❌ Ошибка приема файла $fileName: $error');
          _fileReceivers.remove(transferId);
          _activeTransfers.remove(transferId);
          if (isGroupFile) {
            _activeTransfers.remove(groupTransferId);
          }
          notifyListeners();
        },
      );

      _fileReceivers[transferId] = receiver;

      // Если это первый файл в группе или одиночный файл, создаем запись о передаче
      if (!isGroupFile || groupTransfer == null) {
        String displayName;
        int totalFiles = 1;

        if (isGroupFile) {
          // Это первый файл в группе - создаем групповую передачу
          // Определяем тип группы по имени файла
          if (fileName.contains('IMG_') && fileType.startsWith('image/')) {
            displayName = 'Фотографии';
          } else if (fileName.contains('IMG_') &&
              fileType.startsWith('video/')) {
            displayName = 'Видео';
          } else {
            displayName = 'Файлы';
          }

          // Пока не знаем сколько всего файлов, но предположим минимум 1
          totalFiles = 1;
        } else {
          displayName = fileName;
        }

        final transfer = FileTransfer(
          transferId: isGroupFile ? groupTransferId : transferId,
          fileName: displayName,
          fileSize: fileSize,
          fileType: isGroupFile
              ? (fileType.startsWith('image/') ? 'image/mixed' : 'video/mixed')
              : fileType,
          file: File(tempPath),
          targetPath: tempPath,
          onProgress: (progress) {
            notifyListeners();
          },
          onComplete: (file) {
            print('✅ Передача завершена');
          },
          onError: (error) {
            print('❌ Ошибка передачи: $error');
          },
          sendMessage: (message) {
            socket.add(jsonEncode(message));
          },
          totalFiles: totalFiles,
          completedFiles: 0,
        );

        if (isGroupFile) {
          _activeTransfers[groupTransferId] = transfer;
          print('✅ Создана групповая передача: $groupTransferId');
        } else {
          _activeTransfers[transferId] = transfer;
        }

        notifyListeners();
      } else {
        // Обновляем общий размер групповой передачи
        groupTransfer.fileSize += fileSize;
        groupTransfer.totalFiles = max(groupTransfer.totalFiles, fileIndex + 1);
        print(
          '📊 Обновлена групповая передача: общий размер ${groupTransfer.fileSize} байт, файлов: ${groupTransfer.totalFiles}',
        );
        notifyListeners();
      }

      socket.add(
        jsonEncode({
          'type': 'metadata_ack',
          'transferId': transferId,
          'message': 'Готов принимать файл',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      print('❌ Ошибка обработки метаданных: $e');
    }
  }

  void _handleFileChunk(WebSocket socket, Map<String, dynamic> data) async {
    final transferId = data['transferId'] as String;
    final chunkIndex = data['chunkIndex'] as int;
    final chunkData = data['chunkData'] as String;
    final isLast = data['isLast'] as bool? ?? false;

    final receiver = _fileReceivers[transferId];
    if (receiver == null) {
      print('⚠️ Чанк для неизвестной передачи: $transferId');
      return;
    }

    try {
      final bytes = base64Decode(chunkData);
      await receiver.writeChunk(bytes);

      // Находим соответствующую передачу для обновления прогресса
      FileTransfer? transferToUpdate;

      // Прямой поиск
      if (_activeTransfers.containsKey(transferId)) {
        transferToUpdate = _activeTransfers[transferId];
      }
      // Поиск групповой передачи для файла в группе
      else if (transferId.contains('_')) {
        final parts = transferId.split('_');
        final lastPart = parts.last;
        if (int.tryParse(lastPart) != null) {
          final groupId = parts.sublist(0, parts.length - 1).join('_');
          transferToUpdate = _activeTransfers[groupId];
        }
      }

      if (transferToUpdate != null) {
        transferToUpdate.receivedBytes += bytes.length;

        // ОТПРАВЛЯЕМ ПРОГРЕСС ОБРАТНО КЛИЕНТУ
        socket.add(
          jsonEncode({
            'type': 'progress_update',
            'transferId': transferToUpdate.transferId,
            'progress': transferToUpdate.progress,
            'receivedBytes': transferToUpdate.receivedBytes,
            'totalBytes': transferToUpdate.fileSize,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );

        notifyListeners();
      }

      socket.add(
        jsonEncode({
          'type': 'chunk_ack',
          'transferId': transferId,
          'chunkIndex': chunkIndex,
          'receivedBytes': receiver.receivedBytes,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (isLast) {
        print('✅ Последний чанк для $transferId');
        await receiver.complete();

        socket.add(
          jsonEncode({
            'type': 'file_received',
            'transferId': transferId,
            'fileName': receiver.fileName,
            'fileSize': receiver.fileSize,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );

        // Удаляем только отдельные файлы, групповые передачи удаляем после завершения всех файлов
        if (!transferId.contains('_') ||
            (transferId.contains('_') &&
                int.tryParse(transferId.split('_').last) == null)) {
          _activeTransfers.remove(transferId);
          notifyListeners();
        }
      }
    } catch (e) {
      print('❌ Ошибка обработки чанка: $e');
      receiver.onError(e.toString());
      _fileReceivers.remove(transferId);

      // Удаляем соответствующие передачи
      if (_activeTransfers.containsKey(transferId)) {
        _activeTransfers.remove(transferId);
      } else if (transferId.contains('_')) {
        final parts = transferId.split('_');
        final lastPart = parts.last;
        if (int.tryParse(lastPart) != null) {
          final groupId = parts.sublist(0, parts.length - 1).join('_');
          _activeTransfers.remove(groupId);
        }
      }

      notifyListeners();
    }
  }

  Future<void> _saveToGallery(
    File file,
    String mimeType,
    String originalName,
  ) async {
    try {
      print('💾 Сохранение в галерею: ${file.path}');
      print('📱 Платформа: ${Platform.operatingSystem}');
      print('📄 MIME тип: $mimeType');
      print('📝 Имя файла: $originalName');

      bool isSaved = false;
      String? savedPath;

      if (mimeType.startsWith('image/')) {
        try {
          final bytes = await file.readAsBytes();
          print('🖼️ Размер изображения: ${bytes.length} байт');

          if (Platform.isIOS) {
            // Для iOS используем правильный путь
            final result = await ImageGallerySaverPlus.saveImage(
              bytes,
              name: originalName,
              quality: 100,
              isReturnImagePathOfIOS: true,
            );

            print('📱 Результат сохранения на iOS: $result');

            if (result is Map) {
              final success = result['isSuccess'] as bool? ?? false;
              final filePath = result['filePath'] as String?;
              if (success) {
                isSaved = true;
                savedPath = filePath;
                print('✅ Изображение сохранено в галерею iOS: $originalName');
                if (filePath != null) {
                  print('📁 Путь: $filePath');
                }
              } else {
                print('❌ Ошибка при сохранении изображения на iOS');
              }
            } else if (result is bool) {
              isSaved = result;
              if (isSaved) {
                print(
                  '✅ Изображение сохранено в галерею Android: $originalName',
                );
              } else {
                print('❌ Ошибка при сохранении изображения на Android');
              }
            }
          } else {
            // Для Android
            final result = await ImageGallerySaverPlus.saveImage(
              bytes,
              name: originalName,
              quality: 100,
            );

            print('📱 Результат сохранения на Android: $result');

            if (result is Map) {
              final success = result['isSuccess'] as bool? ?? false;
              if (success) {
                isSaved = true;
                print(
                  '✅ Изображение сохранено в галерею Android: $originalName',
                );
              }
            } else if (result is bool) {
              isSaved = result;
              if (isSaved) {
                print(
                  '✅ Изображение сохранено в галерею Android: $originalName',
                );
              }
            }
          }
        } catch (e) {
          print('❌ Ошибка при сохранении изображения: $e');
        }
      } else if (mimeType.startsWith('video/')) {
        try {
          print('🎥 Размер видео файла: ${await file.length()} байт');

          if (Platform.isIOS) {
            // Для iOS видео
            final result = await ImageGallerySaverPlus.saveFile(
              file.path,
              name: originalName,
              isReturnPathOfIOS: true,
            );

            print('📱 Результат сохранения видео на iOS: $result');

            if (result is Map) {
              final success = result['isSuccess'] as bool? ?? false;
              final filePath = result['filePath'] as String?;
              if (success) {
                isSaved = true;
                savedPath = filePath;
                print('✅ Видео сохранено в галерею iOS: $originalName');
                if (filePath != null) {
                  print('📁 Путь: $filePath');
                }
              } else {
                print('❌ Ошибка при сохранении видео на iOS');
              }
            }
          } else {
            // Для Android видео
            final result = await ImageGallerySaverPlus.saveFile(
              file.path,
              name: originalName,
            );

            print('📱 Результат сохранения видео на Android: $result');

            if (result is Map) {
              final success = result['isSuccess'] as bool? ?? false;
              if (success) {
                isSaved = true;
                print('✅ Видео сохранено в галерею Android: $originalName');
              }
            }
          }
        } catch (e) {
          print('❌ Ошибка при сохранении видео: $e');
        }
      }

      if (isSaved) {
        _status = 'Файл сохранен в галерею';
        final length = await file.length();

        // Обновляем путь в ReceivedMedia, если файл был сохранен в галерею
        if (savedPath != null && savedPath.isNotEmpty) {
          final media = _receivedMedia.firstWhere(
            (m) => m.fileName == originalName,
            orElse: () => ReceivedMedia(
              file: file,
              fileName: originalName,
              fileSize: length,
              mimeType: mimeType,
              receivedAt: DateTime.now(),
            ),
          );

          if (media.file.path != savedPath) {
            print('🔄 Обновляю путь к файлу: $savedPath');
            // Обновляем файл на новый путь
            media.file = File(savedPath);
          }
        }

        // Удаляем временный файл после успешного сохранения
        try {
          if (await file.exists()) {
            await file.delete();
            print('🗑️ Временный файл удален: ${file.path}');
          }
        } catch (e) {
          print('⚠️ Ошибка удаления временного файла: $e');
        }
      } else {
        print('⚠️ Не удалось сохранить файл в галерею, оставляю локально');
        _status = 'Файл сохранен локально';

        // Перемещаем файл из временной директории в постоянную
        try {
          final permanentDir = Directory(
            path.join(_appDocumentsDirectory!.path, _receivedFilesDir),
          );

          if (!await permanentDir.exists()) {
            await permanentDir.create(recursive: true);
          }

          final permanentPath = path.join(permanentDir.path, originalName);

          await file.copy(permanentPath);
          await file.delete();

          print('📁 Файл перемещен в постоянную директорию: $permanentPath');

          final fileSize = await File(permanentPath).length();

          // Обновляем путь в ReceivedMedia
          final media = _receivedMedia.firstWhere(
            (m) => m.fileName == originalName,
            orElse: () => ReceivedMedia(
              file: File(permanentPath),
              fileName: originalName,
              fileSize: fileSize,
              mimeType: mimeType,
              receivedAt: DateTime.now(),
            ),
          );

          media.file = File(permanentPath);
        } catch (e) {
          print('⚠️ Ошибка перемещения файла: $e');
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ Критическая ошибка сохранения в галерею: $e');
      print('Stack: $stackTrace');
      _status = 'Ошибка сохранения: $e';
      notifyListeners();
    }
  }

  void _handleChunkAck(Map<String, dynamic> data) {
    final transferId = data['transferId'] as String?;
    final receivedBytes = data['receivedBytes'] as int?;

    if (transferId != null && receivedBytes != null) {
      print('✅ Подтверждение чанка $transferId: $receivedBytes байт');

      // Ищем родительскую групповую передачу
      // Если transferId содержит "_", значит это дочерний файл
      if (transferId.contains('_')) {
        final parts = transferId.split('_');
        final groupId = parts.sublist(0, parts.length - 1).join('_');

        final groupTransfer = _activeTransfers[groupId];
        if (groupTransfer != null) {
          // Обновляем прогресс на основе полученных байт
          // Здесь можно добавить логику для обновления прогресса на основе ACK
          notifyListeners();
        }
      }
    }
  }

  void _handleFileReceived(Map<String, dynamic> data) {
    final transferId = data['transferId'] as String?;
    final fileName = data['fileName'] as String?;

    if (transferId != null && fileName != null) {
      print('🎉 Файл $fileName успешно доставлен на сервер');

      // Если это дочерний файл, не удаляем групповую передачу сразу
      // Групповая передача удаляется только по onComplete
      if (transferId.contains('_')) {
        // Это дочерний файл - ничего не делаем с групповой передачей
      } else {
        _activeTransfers.remove(transferId);
      }
      notifyListeners();
    }
  }

  // =========== УПРАВЛЕНИЕ ПОЛУЧЕННЫМИ МЕДИА ===========

  Future<void> openMediaInGallery(ReceivedMedia media) async {
    try {
      print('📱 Открытие медиа: ${media.file.path}');
      _status = 'Открытие: ${media.fileName}';
      notifyListeners();
    } catch (e) {
      print('❌ Ошибка открытия медиа: $e');
    }
  }

  Future<bool> deleteMedia(ReceivedMedia media) async {
    try {
      if (await media.file.exists()) {
        await media.file.delete();
        _receivedMedia.remove(media);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления медиа: $e');
      return false;
    }
  }

  Future<void> refreshReceivedMedia() async {
    await _loadReceivedMedia();
  }

  @override
  void dispose() {
    // Закрываем все активные файловые потоки
    for (final receiver in _fileReceivers.values) {
      receiver.close();
    }
    _fileReceivers.clear();

    stopServer();
    disconnect();
    super.dispose();
  }
}

// =========== ВСПОМОГАТЕЛЬНЫЕ КЛАССЫ ===========

class FileReceiver {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String fileType;
  final File tempFile;
  final WebSocket socket;
  final Function(double) onProgress;
  final Function(File) onComplete;
  final Function(String) onError;

  int receivedBytes = 0;
  IOSink? _fileSink;
  bool _isClosed = false;

  FileReceiver({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.tempFile,
    required this.socket,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  });

  Future<void> writeChunk(List<int> bytes) async {
    if (_isClosed) {
      throw StateError('FileReceiver уже закрыт');
    }

    _fileSink ??= tempFile.openWrite(mode: FileMode.writeOnly);
    _fileSink!.add(bytes);

    receivedBytes += bytes.length;
    final progress = (receivedBytes / fileSize) * 100;
    onProgress(progress);
  }

  Future<void> complete() async {
    if (_isClosed) return;

    if (_fileSink != null) {
      await _fileSink!.flush();
      await _fileSink!.close();
      _fileSink = null;
    }

    _isClosed = true;

    final receivedSize = await tempFile.length();
    if (receivedSize == fileSize) {
      onComplete(tempFile);
    } else {
      final error = Exception(
        'Размер файла не совпадает: ожидалось $fileSize, получено $receivedSize',
      );
      onError(error.toString());
    }
  }

  Future<void> close() async {
    if (_isClosed) return;

    _isClosed = true;

    if (_fileSink != null) {
      try {
        await _fileSink!.flush();
        await _fileSink!.close();
      } catch (e) {
        print('⚠️ Ошибка при закрытии файлового потока: $e');
      }
      _fileSink = null;
    }

    // Удаляем временный файл, если он существует
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (e) {
      print('⚠️ Ошибка удаления временного файла: $e');
    }
  }
}

class ReceivedMedia {
  File file;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final DateTime receivedAt;

  ReceivedMedia({
    required this.file,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.receivedAt,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');

  String get sizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class FileTransfer {
  final String transferId;
  final String fileName;
  int fileSize;
  String fileType;
  File file;
  String targetPath;
  int receivedBytes = 0;
  int totalFiles = 0; // Общее количество файлов в группе
  int completedFiles = 0; // Количество завершенных файлов
  final Function(double) onProgress;
  final Function(File) onComplete;
  final Function(String) onError;
  final Function(Map<String, dynamic>) sendMessage;

  FileTransfer({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.file,
    required this.targetPath,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
    required this.sendMessage,
    this.totalFiles = 1, // Значение по умолчанию
    this.completedFiles = 0, // Значение по умолчанию
  });

  double get progress {
    if (fileSize <= 0) return 0.0;
    final calculated = (receivedBytes.toDouble() / fileSize.toDouble()) * 100.0;
    // ОГРАНИЧИВАЕМ ПРОГРЕСС 100%
    return calculated.clamp(0.0, 100.0);
  }

  void updateProgress(int bytes) {
    receivedBytes = bytes;
    // ОГРАНИЧИВАЕМ ПРОГРЕСС
    final clampedProgress = progress;
    onProgress(clampedProgress);
  }

  void completeFile() {
    completedFiles++;
    if (completedFiles >= totalFiles) {
      // Устанавливаем точный прогресс 100%
      receivedBytes = fileSize;
      onProgress(100.0);
      onComplete(file);
    }
  }

  // Дополнительный геттер для отображения статуса
  String get status {
    if (completedFiles >= totalFiles) return 'Завершено';
    if (receivedBytes > 0) return 'В процессе';
    return 'Ожидание';
  }

  // Методы для форматирования байт в читаемый вид
  String get sizeFormatted {
    return _formatBytes(fileSize);
  }

  String get progressSizeFormatted {
    return '${_formatBytes(receivedBytes)} / ${_formatBytes(fileSize)}';
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
}
