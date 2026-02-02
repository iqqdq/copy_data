import 'dart:io';

class ReceivedFileInfo {
  final File file;
  final String fileName;
  final String fileType;
  final DateTime receivedAt;
  final String transferId;

  ReceivedFileInfo({
    required this.file,
    required this.fileName,
    required this.fileType,
    required this.receivedAt,
    required this.transferId,
  });
}
