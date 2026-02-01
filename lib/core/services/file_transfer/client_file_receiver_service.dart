import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../core.dart';

class ClientFileReceiverService {
  final MediaManagerService _mediaManager;
  final GallerySaverService _gallerySaver;
  final FileTransferManager _transferManager;
  final Function(Map<String, dynamic>) _sendClientMessage;

  ClientFileReceiverService({
    required MediaManagerService mediaManager,
    required GallerySaverService gallerySaver,
    required FileTransferManager transferManager,
    required Function(Map<String, dynamic>) sendClientMessage,
  }) : _mediaManager = mediaManager,
       _gallerySaver = gallerySaver,
       _transferManager = transferManager,
       _sendClientMessage = sendClientMessage;

  // MARK: - ОБРАБОТКА СООБЩЕНИЙ ОТ СЕРВЕРА

  void handleGroupMetadata(Map<String, dynamic> data) {
    try {
      final transferId = data['transferId'] as String;
      final fileName = data['fileName'] as String;
      final totalFiles = data['totalFiles'] as int;
      final totalSize = data['totalSize'] as int;
      final fileType = data['fileType'] as String;

      print(
        '📦 Клиент получает метаданные группы от сервера: $fileName '
        '($totalFiles файлов, ${FileUtils.formatBytes(totalSize)})',
      );

      final transfer = FileTransfer(
        transferId: transferId,
        fileName: fileName,
        fileSize: totalSize,
        fileType: fileType,
        file: File(''),
        targetPath: '',
        onProgress: (progress) {
          // UI будет обновляться через FileTransferManager
        },
        onComplete: (file) {
          print('✅ Групповая передача завершена: $fileName');
        },
        onError: (error) {
          print('❌ Ошибка групповой передачи: $error');
          _transferManager.removeTransfer(transferId);
        },
        sendMessage: _sendClientMessage,
        totalFiles: totalFiles,
        completedFiles: 0,
      );

      _transferManager.addTransfer(transfer);
      print(
        '✅ Создана групповая передача от сервера: $transferId '
        '($totalFiles файлов, ${FileUtils.formatBytes(totalSize)})',
      );

      if (transferId.startsWith('videos_') || fileType == 'video/mixed') {
        print('🎥 Зарегистрирована видео передача: $fileName');
      }
    } catch (e) {
      print('❌ Ошибка обработки метаданных группы от сервера: $e');
    }
  }

  void handleFileMetadata(Map<String, dynamic> data) async {
    try {
      final transferId = data['transferId'] as String;
      final fileName = data['fileName'] as String;
      final fileSize = data['fileSize'] as int;
      final fileType = data['fileType'] as String;

      print(
        '📥 Клиент получает метаданные файла от сервера: $fileName (${FileUtils.formatBytes(fileSize)})',
      );

      // Определяем, является ли это групповой передачей
      final isGroupFile =
          transferId.contains('_') && RegExp(r'_\d+$').hasMatch(transferId);
      String groupTransferId = transferId;
      int fileIndex = 0;

      if (isGroupFile) {
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
      if (isGroupFile) {
        groupTransfer = _transferManager.getTransfer(groupTransferId);
        if (groupTransfer != null) {
          print(
            '📊 Найдена групповая передача от сервера: ${groupTransfer.fileName} '
            '(${groupTransfer.completedFiles}/${groupTransfer.totalFiles} файлов, '
            '${FileUtils.formatBytes(groupTransfer.fileSize)})',
          );
        }
      }

      final receiver = FileReceiver(
        transferId: transferId,
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
        tempFile: File(tempPath),
        socket: null,
        onProgress: (progress) {
          print(
            '📥 Прогресс приема $fileName: ${progress.toStringAsFixed(1)}%',
          );
        },
        onComplete: (file) async {
          await _handleFileReceived(
            file: file,
            fileType: fileType,
            fileName: fileName,
            transferId: transferId,
            isGroupFile: isGroupFile,
            groupTransfer: groupTransfer,
            fileIndex: fileIndex,
          );
        },
        onError: (error) {
          print('❌ Ошибка приема файла $fileName: $error');
          _transferManager.closeFileReceiver(transferId);

          if (isGroupFile) {
            print('⚠️ Ошибка в файле ${fileIndex + 1} групповой передачи');
          } else {
            _transferManager.removeTransfer(transferId);
          }
        },
      );

      _transferManager.addFileReceiver(transferId, receiver);

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
            // UI будет обновляться через FileTransferManager
          },
          onComplete: (file) {
            print('✅ Передача от сервера завершена');
          },
          onError: (error) {
            print('❌ Ошибка передачи от сервера: $error');
            _transferManager.removeTransfer(transferId);
          },
          sendMessage: _sendClientMessage,
          totalFiles: 1,
          completedFiles: 0,
        );

        _transferManager.addTransfer(transfer);
        print('✅ Создана передача для одиночного файла: $fileName');
      }

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

  void handleFileChunk(Map<String, dynamic> data) async {
    final transferId = data['transferId'] as String;
    final chunkIndex = data['chunkIndex'] as int;
    final chunkData = data['chunkData'] as String;
    final isLast = data['isLast'] as bool? ?? false;

    // Проверяем, не отменена ли передача
    final receiver = _transferManager.getFileReceiver(transferId);
    if (receiver == null) {
      print('⚠️ Чанк для неизвестной или отмененной передачи: $transferId');
      return;
    }

    try {
      final bytes = base64Decode(chunkData);
      await receiver.writeChunk(bytes);

      // Находим соответствующую передачу
      FileTransfer? transferToUpdate;

      final transfer = _transferManager.getTransfer(transferId);
      if (transfer != null) {
        transferToUpdate = transfer;
      } else if (transferId.contains('_')) {
        final parts = transferId.split('_');
        final lastPart = parts.last;
        if (int.tryParse(lastPart) != null) {
          final groupId = parts.sublist(0, parts.length - 1).join('_');
          transferToUpdate = _transferManager.getTransfer(groupId);
        }
      }

      // Если передача не найдена (возможно отменена), пропускаем обновление
      if (transferToUpdate != null) {
        transferToUpdate.updateProgress(
          transferToUpdate.receivedBytes + bytes.length,
        );

        // Отправляем прогресс серверу
        _sendClientMessage({
          'type': 'progress_update',
          'transferId': transferToUpdate.transferId,
          'progress': transferToUpdate.progress,
          'receivedBytes': transferToUpdate.receivedBytes,
          'totalBytes': transferToUpdate.fileSize,
          'timestamp': DateTime.now().toIso8601String(),
        });
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
      if (!transferId.contains('cancelled')) {
        print('❌ Ошибка обработки чанка от сервера: $e');
      }

      if (_transferManager.getFileReceiver(transferId) != null) {
        receiver.onError(e.toString());
        await _transferManager.closeFileReceiver(transferId);
      }
    }
  }

  void handleProgressUpdate(Map<String, dynamic> data) {
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
          '(${FileUtils.formatBytes(receivedBytes)} / ${FileUtils.formatBytes(totalBytes)})',
        );

        final transfer = _transferManager.getTransfer(transferId);
        if (transfer != null) {
          transfer.updateProgress(receivedBytes);

          print(
            '📊 Обновлен прогресс группы: ${transfer.fileName} '
            '${transfer.receivedBytes}/${transfer.fileSize} байт '
            '(${transfer.progress.toStringAsFixed(1)}%)',
          );
        }
      }
    } catch (e) {
      print('❌ Ошибка обработки прогресса от сервера: $e');
    }
  }

  // MARK: - ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ

  Future<void> _handleFileReceived({
    required File file,
    required String fileType,
    required String fileName,
    required String transferId,
    required bool isGroupFile,
    required FileTransfer? groupTransfer,
    required int fileIndex,
  }) async {
    await _saveToGallery(file, fileType, fileName);
    await _transferManager.closeFileReceiver(transferId);

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
        '(${FileUtils.formatBytes(await file.length())})',
      );

      if (groupTransfer.completedFiles >= groupTransfer.totalFiles) {
        print(
          '🎉 Вся группа от сервера завершена: ${groupTransfer.fileName} '
          '(${groupTransfer.completedFiles} файлов, '
          '${FileUtils.formatBytes(groupTransfer.fileSize)})',
        );

        // Обновляем прогресс до 100%
        groupTransfer.updateProgress(groupTransfer.fileSize);
      }
    } else {
      print('✅ Одиночный файл завершен: $fileName');
    }

    await _mediaManager.addMedia(
      file: file,
      fileName: fileName,
      mimeType: fileType,
      receivedAt: DateTime.now(),
    );
  }

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
        print('💾 Файл сохранен в галерею: $originalName');

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

        // Перемещаем файл из временной директории в постоянную
        try {
          final permanentFile = await _gallerySaver.moveToPermanentDirectory(
            tempFile: file,
            originalName: originalName,
            appDocumentsDirectory: _mediaManager.appDocumentsDirectory!,
            receivedFilesDir: _mediaManager.receivedFilesDir,
          );

          await _mediaManager.updateMediaFile(originalName, permanentFile);
        } catch (e) {
          print('⚠️ Ошибка перемещения файла: $e');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Ошибка сохранения файла: $e');
      print('Stack: $stackTrace');
    }
  }
}
