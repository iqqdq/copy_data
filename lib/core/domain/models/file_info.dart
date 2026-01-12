class FileInfo {
  final String id;
  final String name;
  String path;
  final int size;
  final String hash;
  final String mimeType;
  final DateTime modifiedDate;
  FileTransferStatus status;
  double progress;
  String? transferId;
  String? destinationDevice;

  FileInfo({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.hash,
    required this.mimeType,
    required this.modifiedDate,
    this.status = FileTransferStatus.pending,
    this.progress = 0,
    this.transferId,
    this.destinationDevice,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}

enum FileTransferStatus {
  pending,
  transferring,
  completed,
  failed,
  paused,
  cancelled,
}
