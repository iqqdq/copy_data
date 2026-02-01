import 'dart:io';

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
