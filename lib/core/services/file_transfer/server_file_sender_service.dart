import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:ui';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

import '../../core.dart';

class ServerFileSenderService {
  final VideoConverterService _videoConverter;
  final FileTransferManager _transferManager;
  final VoidCallback onProgressUpdated;

  // Храним подтверждения сохранения файлов
  final Map<String, Completer<bool>> _fileSaveCompleters = {};
  final Map<String, Map<int, bool>> _fileSaveConfirmations = {};

  ServerFileSenderService({
    required VideoConverterService videoConverter,
    required FileTransferManager transferManager,
    required this.onProgressUpdated,
  }) : _videoConverter = videoConverter,
       _transferManager = transferManager;

  Future<void> sendFilesToClient(
    List<File> files,
    WebSocket client,
    Function(WebSocket, Map<String, dynamic>) sendToClient,
  ) async {
    print('🚀 Сервер начинает отправку файлов клиенту');

    // Очищаем старые передачи перед началом новых
    _transferManager.clearAllTransfers();
    _fileSaveCompleters.clear();
    _fileSaveConfirmations.clear();

    // Проверяем платформу сервера
    final isServerIOS = Platform.isIOS;

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
      photoTransferId = await _createPhotoTransfer(
        photoFiles,
        client,
        sendToClient,
      );
      _fileSaveConfirmations[photoTransferId] = {};
    }

    // Создаем передачи для видео
    String? videoTransferId;
    if (videoFiles.isNotEmpty) {
      videoTransferId = await _createVideoTransfer(
        videoFiles,
        client,
        sendToClient,
        isServerIOS: isServerIOS,
      );
      _fileSaveConfirmations[videoTransferId] = {};
    }

    // Отправляем файлы группами
    if (photoFiles.isNotEmpty && photoTransferId != null) {
      print('🚀 Начинаю отправку ${photoFiles.length} фото с сервера...');
      await _sendFileGroup(
        photoFiles,
        client,
        photoTransferId,
        isVideoGroup: false,
        isServerIOS: isServerIOS,
        sendToClient: sendToClient,
      );
    }

    if (videoFiles.isNotEmpty && videoTransferId != null) {
      print('🚀 Начинаю отправку ${videoFiles.length} видео с сервера...');
      await _sendFileGroup(
        videoFiles,
        client,
        videoTransferId,
        isVideoGroup: true,
        isServerIOS: isServerIOS,
        sendToClient: sendToClient,
      );
    }

    print('🎯 Все групповые передачи запущены с сервера');
  }

  Future<String> _createPhotoTransfer(
    List<File> photoFiles,
    WebSocket client,
    Function(WebSocket, Map<String, dynamic>) sendToClient,
  ) async {
    final photoTransferId = 'photos_${DateTime.now().millisecondsSinceEpoch}';
    int totalPhotoSize = 0;

    for (final file in photoFiles) {
      try {
        final length = await file.length();
        totalPhotoSize += length;
        print(
          '📊 Фото ${path.basename(file.path)}: ${FileUtils.formatBytes(length)}',
        );
      } catch (e) {
        print('⚠️ Ошибка получения размера фото: $e');
      }
    }

    final photoTransfer = FileTransfer(
      transferId: photoTransferId,
      fileName: '${photoFiles.length} фото',
      fileSize: totalPhotoSize,
      fileType: 'image/mixed',
      file: photoFiles.first,
      targetPath: '',
      onProgress: (progress) {
        // UI будет обновляться через onProgress callback
      },
      onComplete: (file) {
        print('✅ Все фото отправлены с сервера');
      },
      onError: (error) {
        print('❌ Ошибка отправки фото: $error');
        _transferManager.removeTransfer(photoTransferId);
      },
      sendMessage: (message) {
        try {
          sendToClient(client, message);
        } catch (e) {
          print('❌ Ошибка отправки сообщения клиенту: $e');
        }
      },
      totalFiles: photoFiles.length,
      completedFiles: 0,
    );

    _transferManager.addTransfer(photoTransfer);

    print(
      '📸 Создана групповая передача фото: ${photoFiles.length} файлов, '
      'общий размер: ${(totalPhotoSize / (1024 * 1024)).toStringAsFixed(2)} MB',
    );

    return photoTransferId;
  }

  Future<String> _createVideoTransfer(
    List<File> videoFiles,
    WebSocket client,
    Function(WebSocket, Map<String, dynamic>) sendToClient, {
    required bool isServerIOS,
  }) async {
    final videoTransferId = 'videos_${DateTime.now().millisecondsSinceEpoch}';
    int totalVideoSize = 0;

    // Для iOS сервера: если есть MOV файлы, оцениваем размер после конвертации
    if (isServerIOS) {
      for (final file in videoFiles) {
        if (_videoConverter.isMovFile(file)) {
          // Для MOV файлов добавляем 20% к размеру (оценка конвертации)
          final originalSize = await file.length();
          totalVideoSize += (originalSize * 1.2).toInt();
          print(
            '📊 MOV видео ${path.basename(file.path)}: ${FileUtils.formatBytes(originalSize)} '
            '(будет конвертирован, примерный размер после: ${FileUtils.formatBytes((originalSize * 1.2).toInt())})',
          );
        } else {
          final length = await file.length();
          totalVideoSize += length;
          print(
            '📊 Видео ${path.basename(file.path)}: ${FileUtils.formatBytes(length)}',
          );
        }
      }
    } else {
      // Для не-iOS серверов используем оригинальные размеры
      for (final file in videoFiles) {
        try {
          final length = await file.length();
          totalVideoSize += length;
          print(
            '📊 Видео ${path.basename(file.path)}: ${FileUtils.formatBytes(length)}',
          );
        } catch (e) {
          print('⚠️ Ошибка получения размера видео: $e');
        }
      }
    }

    final videoTransfer = FileTransfer(
      transferId: videoTransferId,
      fileName: '${videoFiles.length} видео',
      fileSize: totalVideoSize,
      fileType: 'video/mixed',
      file: videoFiles.first,
      targetPath: '',
      onProgress: (progress) {
        // UI будет обновляться через onProgress callback
      },
      onComplete: (file) {
        print('✅ Все видео отправлены с сервера');
      },
      onError: (error) {
        print('❌ Ошибка отправки видео: $error');
        _transferManager.removeTransfer(videoTransferId);
      },
      sendMessage: (message) {
        try {
          sendToClient(client, message);
        } catch (e) {
          print('❌ Ошибка отправки сообщения клиенту: $e');
        }
      },
      totalFiles: videoFiles.length,
      completedFiles: 0,
    );

    _transferManager.addTransfer(videoTransfer);

    print(
      '🎥 Создана групповая передача видео: ${videoFiles.length} файлов, '
      'общий размер: ${(totalVideoSize / (1024 * 1024)).toStringAsFixed(2)} MB',
    );

    // Отправляем метаданные видео группы немедленно
    final videoGroupMetadata = {
      'type': 'group_metadata',
      'transferId': videoTransferId,
      'fileName': '${videoFiles.length} видео',
      'totalFiles': videoFiles.length,
      'totalSize': totalVideoSize,
      'fileType': 'video/mixed',
      'timestamp': DateTime.now().toIso8601String(),
    };

    sendToClient(client, videoGroupMetadata);
    print('📤 Отправлены метаданные видео группы немедленно');

    return videoTransferId;
  }

  Future<void> _sendFileGroup(
    List<File> files,
    WebSocket socket,
    String groupTransferId, {
    required bool isVideoGroup,
    required bool isServerIOS,
    required Function(WebSocket, Map<String, dynamic>) sendToClient,
  }) async {
    final transfer = _transferManager.getTransfer(groupTransferId);
    if (transfer == null) {
      print('⚠️ Групповая передача $groupTransferId не найдена');
      return;
    }

    bool isCancelled = false;

    if (_transferManager.getTransfer(groupTransferId) == null) {
      print('⚠️ Передача была отменена до начала отправки');
      return;
    }

    // Отправляем метаданные группы
    final groupMetadata = {
      'type': 'group_metadata',
      'transferId': groupTransferId,
      'fileName': transfer.fileName,
      'totalFiles': files.length,
      'totalSize': transfer.fileSize,
      'fileType': isVideoGroup ? 'video/mixed' : 'image/mixed',
      'timestamp': DateTime.now().toIso8601String(),
    };

    sendToClient(socket, groupMetadata);
    await Future.delayed(Duration(milliseconds: 200)); // Пауза для обработки

    int totalBytesSent = 0;
    final int totalGroupSize = transfer.fileSize;

    print(
      '📊 Начинаю отправку группы с сервера: ${files.length} файлов, '
      'общий размер: ${(totalGroupSize / (1024 * 1024)).toStringAsFixed(2)} MB',
    );

    // Начальный прогресс
    transfer.updateProgress(0);

    // Отправляем начальный прогресс клиенту
    _sendProgressUpdate(
      socket,
      groupTransferId,
      0.0,
      0,
      totalGroupSize,
      sendToClient,
    );

    for (int i = 0; i < files.length; i++) {
      if (_transferManager.getTransfer(groupTransferId) == null) {
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

      if (isCancelled ||
          _transferManager.getTransfer(groupTransferId) == null) {
        print('⚠️ Отмена во время подготовки файла ${i + 1}');
        break;
      }

      final fileShare = fileSize.toDouble() / totalGroupSize.toDouble();
      final progressBeforeThisFile =
          (totalBytesSent.toDouble() / totalGroupSize.toDouble()) * 100.0;

      // ПОДДЕРЖКА КОНВЕРТАЦИИ MOV -> MP4 для iOS сервера
      if (isVideoGroup && isServerIOS && _videoConverter.isMovFile(file)) {
        print('🎥 iOS сервер обнаружил MOV файл, начинаю конвертацию...');

        // Создаем Completer для отмены конвертации
        final cancelCompleter = Completer<void>();

        // Обновляем прогресс конвертации
        _sendProgressUpdate(
          socket,
          groupTransferId,
          progressBeforeThisFile,
          totalBytesSent,
          totalGroupSize,
          sendToClient,
        );

        // Запускаем конвертацию с отслеживанием прогресса
        final convertedFile = await _videoConverter.convertMovToMp4(file, (
          double progress,
        ) {
          // Обновляем прогресс конвертации (0-50% от доли этого файла)
          final conversionShare =
              fileShare * 0.5; // Конвертация занимает 50% времени
          final currentConversionProgress = progress * 0.5; // 0-50%
          final totalProgressForThisFile =
              progressBeforeThisFile +
              (conversionShare * currentConversionProgress);

          transfer.updateProgress(
            (totalProgressForThisFile / 100.0 * totalGroupSize).toInt(),
          );

          _sendProgressUpdate(
            socket,
            groupTransferId,
            totalProgressForThisFile,
            transfer.receivedBytes,
            totalGroupSize,
            sendToClient,
          );
        }, cancelCompleter: cancelCompleter);

        // Проверяем отмену
        if (_transferManager.getTransfer(groupTransferId) == null) {
          print('⚠️ Передача отменена во время конвертации');
          cancelCompleter.complete(); // Отменяем конвертацию
          isCancelled = true;
          break;
        }

        if (convertedFile != null) {
          fileToSend = convertedFile;
          fileType = 'video/mp4';
          print('✅ MOV успешно сконвертирован в MP4');
        } else {
          print('⚠️ Конвертация не удалась, отправляю оригинальный MOV файл');
          // Отправляем как есть, возможно Android клиент сможет обработать
        }
      } else {
        // Для обычных файлов просто отправляем прогресс
        _sendProgressUpdate(
          socket,
          groupTransferId,
          progressBeforeThisFile,
          totalBytesSent,
          totalGroupSize,
          sendToClient,
        );
      }

      if (isCancelled ||
          _transferManager.getTransfer(groupTransferId) == null) {
        print('⚠️ Отмена перед началом передачи файла');
        break;
      }

      final progressBeforeTransfer = progressBeforeThisFile;
      final clampedProgressBeforeTransfer = progressBeforeTransfer.clamp(
        0.0,
        100.0,
      );

      final bytesBeforeTransfer =
          (clampedProgressBeforeTransfer / 100.0 * totalGroupSize).toInt();
      transfer.updateProgress(bytesBeforeTransfer);

      _sendProgressUpdate(
        socket,
        groupTransferId,
        clampedProgressBeforeTransfer,
        transfer.receivedBytes,
        totalGroupSize,
        sendToClient,
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
        'isConverted': fileToSend.path != file.path, // Флаг конвертации
      };

      socket.add(jsonEncode(metadata));
      await Future.delayed(Duration(milliseconds: 100)); // Пауза для клиента

      // Открываем поток с проверкой отмены
      final stream = fileToSend.openRead();
      var chunkIndex = 0;
      var fileSentBytes = 0;

      try {
        await for (final chunk in stream) {
          if (_transferManager.getTransfer(groupTransferId) == null) {
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

          // Для конвертированных файлов учитываем что часть прогресса уже пройдена
          final transferShareInGroup = fileTransferProgress * fileShare;

          final groupProgress =
              progressBeforeTransfer + (transferShareInGroup * 100.0);

          final clampedGroupProgress = groupProgress.clamp(0.0, 100.0);

          final bytesForGroupProgress =
              (clampedGroupProgress / 100.0 * totalGroupSize).toInt();
          transfer.updateProgress(bytesForGroupProgress);

          // Для видео отправляем прогресс чаще (каждый чанк)
          if (isVideoGroup ||
              chunkIndex % 2 == 0 ||
              fileSentBytes == currentFileSize) {
            _sendProgressUpdate(
              socket,
              groupTransferId,
              clampedGroupProgress,
              transfer.receivedBytes,
              totalGroupSize,
              sendToClient,
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

      if (isCancelled ||
          _transferManager.getTransfer(groupTransferId) == null) {
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

      totalBytesSent += await fileToSend.length();

      final exactGroupProgress =
          (totalBytesSent.toDouble() / totalGroupSize.toDouble()) * 100.0;
      final clampedExactProgress = exactGroupProgress.clamp(0.0, 100.0);

      final bytesForExactProgress =
          (clampedExactProgress / 100.0 * totalGroupSize).toInt();
      transfer.updateProgress(bytesForExactProgress);

      _sendProgressUpdate(
        socket,
        groupTransferId,
        clampedExactProgress,
        transfer.receivedBytes,
        totalGroupSize,
        sendToClient,
      );

      // Увеличиваем таймаут для видео файлов
      print('⏳ Жду подтверждения сохранения файла ${i + 1} от клиента...');

      try {
        // Создаем Completer для ожидания подтверждения
        final completerKey = '$groupTransferId-$i';
        final completer = Completer<bool>();
        _fileSaveCompleters[completerKey] = completer;

        // Увеличиваем таймаут для видео: 60 секунд вместо 30
        final timeoutDuration = isVideoGroup
            ? Duration(seconds: 60)
            : Duration(seconds: 30);

        final confirmed = await completer.future.timeout(
          timeoutDuration,
          onTimeout: () {
            print('⚠️ Таймаут ожидания подтверждения для файла ${i + 1}');
            return false;
          },
        );

        if (confirmed) {
          print('✅ Клиент подтвердил сохранение файла ${i + 1}');
        } else {
          print('⚠️ Клиент не подтвердил сохранение файла ${i + 1}');
        }
      } catch (e) {
        print('⚠️ Ошибка ожидания подтверждения: $e');
      }

      // Увеличиваем паузу между видео файлами
      final pauseDuration = isVideoGroup
          ? Duration(milliseconds: 2000) // 2 секунды для видео
          : Duration(milliseconds: 500); // 0.5 секунды для фото

      await Future.delayed(pauseDuration);

      print(
        '✅ ${isVideoGroup ? 'Видео' : 'Фото'} ${i + 1}/${files.length} отправлено с сервера '
        '(${transfer.completedFiles}/${transfer.totalFiles} файлов, '
        '${clampedExactProgress.toStringAsFixed(1)}%)',
      );

      // Удаляем временный файл только если он был создан конвертером
      if (fileToSend.path != file.path && await fileToSend.exists()) {
        try {
          await fileToSend.delete();
          print('🗑️ Удален временный конвертированный файл');
        } catch (e) {
          print('⚠️ Не удалось удалить временный файл: $e');
        }
      }

      if (_transferManager.getTransfer(groupTransferId) == null) {
        print('⚠️ Передача отменена после завершения файла');
        isCancelled = true;
        break;
      }
    }

    if (isCancelled) {
      print('🛑 Отправка отменена пользователем');
      transfer.onError('Передача отменена');
    } else {
      // Ждем подтверждения для всех файлов
      print('⏳ Ожидаю финальных подтверждений сохранения...');
      await Future.delayed(Duration(seconds: isVideoGroup ? 5 : 2));

      // ФИНАЛЬНАЯ ПРОВЕРКА СЧЕТЧИКА
      final confirmedFiles =
          _fileSaveConfirmations[groupTransferId]?.values
              .where((confirmed) => confirmed == true)
              .length ??
          0;

      // Если подтверждено меньше файлов, но все отправлено - устанавливаем totalFiles
      if (confirmedFiles < transfer.totalFiles) {
        print(
          '⚠️ Подтверждено $confirmedFiles из ${transfer.totalFiles} файлов',
        );

        // Для последнего файла мог быть таймаут, но файл был сохранен
        if (transfer.progress >= 100.0) {
          print(
            '🔄 Исправляю счетчик завершенной передачи: '
            '$confirmedFiles → ${transfer.totalFiles}',
          );
          transfer.completedFiles = transfer.totalFiles;
          onProgressUpdated.call(); // Уведомляем UI
        } else {
          transfer.completedFiles = confirmedFiles;
        }
      } else {
        transfer.completedFiles = confirmedFiles;
      }
    }

    // Завершаем прогресс группы - ТОЧНО 100%
    transfer.updateProgress(totalGroupSize);

    _sendProgressUpdate(
      socket,
      groupTransferId,
      100.0,
      totalGroupSize,
      totalGroupSize,
      sendToClient,
    );
    transfer.onComplete(files.first);

    print(
      '🎉 Все ${files.length} ${isVideoGroup ? 'видео' : 'фото'} отправлены с сервера! '
      '(${transfer.completedFiles}/${transfer.totalFiles} файлов)',
    );
  }

  void handleFileSavedConfirmation(Map<String, dynamic> data) {
    try {
      final transferId = data['transferId'] as String?;
      final fileIndex = data['fileIndex'] as int?;
      final success = data['success'] as bool? ?? false;

      if (transferId != null && fileIndex != null) {
        print(
          '✅ Получено подтверждение сохранения файла: $transferId, индекс: $fileIndex',
        );

        // Сохраняем подтверждение
        _fileSaveConfirmations[transferId]?[fileIndex] = success;

        // Разрешаем Completer если он есть
        final completerKey = '$transferId-$fileIndex';
        final completer = _fileSaveCompleters[completerKey];
        if (completer != null && !completer.isCompleted) {
          completer.complete(success);
          _fileSaveCompleters.remove(completerKey);
        }

        // Обновляем счетчик в transfer
        final transfer = _transferManager.getTransfer(transferId);
        if (transfer != null && success) {
          // Считаем количество подтвержденных файлов
          final confirmedFiles =
              _fileSaveConfirmations[transferId]?.values
                  .where((confirmed) => confirmed == true)
                  .length ??
              0;

          transfer.completedFiles = confirmedFiles;
          print(
            '📊 Обновлен счетчик файлов: $confirmedFiles/${transfer.totalFiles}',
          );

          // Уведомляем UI
          onProgressUpdated.call();
        }
      }
    } catch (e) {
      print('❌ Ошибка обработки подтверждения сохранения: $e');
    }
  }

  void _sendProgressUpdate(
    WebSocket socket,
    String transferId,
    double progress,
    int receivedBytes,
    int totalBytes,
    Function(WebSocket, Map<String, dynamic>) sendToClient,
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

      sendToClient(socket, progressMessage);
    } catch (e) {
      print('❌ Ошибка отправки прогресса клиенту: $e');
    }
  }
}
