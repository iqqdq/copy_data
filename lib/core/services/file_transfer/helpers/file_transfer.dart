import 'dart:io';
import 'package:flutter/foundation.dart';

class FileTransfer with ChangeNotifier {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String fileType;
  final File file;
  final String targetPath;

  final void Function(double progress) onProgress;
  final void Function(File file) onComplete;
  final void Function(String error) onError;
  final void Function(Map<String, dynamic> message) sendMessage;

  final int totalFiles;
  int completedFiles;

  int receivedBytes = 0;

  // Флаг, чтобы onComplete вызывался только один раз
  bool _hasCompleted = false;

  double get progress {
    if (fileSize == 0) return 0.0;
    return (receivedBytes / fileSize * 100).clamp(0.0, 100.0);
  }

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
    required this.totalFiles,
    required this.completedFiles,
  });

  void updateProgress(int newReceivedBytes) {
    if (_hasCompleted) return; // Если уже завершено, не обновляем

    receivedBytes = newReceivedBytes;

    // Если прогресс достиг 100% и еще не вызывали onComplete
    if (receivedBytes >= fileSize && !_hasCompleted) {
      _hasCompleted = true;

      // Вызываем с небольшой задержкой, чтобы избежать повторных вызовов
      Future.delayed(Duration(milliseconds: 100), () {
        if (!_hasCompleted) return; // Дополнительная проверка
        print('🎯 Вызов onComplete для передачи: $transferId');
        onComplete(file);
      });
    }

    // Обновляем UI через callback
    onProgress(progress);

    notifyListeners();
  }

  // Метод для явного завершения
  void markAsCompleted() {
    if (!_hasCompleted) {
      _hasCompleted = true;
      receivedBytes = fileSize; // Устанавливаем 100%
      onComplete(file);
      notifyListeners();
    }
  }

  // НОВЫЙ МЕТОД: Создание копии объекта
  FileTransfer copy() {
    return FileTransfer(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
      file: file,
      targetPath: targetPath,
      onProgress: onProgress,
      onComplete: onComplete,
      onError: onError,
      sendMessage: sendMessage,
      totalFiles: totalFiles,
      completedFiles: completedFiles,
    )..receivedBytes = receivedBytes;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileTransfer && other.transferId == transferId;
  }

  @override
  int get hashCode => transferId.hashCode;
}
