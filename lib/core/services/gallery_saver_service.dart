import 'dart:io';
import 'dart:typed_data';

import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path/path.dart' as path;

class GallerySaverService {
  Future<GallerySaveResult> saveToGallery({
    required File file,
    required String mimeType,
    required String originalName,
  }) async {
    try {
      print('💾 Сохранение в галерею: ${file.path}');
      print('📝 Имя файла: $originalName');

      bool isSaved = false;
      String? savedPath;
      String? errorMessage;

      if (mimeType.startsWith('image/')) {
        final result = await _saveImageToGallery(file, originalName);
        isSaved = result.isSaved;
        savedPath = result.savedPath;
        errorMessage = result.errorMessage;
      } else if (mimeType.startsWith('video/')) {
        final result = await _saveVideoToGallery(file, originalName);
        isSaved = result.isSaved;
        savedPath = result.savedPath;
        errorMessage = result.errorMessage;
      }

      return GallerySaveResult(
        isSaved: isSaved,
        savedPath: savedPath,
        errorMessage: errorMessage,
        fileSize: await file.length(),
      );
    } catch (e, stackTrace) {
      print('❌ Критическая ошибка сохранения в галерею: $e');
      print('Stack: $stackTrace');

      return GallerySaveResult(
        isSaved: false,
        errorMessage: e.toString(),
        fileSize: await file.length(),
      );
    }
  }

  Future<GallerySaveResult> _saveImageToGallery(
    File file,
    String originalName,
  ) async {
    try {
      final bytes = await file.readAsBytes();
      print('🖼️ Размер изображения: ${bytes.length} байт');

      if (Platform.isIOS) {
        return await _saveImageIOS(bytes, originalName);
      } else {
        return await _saveImageAndroid(bytes, originalName);
      }
    } catch (e) {
      print('❌ Ошибка при сохранении изображения: $e');
      return GallerySaveResult(isSaved: false, errorMessage: e.toString());
    }
  }

  Future<GallerySaveResult> _saveImageIOS(
    List<int> bytes,
    String originalName,
  ) async {
    final result = await ImageGallerySaverPlus.saveImage(
      Uint8List.fromList(bytes),
      name: originalName,
      quality: 100,
      isReturnImagePathOfIOS: true,
    );

    print('📱 Результат сохранения на iOS: $result');

    if (result is Map) {
      final success = result['isSuccess'] as bool? ?? false;
      final filePath = result['filePath'] as String?;
      if (success) {
        print('✅ Изображение сохранено в галерею iOS: $originalName');
        if (filePath != null) {
          print('📁 Путь: $filePath');
        }
        return GallerySaveResult(isSaved: true, savedPath: filePath);
      } else {
        print('❌ Ошибка при сохранении изображения на iOS');
        return GallerySaveResult(isSaved: false);
      }
    } else if (result is bool) {
      if (result) {
        print('✅ Изображение сохранено в галерею iOS: $originalName');
        return GallerySaveResult(isSaved: true);
      } else {
        print('❌ Ошибка при сохранении изображения на iOS');
        return GallerySaveResult(isSaved: false);
      }
    }

    return GallerySaveResult(isSaved: false);
  }

  Future<GallerySaveResult> _saveImageAndroid(
    List<int> bytes,
    String originalName,
  ) async {
    final result = await ImageGallerySaverPlus.saveImage(
      Uint8List.fromList(bytes),
      name: originalName,
      quality: 100,
    );

    print('📱 Результат сохранения на Android: $result');

    if (result is Map) {
      final success = result['isSuccess'] as bool? ?? false;
      if (success) {
        print('✅ Изображение сохранено в галерею Android: $originalName');
        return GallerySaveResult(isSaved: true);
      }
    } else if (result is bool && result) {
      print('✅ Изображение сохранено в галерею Android: $originalName');
      return GallerySaveResult(isSaved: true);
    }

    return GallerySaveResult(isSaved: false);
  }

  Future<GallerySaveResult> _saveVideoToGallery(
    File file,
    String originalName,
  ) async {
    try {
      print('🎥 Размер видео файла: ${await file.length()} байт');

      if (Platform.isIOS) {
        return await _saveVideoIOS(file, originalName);
      } else {
        return await _saveVideoAndroid(file, originalName);
      }
    } catch (e) {
      print('❌ Ошибка при сохранении видео: $e');
      return GallerySaveResult(isSaved: false, errorMessage: e.toString());
    }
  }

  Future<GallerySaveResult> _saveVideoIOS(
    File file,
    String originalName,
  ) async {
    final result = await ImageGallerySaverPlus.saveFile(
      file.path,
      name: originalName,
      isReturnPathOfIOS: true,
    );

    print('📱 Результат сохранения видео на iOS: $result');

    if (result is Map) {
      final success = result['isSuccess'] as bool? ?? false;
      final filePath = result['filePath'] as String?;
      if (success) {
        print('✅ Видео сохранено в галерею iOS: $originalName');
        if (filePath != null) {
          print('📁 Путь: $filePath');
        }
        return GallerySaveResult(isSaved: true, savedPath: filePath);
      } else {
        print('❌ Ошибка при сохранении видео на iOS');
        return GallerySaveResult(isSaved: false);
      }
    }

    return GallerySaveResult(isSaved: false);
  }

  Future<GallerySaveResult> _saveVideoAndroid(
    File file,
    String originalName,
  ) async {
    final result = await ImageGallerySaverPlus.saveFile(
      file.path,
      name: originalName,
    );

    print('📱 Результат сохранения видео на Android: $result');

    if (result is Map) {
      final success = result['isSuccess'] as bool? ?? false;
      if (success) {
        print('✅ Видео сохранено в галерею Android: $originalName');
        return GallerySaveResult(isSaved: true);
      }
    }

    return GallerySaveResult(isSaved: false);
  }

  Future<File> moveToPermanentDirectory({
    required File tempFile,
    required String originalName,
    required Directory appDocumentsDirectory,
    required String receivedFilesDir,
  }) async {
    try {
      final permanentDir = Directory(
        path.join(appDocumentsDirectory.path, receivedFilesDir),
      );

      if (!await permanentDir.exists()) {
        await permanentDir.create(recursive: true);
      }

      final permanentPath = path.join(permanentDir.path, originalName);
      await tempFile.copy(permanentPath);
      await tempFile.delete();

      print('📁 Файл перемещен в постоянную директорию: $permanentPath');

      return File(permanentPath);
    } catch (e) {
      print('⚠️ Ошибка перемещения файла: $e');
      rethrow;
    }
  }
}

class GallerySaveResult {
  final bool isSaved;
  final String? savedPath;
  final String? errorMessage;
  final int? fileSize;

  GallerySaveResult({
    required this.isSaved,
    this.savedPath,
    this.errorMessage,
    this.fileSize,
  });
}
