import 'dart:async';
import 'dart:io';

import '../../core.dart';

class ClientFileReceiverService {
  final GallerySaverService _gallerySaver;
  final FileTransferManager _transferManager;
  final Future<void> Function(Map<String, dynamic> message) sendClientMessage;

  // Для отслеживания индексов файлов в группе
  final Map<String, int> _currentFileIndices = {};
  final Map<String, List<String>> _receivedFiles = {};
  final Map<String, int> _savedFilesCount = {}; // Счетчик сохраненных файлов
  final Map<String, Completer<void>> _groupCompleters =
      {}; // Для ожидания завершения группы

  ClientFileReceiverService({
    required GallerySaverService gallerySaver,
    required FileTransferManager transferManager,
    required this.sendClientMessage,
  }) : _gallerySaver = gallerySaver,
       _transferManager = transferManager;

  void handleGroupMetadata(Map<String, dynamic> data) {
    try {
      final transferId = data['transferId'] as String?;
      final totalFiles = data['totalFiles'] as int?;
      final fileName = data['fileName'] as String?;
      final totalSize = data['totalSize'] as int?;
      final fileType = data['fileType'] as String?;

      if (transferId != null && totalFiles != null && totalSize != null) {
        // Сбрасываем индекс для новой группы
        _currentFileIndices[transferId] = 0;
        _receivedFiles[transferId] = [];
        _savedFilesCount[transferId] = 0;
        _groupCompleters[transferId] = Completer<void>();

        // Создаем передачу для группы
        final transfer = FileTransfer(
          transferId: transferId,
          fileName: fileName ?? 'Группа файлов',
          fileSize: totalSize,
          fileType: fileType ?? 'application/octet-stream',
          file: File(''), // Временный файл
          targetPath: '',
          onProgress: (progress) {
            // UI обновится через notifyListeners
          },
          onComplete: (file) async {
            print('✅ Группа завершена: $transferId');
            // Ждем завершения всех файлов
            await _groupCompleters[transferId]?.future;
            print('✅ Все файлы в группе $transferId обработаны');
          },
          onError: (error) {
            print('❌ Ошибка в группе: $error');
            _groupCompleters[transferId]?.completeError(error);
          },
          sendMessage: sendClientMessage,
          totalFiles: totalFiles,
          completedFiles: 0,
        );

        _transferManager.addTransfer(transfer);
      }
    } catch (e) {
      print('❌ Ошибка обработки метаданных группы: $e');
    }
  }

  void handleFileMetadata(Map<String, dynamic> data) async {
    try {
      final transferId = data['transferId'] as String?;
      final fileName = data['fileName'] as String?;
      final fileSize = data['fileSize'] as int?;
      final fileType = data['fileType'] as String?;

      if (transferId != null && fileName != null && fileSize != null) {
        print(
          '📄 Получены метаданные файла: $fileName (${FileUtils.formatBytes(fileSize)})',
        );

        // Определяем групповой transferId (убираем суффикс _index)
        final groupTransferId = transferId.contains('_')
            ? transferId.substring(0, transferId.lastIndexOf('_'))
            : transferId;

        // Увеличиваем индекс файла в группе
        final currentIndex = _currentFileIndices[groupTransferId] ?? 0;

        // Создаем FileReceiver для этого файла
        final fileReceiver = FileReceiver(
          transferId: transferId,
          fileName: fileName,
          fileSize: fileSize,
          fileType: fileType ?? 'application/octet-stream',
          onProgress: (receivedBytes) {
            final transfer = _transferManager.getTransfer(groupTransferId);
            if (transfer != null) {
              transfer.updateProgress(receivedBytes);
            }
          },
          onComplete: (file) async {
            await _handleFileComplete(
              file,
              fileName,
              fileType ?? 'application/octet-stream',
              groupTransferId,
              currentIndex,
            );
          },
          onError: (error) {
            print('❌ Ошибка получения файла: $error');
            // Даже при ошибке увеличиваем индекс
            _currentFileIndices[groupTransferId] = currentIndex + 1;
          },
        );

        _transferManager.addFileReceiver(transferId, fileReceiver);

        // Подтверждаем получение метаданных
        await sendClientMessage({
          'type': 'metadata_ack',
          'transferId': transferId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('❌ Ошибка обработки метаданных файла: $e');
    }
  }

  void handleFileChunk(Map<String, dynamic> data) {
    try {
      final transferId = data['transferId'] as String?;
      final chunkData = data['chunkData'] as String?;
      final isLast = data['isLast'] as bool? ?? false;

      if (transferId != null && chunkData != null) {
        final fileReceiver = _transferManager.getFileReceiver(transferId);
        if (fileReceiver != null) {
          fileReceiver.receiveChunk(chunkData, isLast);
        }
      }
    } catch (e) {
      print('❌ Ошибка обработки чанка файла: $e');
    }
  }

  Future<void> _handleFileComplete(
    File file,
    String fileName,
    String fileType,
    String groupTransferId,
    int fileIndex,
  ) async {
    try {
      // Сохраняем файл в галерею с уникальным именем
      final saveResult = await _gallerySaver.saveToGallery(
        file: file,
        mimeType: fileType,
        originalName: fileName,
      );

      // Используем savedName из результата для логов
      final savedFileName = saveResult.savedName ?? fileName;

      if (saveResult.isSaved) {
        print(
          '✅ Файл сохранен в галерею: $savedFileName (оригинальное: $fileName)',
        );

        if (saveResult.savedPath != null) {
          print('\nПуть сохранения: ${saveResult.savedPath}');
        }

        // Обновляем счетчик файлов на клиенте
        final transfer = _transferManager.getTransfer(groupTransferId);
        if (transfer != null) {
          // Увеличиваем счетчик сохраненных файлов
          final currentCount = _savedFilesCount[groupTransferId] ?? 0;
          _savedFilesCount[groupTransferId] = currentCount + 1;

          // Обновляем счетчик в transfer
          transfer.completedFiles = _savedFilesCount[groupTransferId]!;
        }

        // Отправляем подтверждение на сервер с обоими именами
        await sendClientMessage({
          'type': 'file_saved',
          'transferId': groupTransferId,
          'fileIndex': fileIndex,
          'originalName': fileName,
          'savedName': savedFileName,
          'savedPath': saveResult.savedPath,
          'fileSize': saveResult.fileSize,
          'success': true,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        print('❌ Не удалось сохранить файл в галерею: $fileName');
        if (saveResult.errorMessage != null) {
          print('\nПричина: ${saveResult.errorMessage}');
        }

        await sendClientMessage({
          'type': 'file_saved',
          'transferId': groupTransferId,
          'fileIndex': fileIndex,
          'originalName': fileName,
          'success': false,
          'error': saveResult.errorMessage ?? 'Unknown error',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Обновляем индекс для следующего файла
      _currentFileIndices[groupTransferId] = fileIndex + 1;

      // Сохраняем информацию о полученном файле
      _receivedFiles[groupTransferId]?.add(fileName);

      // Отправляем сообщение о получении файла
      await sendClientMessage({
        'type': 'file_received',
        'transferId': groupTransferId,
        'fileName': fileName,
        'savedFileName': savedFileName,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Проверяем, все ли файлы в группе обработаны
      final totalFiles =
          _transferManager.getTransfer(groupTransferId)?.totalFiles ?? 0;
      final savedFiles = _savedFilesCount[groupTransferId] ?? 0;

      if (savedFiles >= totalFiles) {
        print('✅ Все $totalFiles файлов в группе $groupTransferId обработаны');
        _groupCompleters[groupTransferId]?.complete();

        // Очищаем временные данные группы
        _cleanupGroupData(groupTransferId);
      }
    } catch (e, _) {
      print('❌ Ошибка при сохранении файла в галерею: $e');

      await sendClientMessage({
        'type': 'file_saved',
        'transferId': groupTransferId,
        'fileIndex': fileIndex,
        'originalName': fileName,
        'success': false,
        'error': 'Critical error: ${e.toString()}',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void _cleanupGroupData(String groupTransferId) {
    // Очищаем данные группы
    Future.delayed(Duration(seconds: 5), () {
      _currentFileIndices.remove(groupTransferId);
      _receivedFiles.remove(groupTransferId);
      _savedFilesCount.remove(groupTransferId);
      _groupCompleters.remove(groupTransferId);
    });
  }

  void handleProgressUpdate(Map<String, dynamic> data) {
    try {
      final transferId = data['transferId'] as String?;
      final progress = data['progress'] as double?;
      final receivedBytes = data['receivedBytes'] as int?;
      final totalBytes = data['totalBytes'] as int?;

      if (transferId != null && progress != null) {
        final transfer = _transferManager.getTransfer(transferId);
        if (transfer != null) {
          // Обновляем прогресс на основе данных от сервера
          if (receivedBytes != null && totalBytes != null) {
            transfer.updateProgress(receivedBytes);
          }

          // Отправляем подтверждение прогресса
          _sendProgressUpdate(
            transferId,
            progress,
            receivedBytes ?? 0,
            totalBytes ?? 0,
          );
        }
      }
    } catch (e) {
      print('❌ Ошибка обработки обновления прогресса: $e');
    }
  }

  Future<void> _sendProgressUpdate(
    String transferId,
    double progress,
    int receivedBytes,
    int totalBytes,
  ) async {
    try {
      await sendClientMessage({
        'type': 'progress_update',
        'transferId': transferId,
        'progress': progress,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Ошибка отправки обновления прогресса: $e');
    }
  }
}
