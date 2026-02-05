import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

class FileReceiver {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String fileType;
  final void Function(int receivedBytes) onProgress;
  final void Function(File file) onComplete;
  final void Function(String error) onError;

  File? _tempFile;
  IOSink? _sink;
  int _receivedBytes = 0;
  bool _isComplete = false;

  int get receivedBytes => _receivedBytes;

  FileReceiver({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.fileType,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  }) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final tempDir = Directory.systemTemp;
      final tempPath = path.join(tempDir.path, 'transfer_$transferId');
      _tempFile = File(tempPath);
      _sink = _tempFile!.openWrite(mode: FileMode.writeOnlyAppend);

      print('📁 Создан временный файл для приема: $fileName');
    } catch (e) {
      onError('Ошибка инициализации приемника: $e');
    }
  }

  void receiveChunk(String chunkData, bool isLast) {
    try {
      if (_sink == null || _isComplete) return;

      final bytes = base64Decode(chunkData);
      _sink!.add(bytes);
      _receivedBytes += bytes.length;

      onProgress(_receivedBytes);

      if (isLast || _receivedBytes >= fileSize) {
        _finalizeFile();
      }
    } catch (e) {
      onError('Ошибка получения чанка: $e');
    }
  }

  Future<void> _finalizeFile() async {
    try {
      if (_sink != null) {
        await _sink!.flush();
        await _sink!.close();
        _sink = null;
      }

      _isComplete = true;

      if (_tempFile != null && await _tempFile!.exists()) {
        final actualSize = await _tempFile!.length();

        if (actualSize == fileSize || fileSize == 0) {
          print('✅ Файл полностью получен: $fileName ($actualSize байт)');
          onComplete(_tempFile!);
        } else {
          onError(
            'Несоответствие размера файла: ожидалось $fileSize, получено $actualSize',
          );
        }
      } else {
        onError('Временный файл не существует');
      }
    } catch (e) {
      onError('Ошибка финализации файла: $e');
    }
  }

  Future<void> close() async {
    try {
      if (_sink != null) {
        await _sink!.flush();
        await _sink!.close();
        _sink = null;
      }

      if (_tempFile != null && await _tempFile!.exists()) {
        await _tempFile!.delete();
      }
    } catch (e) {
      print('⚠️ Ошибка закрытия FileReceiver: $e');
    }
  }
}
