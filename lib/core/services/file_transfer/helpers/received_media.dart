import 'dart:io';

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
