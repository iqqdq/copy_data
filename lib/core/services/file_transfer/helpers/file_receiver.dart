import 'dart:io';

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
