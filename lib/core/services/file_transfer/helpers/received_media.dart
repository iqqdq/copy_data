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
}
