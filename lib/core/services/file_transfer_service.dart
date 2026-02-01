// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../app.dart';
import '../core.dart';

class FileTransferService extends ChangeNotifier {
  final WebSocketServerService _webSocketServer = WebSocketServerService();
  final VideoConverterService _videoConverter = VideoConverterService();
  final GallerySaverService _gallerySaver = GallerySaverService();
  final MediaManagerService _mediaManager = MediaManagerService();

  static const int CHUNK_SIZE = 32 * 1024; // 32KB
  static const int PORT = 8080;

  // Состояние
  final Map<String, FileTransfer> _activeTransfers = {};
  String _status = 'Готов';

  // WebSocket клиент
  WebSocketChannel? _clientChannel;
  String? _connectedServerIp;
  String? _connectedServerName;

  final Map<String, FileReceiver> _fileReceivers = {};

  bool _shouldShowSubscriptionDialog = false;

  // Getters
  bool get isServerRunning => _webSocketServer.isServerRunning;
  String get localIp => _webSocketServer.localIp;
  List<WebSocket> get connectedClients => _webSocketServer.connectedClients;

  String get status => _status; // TODO: DELETE?
  String? get connectedServerIp => _connectedServerIp;
  String? get connectedServerName => _connectedServerName;
  bool get isConnected => _clientChannel != null;

  Map<String, FileTransfer> get activeTransfers => Map.from(_activeTransfers);

  List<ReceivedMedia> get receivedMedia => _mediaManager.receivedMedia;

  bool get shouldShowSubscriptionDialog => _shouldShowSubscriptionDialog;

  // Колбэк для уведомления UI об отсутствии подписки
  VoidCallback? _onSubscriptionRequired;

  void setOnSubscriptionRequiredCallback(VoidCallback callback) {
    _onSubscriptionRequired = callback;
  }

  void removeOnSubscriptionRequiredCallback() {
    _onSubscriptionRequired = null;
  }

  // Колбэк для уведомления UI об отмене с другой стороны
  void Function(String message)? _onRemoteCancellationCallback;

  void setRemoteCancellationCallback(Function(String) callback) {
    _onRemoteCancellationCallback = callback;
  }

  FileTransferService() {
    _initialize(); // TODO: DELETE?
  }

  Future<void> _initialize() async {} // TODO: DELETE?

  @override
  void dispose() {
    // Закрываем все активные файловые потоки
    for (final receiver in _fileReceivers.values) {
      receiver.close();
    }
    _fileReceivers.clear();

    // Очищаем активные передачи
    _activeTransfers.clear();

    // Освобождаем ресурсы сервисов
    _webSocketServer.dispose();
    _videoConverter.dispose();
    _mediaManager.dispose();

    stopServer();
    disconnect();
    super.dispose();
  }

  // MARK: - СЕРВЕРНЫЕ МЕТОДЫ

  Future<void> startServer() async {
    try {
      _status = 'Запуск сервера...';
      notifyListeners();

      // Настраиваем обработчики сообщений
      _webSocketServer.setMessageHandler(_handleServerMessage);
      _webSocketServer.setClientConnectedHandler((client) {
        notifyListeners();
      });
      _webSocketServer.setClientDisconnectedHandler((client) {
        notifyListeners();
      });

      await _webSocketServer.startServer();

      _status = 'Сервер запущен ✅\nIP: ${_webSocketServer.localIp}';
      notifyListeners();
    } catch (e, stackTrace) {
      print('💥 ОШИБКА ЗАПУСКА СЕРВЕРА: $e');
      print('Stack: $stackTrace');

      _status = 'Ошибка: $e';
      notifyListeners();
      rethrow;
    }
  }

  void _handleServerMessage(WebSocket socket, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'handshake':
        _handleClientHandshake(socket, data);
        break;
      case 'metadata_ack':
        print('✅ Клиент готов принимать файл');
        break;
      case 'chunk_ack':
        _handleChunkAckFromClient(socket, data);
        break;
      case 'file_received':
        _handleFileReceivedFromClient(socket, data);
        break;
      case 'progress_update':
        _handleProgressUpdateFromClient(socket, data);
        break;
      case 'cancel_transfer':
        _handleCancelTransferFromClient(socket, data);
        break;
    }
  }

  void _handleCancelTransferFromClient(
    WebSocket socket,
    Map<String, dynamic> data,
  ) {
    try {
      final transferId = data['transferId'] as String?;
      if (transferId != null) {
        print('🛑 Получена отмена передачи от клиента: $transferId');

        // Уведомляем UI об отмене (только для этой передачи)
        if (_onRemoteCancellationCallback != null) {
          _onRemoteCancellationCallback!('The receiver canceled the transfer');
        }

        // Отменяем только указанную передачу
        _cancelTransferInternal(transferId, notifyRemote: false);
      }
    } catch (e) {
      print('❌ Ошибка обработки отмены от клиента: $e');
    }
  }

  void _handleProgressUpdateFromClient(
    WebSocket socket,
    Map<String, dynamic> data,
  ) {
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
          '📈 Прогресс от клиента (прием): $transferId - ${progress.toStringAsFixed(1)}% '
          '(${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)})',
        );

        // Обновляем прогресс на сервере для отображения прогресса на клиенте
        final transfer = _activeTransfers[transferId];
        if (transfer != null) {
          // Обновляем прогресс на стороне клиента (для отображения на сервере)
          transfer.receivedBytes = receivedBytes;
          transfer.onProgress(progress);
          notifyListeners();
        }
      }
    } catch (e) {
      print('❌ Ошибка обработки прогресса от клиента: $e');
    }
  }

  Future<void> _handleClientHandshake(
    WebSocket socket,
    Map<String, dynamic> data,
  ) async {
    print('🤝 Handshake от клиента: ${data['clientInfo']}');

    // Проверяем наличие подписки
    if (!isSubscribed.value) {
      print('⚠️ У сервера нет подписки, отправляю уведомление клиенту');

      await _webSocketServer.sendToClient(socket, {
        'type': 'subscription_required',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Закрываем соединение - сервис сам удалит клиента
      await Future.delayed(Duration(milliseconds: 500));
      try {
        await socket.close();
      } catch (e) {
        print('⚠️ Ошибка закрытия сокета: $e');
      }

      notifyListeners();
      return;
    }

    // Если подписка есть - продолжаем обычный handshake
    await _webSocketServer.sendToClient(socket, {
      'type': 'handshake_ack',
      'message': 'Добро пожаловать',
      'serverInfo': {
        'name': await _getDeviceName(),
        'platform': Platform.operatingSystem,
        'ip': _webSocketServer.localIp,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });

    notifyListeners();
  }

  void _handleChunkAckFromClient(WebSocket socket, Map<String, dynamic> data) {
    final transferId = data['transferId'] as String?;
    final receivedBytes = data['receivedBytes'] as int?;

    if (transferId != null && receivedBytes != null) {
      print(
        '✅ Подтверждение чанка от клиента: $transferId - ${_formatBytes(receivedBytes)}',
      );
    }
  }

  void _handleFileReceivedFromClient(
    WebSocket socket,
    Map<String, dynamic> data,
  ) {
    final transferId = data['transferId'] as String?;
    final fileName = data['fileName'] as String?;

    if (transferId != null && fileName != null) {
      print('🎉 Клиент подтвердил получение файла: $fileName');
    }
  }

  // Метод для очистки передач на клиенте
  Future<void> clearClientTransfers() async {
    print('🧹 Очищаю клиентские передачи...');

    // Отключаем от сервера
    if (_clientChannel != null) {
      await disconnect();
    }

    // Закрываем все активные файловые потоки
    final receiversCopy = Map<String, FileReceiver>.from(_fileReceivers);
    for (final entry in receiversCopy.entries) {
      try {
        await entry.value.close();
      } catch (e) {
        print('⚠️ Ошибка закрытия приемника ${entry.key}: $e');
      }
    }
    _fileReceivers.clear();

    // Очищаем активные передачи
    _activeTransfers.clear();

    // Сбрасываем состояния
    _status = 'Готов';

    notifyListeners();
    print('✅ Клиентские передачи очищены');
  }

  Future<void> stopServer() async {
    try {
      print('🛑 Остановка сервера...');

      // Очищаем все активные передачи
      _activeTransfers.clear();

      // Закрываем все активные файловые потоки
      final receiversCopy = Map<String, FileReceiver>.from(_fileReceivers);
      for (final entry in receiversCopy.entries) {
        try {
          await entry.value.close();
        } catch (e) {
          print('⚠️ Ошибка закрытия приемника ${entry.key}: $e');
        }
      }
      _fileReceivers.clear();

      // Останавливаем WebSocket сервер
      await _webSocketServer.stopServer();

      // Сбрасываем состояния
      _status = 'Сервер остановлен';
      _connectedServerIp = null;
      _connectedServerName = null;

      notifyListeners();

      print('✅ Сервер остановлен, все передачи очищены');
    } catch (e) {
      print('❌ Ошибка остановки сервера: $e');
    }
  }

  // MARK: - ОТПРАВКА ФАЙЛОВ С СЕРВЕРА НА КЛИЕНТ

  Future<void> sendFilesToClient(
    List<File> files,
    WebSocket? targetClient,
  ) async {
    if (_webSocketServer.connectedClients.isEmpty) {
      throw Exception('Нет подключенных клиентов');
    }

    // Используем целевого клиента или первого подключенного
    final client = targetClient ?? _webSocketServer.connectedClients.first;

    print('🚀 Сервер начинает отправку файлов клиенту');

    // Очищаем старые передачи перед началом новых
    _activeTransfers.clear();
    notifyListeners();

    // Создаем отдельные передачи для фото и видео - ВОССТАНАВЛИВАЕМ ОРИГИНАЛЬНУЮ ЛОГИКУ
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
        try {
          final length = await file.length();
          totalPhotoSize += length;
          print('📊 Фото ${path.basename(file.path)}: ${_formatBytes(length)}');
        } catch (e) {
          print('⚠️ Ошибка получения размера фото: $e');
        }
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
          print('✅ Все фото отправлены с сервера');
        },
        onError: (error) {
          print('❌ Ошибка отправки фото: $error');
          _activeTransfers.remove(photoTransferId);
          notifyListeners();
        },
        sendMessage: (message) {
          try {
            _webSocketServer.sendToClient(client, message);
          } catch (e) {
            print('❌ Ошибка отправки сообщения клиенту: $e');
          }
        },
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
        try {
          final length = await file.length();
          totalVideoSize += length;
          print(
            '📊 Видео ${path.basename(file.path)}: ${_formatBytes(length)}',
          );
        } catch (e) {
          print('⚠️ Ошибка получения размера видео: $e');
        }
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
          print('✅ Все видео отправлены с сервера');
        },
        onError: (error) {
          print('❌ Ошибка отправки видео: $error');
          _activeTransfers.remove(videoTransferId);
          notifyListeners();
        },
        sendMessage: (message) {
          try {
            _webSocketServer.sendToClient(client, message);
          } catch (e) {
            print('❌ Ошибка отправки сообщения клиенту: $e');
          }
        },
        totalFiles: videoFiles.length,
        completedFiles: 0,
      );

      print(
        '🎥 Создана групповая передача видео: ${videoFiles.length} файлов, '
        'общий размер: ${(totalVideoSize / (1024 * 1024)).toStringAsFixed(2)} MB',
      );

      final videoGroupMetadata = {
        'type': 'group_metadata',
        'transferId': videoTransferId,
        'fileName': '${videoFiles.length} видео',
        'totalFiles': videoFiles.length,
        'totalSize': totalVideoSize,
        'fileType': 'video/mixed',
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _webSocketServer.sendToClient(client, videoGroupMetadata);
      print('📤 Отправлены метаданные видео группы немедленно');
    }

    // Уведомляем UI о создании передач
    notifyListeners();

    // Отправляем файлы группами
    if (photoFiles.isNotEmpty) {
      print('🚀 Начинаю отправку ${photoFiles.length} фото с сервера...');
      await _sendFileGroupFromServer(
        photoFiles,
        client,
        photoTransferId!,
        isVideoGroup: false,
      );
    }

    if (videoFiles.isNotEmpty) {
      print('🚀 Начинаю отправку ${videoFiles.length} видео с сервера...');
      await _sendFileGroupFromServer(
        videoFiles,
        client,
        videoTransferId!,
        isVideoGroup: true,
      );
    }

    print('🎯 Все групповые передачи запущены с сервера');
  }

  Future<void> _sendFileGroupFromServer(
    List<File> files,
    WebSocket socket,
    String groupTransferId, {
    required bool isVideoGroup,
  }) async {
    final transfer = _activeTransfers[groupTransferId];
    if (transfer == null) {
      print('⚠️ Групповая передача $groupTransferId не найдена');
      return;
    }

    // Флаг отмены передачи
    bool isCancelled = false;

    // Проверяем отмену перед началом
    if (!_activeTransfers.containsKey(groupTransferId)) {
      print('⚠️ Передача была отменена до начала отправки');
      return;
    }

    // ОТПРАВЛЯЕМ МЕТАДАННЫЕ ГРУППЫ
    final groupMetadata = {
      'type': 'group_metadata',
      'transferId': groupTransferId,
      'fileName': transfer.fileName,
      'totalFiles': files.length,
      'totalSize': transfer.fileSize,
      'fileType': isVideoGroup ? 'video/mixed' : 'image/mixed',
      'timestamp': DateTime.now().toIso8601String(),
    };

    _webSocketServer.sendToClient(socket, groupMetadata);

    await Future.delayed(Duration(milliseconds: 100));

    int totalBytesSent = 0;
    final int totalGroupSize = transfer.fileSize;

    print(
      '📊 Начинаю отправку группы с сервера: ${files.length} файлов, '
      'общий размер: ${(totalGroupSize / (1024 * 1024)).toStringAsFixed(2)} MB',
    );

    // Начальный прогресс
    transfer.receivedBytes = 0;
    transfer.onProgress(0.0);

    // Отправляем начальный прогресс клиенту
    _sendProgressUpdateToClient(
      socket,
      groupTransferId,
      0.0,
      0,
      totalGroupSize,
    );

    for (int i = 0; i < files.length; i++) {
      // Проверяем отмену перед каждым файлом
      if (!_activeTransfers.containsKey(groupTransferId)) {
        print('⚠️ Передача отменена во время отправки файла ${i + 1}');
        isCancelled = true;
        break;
      }

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

      // Проверяем отмену
      if (isCancelled || !_activeTransfers.containsKey(groupTransferId)) {
        print('⚠️ Отмена во время подготовки файла ${i + 1}');
        break;
      }

      // Точная доля этого файла в общей группе
      final fileShare = fileSize.toDouble() / totalGroupSize.toDouble();

      // Прогресс до начала этого файла
      final progressBeforeThisFile =
          (totalBytesSent.toDouble() / totalGroupSize.toDouble()) * 100.0;

      final conversionWeight = isVideoGroup ? 40.0 : 0.0;
      final transferWeight = isVideoGroup ? 60.0 : 100.0;

      if (isVideoGroup &&
          mimeType.startsWith('video/') &&
          _videoConverter.isMovFile(file)) {
        print('🎬 Конвертация .mov в .mp4 на сервере...');

        final fileTransferId = '${groupTransferId}_$i';
        final currentFileSize = fileSize;

        final metadata = {
          'type': 'file_metadata',
          'transferId': fileTransferId,
          'fileName': fileName,
          'fileSize': currentFileSize,
          'fileType': mimeType,
          'timestamp': DateTime.now().toIso8601String(),
          'isConverting': true,
        };

        socket.add(jsonEncode(metadata));
        await Future.delayed(Duration(milliseconds: 100));

        // Проверяем отмену перед конвертацией
        if (!_activeTransfers.containsKey(groupTransferId)) {
          print('⚠️ Передача отменена перед конвертацией');
          isCancelled = true;
          break;
        }

        // Прогресс на начало конвертации
        transfer.onProgress(progressBeforeThisFile);
        _sendProgressUpdateToClient(
          socket,
          groupTransferId,
          progressBeforeThisFile,
          totalBytesSent,
          totalGroupSize,
        );

        final convertedFile = await _videoConverter.convertMovToMp4(file, (
          conversionProgress,
        ) {
          // Проверяем отмену во время конвертации
          if (!_activeTransfers.containsKey(groupTransferId)) {
            print('⚠️ Передача отменена во время конвертации');
            isCancelled = true;
            return;
          }

          final conversionShareInGroup =
              (conversionProgress / 100.0) *
              conversionWeight *
              fileShare /
              100.0;

          final groupProgress =
              progressBeforeThisFile + (conversionShareInGroup * 100.0);

          final clampedProgress = groupProgress.clamp(0.0, 100.0);

          transfer.receivedBytes = (clampedProgress / 100.0 * totalGroupSize)
              .toInt();
          transfer.onProgress(clampedProgress);

          _sendProgressUpdateToClient(
            socket,
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

        // Проверяем отмену после конвертации
        if (!_activeTransfers.containsKey(groupTransferId)) {
          print('⚠️ Передача отменена после конвертации');
          isCancelled = true;
          break;
        }
      } else {
        _sendProgressUpdateToClient(
          socket,
          groupTransferId,
          progressBeforeThisFile,
          totalBytesSent,
          totalGroupSize,
        );
      }

      // Проверяем отмену
      if (isCancelled || !_activeTransfers.containsKey(groupTransferId)) {
        print('⚠️ Отмена перед началом передачи файла');
        break;
      }

      final progressBeforeTransfer =
          progressBeforeThisFile + (conversionWeight * fileShare);
      final clampedProgressBeforeTransfer = progressBeforeTransfer.clamp(
        0.0,
        100.0,
      );

      transfer.receivedBytes =
          (clampedProgressBeforeTransfer / 100.0 * totalGroupSize).toInt();
      transfer.onProgress(clampedProgressBeforeTransfer);
      _sendProgressUpdateToClient(
        socket,
        groupTransferId,
        clampedProgressBeforeTransfer,
        transfer.receivedBytes,
        totalGroupSize,
      );

      // Отправка текущего файла
      print(
        '📤 Отправка ${isVideoGroup ? 'видео' : 'фото'} ${i + 1}/${files.length} с сервера',
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

      socket.add(jsonEncode(metadata));
      await Future.delayed(Duration(milliseconds: 50));

      // Открываем поток с проверкой отмены
      final stream = fileToSend.openRead();
      var chunkIndex = 0;
      var fileSentBytes = 0;

      try {
        await for (final chunk in stream) {
          // Проверяем отмену перед отправкой каждого чанка
          if (!_activeTransfers.containsKey(groupTransferId)) {
            print('⚠️ Передача отменена во время отправки чанка $chunkIndex');
            isCancelled = true;
            break;
          }

          final chunkMessage = {
            'type': 'file_chunk',
            'transferId': fileTransferId,
            'chunkIndex': chunkIndex,
            'chunkData': base64Encode(chunk),
            'isLast': false,
            'timestamp': DateTime.now().toIso8601String(),
          };

          socket.add(jsonEncode(chunkMessage));
          fileSentBytes += chunk.length;
          chunkIndex++;

          final fileTransferProgress =
              fileSentBytes.toDouble() / currentFileSize.toDouble();

          final transferShareInGroup =
              fileTransferProgress * transferWeight * fileShare / 100.0;

          final groupProgress =
              progressBeforeTransfer + (transferShareInGroup * 100.0);

          final clampedGroupProgress = groupProgress.clamp(0.0, 100.0);

          transfer.receivedBytes =
              (clampedGroupProgress / 100.0 * totalGroupSize).toInt();
          transfer.onProgress(clampedGroupProgress);

          if (chunkIndex % 2 == 0 || fileSentBytes == currentFileSize) {
            _sendProgressUpdateToClient(
              socket,
              groupTransferId,
              clampedGroupProgress,
              transfer.receivedBytes,
              totalGroupSize,
            );
          }
        }
      } catch (e) {
        if (!isCancelled) {
          print('❌ Ошибка во время отправки файла: $e');
          transfer.onError(e.toString());
          break;
        }
      }

      // Если отменено, выходим
      if (isCancelled || !_activeTransfers.containsKey(groupTransferId)) {
        print('⚠️ Передача отменена, прекращаем отправку файлов');
        break;
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

      socket.add(jsonEncode(finalMessage));

      totalBytesSent += fileSize;

      final exactGroupProgress =
          (totalBytesSent.toDouble() / totalGroupSize.toDouble()) * 100.0;
      final clampedExactProgress = exactGroupProgress.clamp(0.0, 100.0);

      transfer.receivedBytes = (clampedExactProgress / 100.0 * totalGroupSize)
          .toInt();
      transfer.onProgress(clampedExactProgress);
      _sendProgressUpdateToClient(
        socket,
        groupTransferId,
        clampedExactProgress,
        transfer.receivedBytes,
        totalGroupSize,
      );

      transfer.completedFiles++;

      print(
        '✅ ${isVideoGroup ? 'Видео' : 'Фото'} ${i + 1}/${files.length} отправлено с сервера '
        '(${transfer.completedFiles}/${transfer.totalFiles} файлов, '
        '${clampedExactProgress.toStringAsFixed(1)}%)',
      );

      // Удаляем временный файл
      if (fileToSend.path != file.path && await fileToSend.exists()) {
        try {
          await fileToSend.delete();
          print('🗑️ Удален временный конвертированный файл');
        } catch (e) {
          print('⚠️ Не удалось удалить временный файл: $e');
        }
      }

      // Проверяем отмену
      if (!_activeTransfers.containsKey(groupTransferId)) {
        print('⚠️ Передача отменена после завершения файла');
        isCancelled = true;
        break;
      }
    }

    if (isCancelled) {
      print('🛑 Отправка отменена пользователем');
      transfer.onError('Передача отменена');
    } else {
      // Завершаем прогресс группы - ТОЧНО 100%
      transfer.receivedBytes = totalGroupSize;
      transfer.onProgress(100.0);
      _sendProgressUpdateToClient(
        socket,
        groupTransferId,
        100.0,
        totalGroupSize,
        totalGroupSize,
      );
      transfer.onComplete(files.first);

      print(
        '🎉 Все ${files.length} ${isVideoGroup ? 'видео' : 'фото'} отправлены с сервера! '
        '(100%, ${transfer.completedFiles}/${transfer.totalFiles} файлов)',
      );
    }
  }

  void _sendProgressUpdateToClient(
    WebSocket socket,
    String transferId,
    double progress,
    int receivedBytes,
    int totalBytes,
  ) {
    try {
      final progressMessage = {
        'type': 'progress_update',
        'transferId': transferId,
        'progress': progress.clamp(0.0, 100.0),
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _webSocketServer.sendToClient(socket, progressMessage);
    } catch (e) {
      print('❌ Ошибка отправки прогресса клиенту: $e');
    }
  }

  Future<void> cancelTransfer(String transferId) async {
    try {
      print('🛑 Инициация отмены передачи: $transferId');
      await _cancelTransferInternal(transferId, notifyRemote: true);
    } catch (e) {
      print('❌ Ошибка при отмене передачи: $e');
    }
  }

  Future<void> _cancelTransferInternal(
    String transferId, {
    required bool notifyRemote,
  }) async {
    try {
      // Находим передачу
      final transfer = _activeTransfers[transferId];
      if (transfer == null) {
        print('⚠️ Передача не найдена: $transferId');
        return;
      }

      print('🛑 Отменяем передачу: ${transfer.fileName} ($transferId)');

      // Отправляем сообщение об отмене другой стороне
      if (notifyRemote) {
        final cancelMessage = {
          'type': 'cancel_transfer',
          'transferId': transferId,
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Используем копию списка для безопасной итерации
        final connectedClientsCopy = List<WebSocket>.from(
          _webSocketServer.connectedClients,
        );

        if (connectedClientsCopy.isNotEmpty) {
          // Сервер отменяет - отправляем клиенту
          _webSocketServer.broadcast(cancelMessage);
        } else if (_clientChannel != null) {
          // Клиент отменяет - отправляем серверу
          _sendClientMessage(cancelMessage);
          print('📤 Отправлена отмена серверу: $transferId');
        }
      }

      // Создаем копию ключей для безопасной итерации
      final receiverKeys = List<String>.from(_fileReceivers.keys);

      for (final key in receiverKeys) {
        // Отменяем только связанные с этой конкретной передачей приемники
        if (key.startsWith(transferId) || key == transferId) {
          print('🛑 Закрываем приемник файла: $key');
          try {
            await _fileReceivers[key]?.close();
          } catch (e) {
            print('⚠️ Ошибка закрытия приемника $key: $e');
          }
          _fileReceivers.remove(key);
        }
      }

      // Удаляем только конкретную передачу
      _activeTransfers.remove(transferId);

      // Вызываем callback ошибки для передачи
      transfer.onError('Передача отменена пользователем');

      // Уведомляем UI
      notifyListeners();

      print('✅ Передача успешно отменена: $transferId');
    } catch (e) {
      print('❌ Ошибка при отмене передачи: $e');
      rethrow;
    }
  }
  // MARK: - КЛИЕНТСКИЕ МЕТОДЫ (ПРИЕМ ФАЙЛОВ)

  void resetSubscriptionDialogFlag() {
    _shouldShowSubscriptionDialog = false;
    notifyListeners();
  }

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
        case 'subscription_required':
          _handleSubscriptionRequired(data);
          break;
        case 'group_metadata':
          _handleGroupMetadataFromServer(data);
          break;
        case 'file_metadata':
          _handleFileMetadataFromServer(data);
          break;
        case 'file_chunk':
          _handleFileChunkFromServer(data);
          break;
        case 'progress_update':
          _handleProgressFromServer(data);
          break;
        case 'cancel_transfer':
          _handleCancelTransferFromServer(data);
          break;
      }
    } catch (e) {
      print('❌ Ошибка обработки сообщения клиентом: $e');
    }
  }

  void _handleSubscriptionRequired(Map<String, dynamic> data) {
    print('⚠️ Получено сообщение: требуется подписка на сервере');

    disconnect();

    _shouldShowSubscriptionDialog = true;
    notifyListeners();

    // Вызываем callback если он установлен
    if (_onSubscriptionRequired != null) {
      _onSubscriptionRequired!();
    }
  }

  void _handleCancelTransferFromServer(Map<String, dynamic> data) {
    try {
      final transferId = data['transferId'] as String?;
      if (transferId != null) {
        print('🛑 Получена отмена передачи от сервера: $transferId');

        // Уведомляем UI об отмене (только для этой передачи)
        if (_onRemoteCancellationCallback != null) {
          _onRemoteCancellationCallback!('The sender canceled the transfer');
        }

        // Отменяем только указанную передачу
        _cancelTransferInternal(transferId, notifyRemote: false);
      }
    } catch (e) {
      print('❌ Ошибка обработки отмены от сервера: $e');
    }
  }

  void _handleGroupMetadataFromServer(Map<String, dynamic> data) async {
    try {
      final transferId = data['transferId'] as String;
      final fileName = data['fileName'] as String;
      final totalFiles = data['totalFiles'] as int;
      final totalSize = data['totalSize'] as int;
      final fileType = data['fileType'] as String;

      print(
        '📦 Клиент получает метаданные группы от сервера: $fileName '
        '($totalFiles файлов, ${_formatBytes(totalSize)})',
      );

      // Всегда создаем групповую передачу, даже если она уже существует
      // Это нужно для того, чтобы обновить totalFiles и totalSize

      final transfer = FileTransfer(
        transferId: transferId,
        fileName: fileName,
        fileSize: totalSize, // Окончательный размер файла (от сервера)
        fileType: fileType,
        file: File(''), // Временный файл
        targetPath: '',
        onProgress: (progress) {
          notifyListeners();
        },
        onComplete: (file) {
          print('✅ Групповая передача завершена: $fileName');
        },
        onError: (error) {
          print('❌ Ошибка групповой передачи: $error');
          _activeTransfers.remove(transferId);
          notifyListeners();
        },
        sendMessage: (message) {
          _sendClientMessage(message);
        },
        totalFiles: totalFiles, // Устанавливаем правильное количество файлов
        completedFiles: 0,
      );

      _activeTransfers[transferId] = transfer;
      print(
        '✅ Создана/обновлена групповая передача от сервера: $transferId '
        '($totalFiles файлов, ${_formatBytes(totalSize)})',
      );

      // Обновляем флаг наличия видео передачи для UI
      if (transferId.startsWith('videos_') || fileType == 'video/mixed') {
        print('🎥 Зарегистрирована видео передача: $fileName');
      }

      notifyListeners();
    } catch (e) {
      print('❌ Ошибка обработки метаданных группы от сервера: $e');
    }
  }

  void _handleFileMetadataFromServer(Map<String, dynamic> data) async {
    try {
      final transferId = data['transferId'] as String;
      final fileName = data['fileName'] as String;
      final fileSize = data['fileSize'] as int;
      final fileType = data['fileType'] as String;

      print(
        '📥 Клиент получает метаданные файла от сервера: $fileName (${_formatBytes(fileSize)})',
      );

      // Определяем, является ли это групповой передачей
      final isGroupFile =
          transferId.contains('_') && RegExp(r'_\d+$').hasMatch(transferId);
      String groupTransferId = transferId;
      int fileIndex = 0;

      if (isGroupFile) {
        // Извлекаем ID группы и индекс файла
        final parts = transferId.split('_');
        fileIndex = int.tryParse(parts.last) ?? 0;
        groupTransferId = parts.sublist(0, parts.length - 1).join('_');

        print(
          '📦 Файл в группе от сервера: $groupTransferId, индекс: $fileIndex',
        );
      }

      // Создаем временный файл для приема
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s.-]'), '_');
      final mediaDirPath = await _mediaManager.getMediaDirectoryPath();
      final tempPath = path.join(
        mediaDirPath,
        'from_server_${timestamp}_$safeFileName',
      );
      // Проверяем, существует ли уже групповая передача
      FileTransfer? groupTransfer;
      if (isGroupFile && _activeTransfers.containsKey(groupTransferId)) {
        groupTransfer = _activeTransfers[groupTransferId];
        print(
          '📊 Найдена групповая передача от сервера: ${groupTransfer!.fileName} '
          '(${groupTransfer.completedFiles}/${groupTransfer.totalFiles} файлов, '
          '${_formatBytes(groupTransfer.fileSize)})',
        );
      }

      final receiver = FileReceiver(
        transferId: transferId,
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
        tempFile: File(tempPath),
        socket: null,
        onProgress: (progress) {
          // Прогресс для отдельного файла
          print(
            '📥 Прогресс приема $fileName: ${progress.toStringAsFixed(1)}%',
          );
        },
        onComplete: (file) async {
          await _saveToGallery(file, fileType, fileName);
          _fileReceivers.remove(transferId);

          // Отправляем подтверждение серверу
          _sendClientMessage({
            'type': 'file_received',
            'transferId': transferId,
            'fileName': fileName,
            'timestamp': DateTime.now().toIso8601String(),
          });

          // Обновляем счетчик завершенных файлов в групповой передаче
          if (isGroupFile && groupTransfer != null) {
            groupTransfer.completedFiles++;

            print(
              '✅ Файл ${fileIndex + 1}/${groupTransfer.totalFiles} завершен: $fileName '
              '(${_formatBytes(fileSize)})',
            );

            if (groupTransfer.completedFiles >= groupTransfer.totalFiles) {
              print(
                '🎉 Вся группа от сервера завершена: ${groupTransfer.fileName} '
                '(${groupTransfer.completedFiles} файлов, '
                '${_formatBytes(groupTransfer.fileSize)})',
              );

              // Обновляем прогресс до 100%
              groupTransfer.receivedBytes = groupTransfer.fileSize;
              groupTransfer.onProgress(100.0);
            }
            notifyListeners();
          } else {
            // Для одиночных файлов удаляем передачу
            print('✅ Одиночный файл завершен: $fileName');
          }

          await _mediaManager.addMedia(
            file: file,
            fileName: fileName,
            mimeType: fileType,
            receivedAt: DateTime.now(),
          );
        },
        onError: (error) {
          print('❌ Ошибка приема файла $fileName: $error');
          _fileReceivers.remove(transferId);

          // Удаляем только соответствующую передачу
          if (isGroupFile) {
            // Для групповой передачи не удаляем всю группу при ошибке одного файла
            print('⚠️ Ошибка в файле ${fileIndex + 1} групповой передачи');
          } else {
            _activeTransfers.remove(transferId);
          }
          notifyListeners();
        },
      );

      _fileReceivers[transferId] = receiver;

      // Если это НЕ групповая передача, создаем запись о передаче
      if (!isGroupFile) {
        final transfer = FileTransfer(
          transferId: transferId,
          fileName: fileName,
          fileSize: fileSize,
          fileType: fileType,
          file: File(tempPath),
          targetPath: tempPath,
          onProgress: (progress) {
            notifyListeners();
          },
          onComplete: (file) {
            print('✅ Передача от сервера завершена');
          },
          onError: (error) {
            print('❌ Ошибка передачи от сервера: $error');
            _activeTransfers.remove(transferId);
            notifyListeners();
          },
          sendMessage: (message) {
            _sendClientMessage(message);
          },
          totalFiles: 1,
          completedFiles: 0,
        );

        _activeTransfers[transferId] = transfer;
        print('✅ Создана передача для одиночного файла: $fileName');
        notifyListeners();
      }
      // Для групповых передач НЕ создаем новую передачу и НЕ меняем размер!
      // Передача уже должна быть создана из group_metadata

      // Подтверждаем получение метаданных
      _sendClientMessage({
        'type': 'metadata_ack',
        'transferId': transferId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Ошибка обработки метаданных от сервера: $e');
    }
  }

  void _handleFileChunkFromServer(Map<String, dynamic> data) async {
    final transferId = data['transferId'] as String;
    final chunkIndex = data['chunkIndex'] as int;
    final chunkData = data['chunkData'] as String;
    final isLast = data['isLast'] as bool? ?? false;

    // Проверяем, не отменена ли передача
    final receiver = _fileReceivers[transferId];
    if (receiver == null) {
      print('⚠️ Чанк для неизвестной или отмененной передачи: $transferId');
      return;
    }

    try {
      final bytes = base64Decode(chunkData);
      await receiver.writeChunk(bytes);

      // Находим соответствующую передачу
      FileTransfer? transferToUpdate;

      if (_activeTransfers.containsKey(transferId)) {
        transferToUpdate = _activeTransfers[transferId];
      } else if (transferId.contains('_')) {
        final parts = transferId.split('_');
        final lastPart = parts.last;
        if (int.tryParse(lastPart) != null) {
          final groupId = parts.sublist(0, parts.length - 1).join('_');
          transferToUpdate = _activeTransfers[groupId];
        }
      }

      // Если передача не найдена (возможно отменена), пропускаем обновление
      if (transferToUpdate != null) {
        transferToUpdate.receivedBytes += bytes.length;

        // Отправляем прогресс серверу
        _sendClientMessage({
          'type': 'progress_update',
          'transferId': transferToUpdate.transferId,
          'progress': transferToUpdate.progress,
          'receivedBytes': transferToUpdate.receivedBytes,
          'totalBytes': transferToUpdate.fileSize,
          'timestamp': DateTime.now().toIso8601String(),
        });

        notifyListeners();
      }

      // Отправляем подтверждение серверу
      _sendClientMessage({
        'type': 'chunk_ack',
        'transferId': transferId,
        'chunkIndex': chunkIndex,
        'receivedBytes': receiver.receivedBytes,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (isLast) {
        print('✅ Последний чанк от сервера для $transferId');
        await receiver.complete();
      }
    } catch (e) {
      // Не логируем ошибку, если передача была отменена
      if (!transferId.contains('cancelled')) {
        print('❌ Ошибка обработки чанка от сервера: $e');
      }

      // Если receiver еще существует, закрываем его
      if (_fileReceivers.containsKey(transferId)) {
        receiver.onError(e.toString());
        _fileReceivers.remove(transferId);
      }
    }
  }

  void _handleProgressFromServer(Map<String, dynamic> data) {
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
          '📈 Прогресс от сервера: $transferId - ${progress.toStringAsFixed(1)}% '
          '(${_formatBytes(receivedBytes)} / ${_formatBytes(totalBytes)})',
        );

        // Находим соответствующую передачу на клиенте
        final transfer = _activeTransfers[transferId];
        if (transfer != null) {
          // ОБНОВЛЯЕМ только полученные байты и прогресс
          // НЕ меняем общий размер (totalBytes) - он уже установлен из group_metadata
          transfer.receivedBytes = receivedBytes;

          // Убеждаемся, что прогресс не превышает 100%
          final clampedProgress = progress.clamp(0.0, 100.0);
          transfer.onProgress(clampedProgress);

          // Логируем для отладки
          print(
            '📊 Обновлен прогресс группы: ${transfer.fileName} '
            '${transfer.receivedBytes}/${transfer.fileSize} байт '
            '(${clampedProgress.toStringAsFixed(1)}%)',
          );

          notifyListeners();
        }
      }
    } catch (e) {
      print('❌ Ошибка обработки прогресса от сервера: $e');
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

  // MARK: - ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ

  Future<String> _getDeviceName() async {
    if (Platform.isAndroid) return 'Android Устройство';
    if (Platform.isIOS) return 'iPhone';
    return 'Устройство';
  }

  // MARK: - КОНВЕРТАЦИЯ ВИДЕО

  // MARK: - СОХРАНЕНИЕ ФАЙЛОВ

  Future<void> _saveToGallery(
    File file,
    String mimeType,
    String originalName,
  ) async {
    try {
      final result = await _gallerySaver.saveToGallery(
        file: file,
        mimeType: mimeType,
        originalName: originalName,
      );

      if (result.isSaved) {
        _status = 'Файл сохранен в галерею';
        final length = result.fileSize ?? await file.length();

        // Обновляем путь в MediaManager, если файл был сохранен в галерею
        if (result.savedPath != null && result.savedPath!.isNotEmpty) {
          await _mediaManager.updateMediaFile(
            originalName,
            File(result.savedPath!),
          );
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
          final permanentFile = await _gallerySaver.moveToPermanentDirectory(
            tempFile: file,
            originalName: originalName,
            appDocumentsDirectory: _mediaManager.appDocumentsDirectory!,
            receivedFilesDir: _mediaManager.receivedFilesDir,
          );

          // Обновляем файл в MediaManager
          await _mediaManager.updateMediaFile(originalName, permanentFile);
        } catch (e) {
          print('⚠️ Ошибка перемещения файла: $e');
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ Ошибка сохранения файла: $e');
      print('Stack: $stackTrace');
      _status = 'Ошибка сохранения: $e';
      notifyListeners();
    }
  }

  // MARK: - УПРАВЛЕНИЕ ПОЛУЧЕННЫМИ МЕДИА

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
    return await _mediaManager.deleteMedia(media);
  }

  Future<void> refreshReceivedMedia() async {
    await _mediaManager.refreshMedia();
  }

  // MARK: - ПУБЛИЧНЫЕ МЕТОДЫ ДЛЯ UI

  // Метод для сервера: отправить файлы клиенту
  Future<void> sendFilesToConnectedClient(List<File> files) async {
    if (_webSocketServer.connectedClients.isEmpty) {
      throw Exception('Нет подключенных клиентов');
    }

    // Отправляем файлы первому подключенному клиенту
    await sendFilesToClient(files, _webSocketServer.connectedClients.first);
  }

  // Метод для сервера: отправить файлы конкретному клиенту
  Future<void> sendFilesToSpecificClient(
    List<File> files,
    WebSocket client,
  ) async {
    await sendFilesToClient(files, client);
  }

  // Получить список подключенных клиентов (для UI сервера)

  // Получить информацию о клиенте
  String getClientInfo(WebSocket client) {
    final index = _webSocketServer.connectedClients.indexOf(client);
    return 'Клиент ${index + 1}';
  }

  // Вспомогательный метод для форматирования байт
  String _formatBytes(int bytes, {bool forceSameUnit = false}) {
    if (forceSameUnit) {
      // Принудительно используем MB для всех значений > 1MB
      if (bytes >= 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
      // Для значений < 1MB используем KB
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }

    // Оригинальная логика
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// MARK: - ВСПОМОГАТЕЛЬНЫЕ КЛАССЫ

class FileReceiver {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String fileType;
  final File tempFile;
  final WebSocket? socket;
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
  int totalFiles = 0;
  int completedFiles = 0;
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
    this.totalFiles = 1,
    this.completedFiles = 0,
  });

  double get progress {
    if (fileSize <= 0) return 0.0;
    final calculated = (receivedBytes.toDouble() / fileSize.toDouble()) * 100.0;
    return calculated.clamp(0.0, 100.0);
  }

  void updateProgress(int bytes) {
    receivedBytes = bytes;
    final clampedProgress = progress;
    onProgress(clampedProgress);
  }

  void completeFile() {
    completedFiles++;
    if (completedFiles >= totalFiles) {
      receivedBytes = fileSize;
      onProgress(100.0);
      onComplete(file);
    }
  }

  String get status {
    if (completedFiles >= totalFiles) return 'Завершено';
    if (receivedBytes > 0) return 'В процессе';
    return 'Ожидание';
  }

  String get sizeFormatted {
    return _formatBytes(fileSize);
  }

  String get progressSizeFormatted {
    // Используем синхронизированные единицы измерения
    if (fileSize >= 1024 * 1024) {
      // Для больших файлов используем MB для обоих
      final receivedMB = receivedBytes / (1024 * 1024);
      final totalMB = fileSize / (1024 * 1024);
      return '${receivedMB.toStringAsFixed(2)} / ${totalMB.toStringAsFixed(2)} MB';
    } else if (fileSize >= 1024) {
      // Для средних файлов используем KB для обоих
      final receivedKB = receivedBytes / 1024;
      final totalKB = fileSize / 1024;
      return '${receivedKB.toStringAsFixed(2)} / ${totalKB.toStringAsFixed(2)} KB';
    } else {
      // Для маленьких файлов используем байты
      return '$receivedBytes / $fileSize B';
    }
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
