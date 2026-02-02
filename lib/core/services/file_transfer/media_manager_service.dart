import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core.dart';

class MediaManagerService extends ChangeNotifier {
  final List<ReceivedMedia> _receivedMedia = [];
  final String _receivedFilesDir = 'ReceivedFiles';
  Directory? _appDocumentsDirectory;

  List<ReceivedMedia> get receivedMedia => List.unmodifiable(_receivedMedia);

  MediaManagerService() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _initializeDirectories();
    await _loadReceivedMedia();
  }

  Future<void> _initializeDirectories() async {
    _appDocumentsDirectory = await getApplicationDocumentsDirectory();
    final receivedDir = Directory(
      path.join(_appDocumentsDirectory!.path, _receivedFilesDir),
    );
    if (!await receivedDir.exists()) {
      await receivedDir.create(recursive: true);
    }
  }

  Future<void> _loadReceivedMedia() async {
    try {
      final mediaDir = Directory(
        path.join(_appDocumentsDirectory!.path, _receivedFilesDir),
      );

      if (await mediaDir.exists()) {
        final files = await mediaDir.list().toList();
        _receivedMedia.clear();

        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            final mimeType =
                lookupMimeType(file.path) ?? 'application/octet-stream';

            if (mimeType.startsWith('image/') ||
                mimeType.startsWith('video/')) {
              _receivedMedia.add(
                ReceivedMedia(
                  file: file,
                  fileName: path.basename(file.path),
                  fileSize: stat.size,
                  mimeType: mimeType,
                  receivedAt: stat.modified,
                ),
              );
            }
          }
        }

        _receivedMedia.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
        notifyListeners();
      }
    } catch (e) {
      print('❌ Ошибка загрузки списка медиа: $e');
    }
  }

  Future<void> addMedia({
    required File file,
    required String fileName,
    required String mimeType,
    required DateTime receivedAt,
  }) async {
    try {
      // Проверяем, существует ли файл
      if (!await file.exists()) {
        print('❌ Файл не существует при добавлении в медиа: ${file.path}');
        return;
      }

      final fileSize = await file.length();

      final media = ReceivedMedia(
        file: file,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        receivedAt: receivedAt,
      );

      _receivedMedia.add(media);
      notifyListeners();

      print('✅ Медиа добавлено: $fileName ($fileSize байт)');
    } catch (e) {
      print('❌ Ошибка добавления медиа: $e');
    }
  }

  Future<bool> deleteMedia(ReceivedMedia media) async {
    try {
      if (await media.file.exists()) {
        await media.file.delete();
        _receivedMedia.remove(media);
        notifyListeners();
        print('🗑️ Медиа удалено: ${media.fileName}');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Ошибка удаления медиа: $e');
      return false;
    }
  }

  Future<void> updateMediaFile(String fileName, File newFile) async {
    try {
      final existingMediaIndex = _receivedMedia.indexWhere(
        (m) => m.fileName == fileName,
      );

      if (existingMediaIndex != -1) {
        final existingMedia = _receivedMedia[existingMediaIndex];
        if (existingMedia.file.path != newFile.path) {
          print('🔄 Обновляю путь к файлу: ${newFile.path}');

          // Создаем обновленную копию медиа
          final updatedMedia = ReceivedMedia(
            file: newFile,
            fileName: existingMedia.fileName,
            fileSize: await newFile.length(),
            mimeType: lookupMimeType(newFile.path) ?? existingMedia.mimeType,
            receivedAt: existingMedia
                .receivedAt, // Сохраняем оригинальное время получения
          );

          _receivedMedia[existingMediaIndex] = updatedMedia;
          notifyListeners();
        }
      } else {
        // Если медиа не найдено, добавляем новое
        await addMedia(
          file: newFile,
          fileName: fileName,
          mimeType: lookupMimeType(newFile.path) ?? 'application/octet-stream',
          receivedAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('❌ Ошибка обновления медиа: $e');
    }
  }

  Future<void> refreshMedia() async {
    await _loadReceivedMedia();
  }

  Future<String> getMediaDirectoryPath() async {
    if (_appDocumentsDirectory == null) {
      await _initializeDirectories();
    }
    return path.join(_appDocumentsDirectory!.path, _receivedFilesDir);
  }

  Directory? get appDocumentsDirectory => _appDocumentsDirectory;
  String get receivedFilesDir => _receivedFilesDir;
}
