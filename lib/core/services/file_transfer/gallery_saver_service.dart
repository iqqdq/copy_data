import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';

class GallerySaverService {
  final Map<String, int> _fileNameCounters = {};

  Future<GallerySaveResult> saveToGallery({
    required File file,
    required String mimeType,
    required String originalName,
  }) async {
    try {
      // Проверяем существует ли файл
      if (!await file.exists()) {
        print('❌ Файл не существует: ${file.path}');
        return GallerySaveResult(
          isSaved: false,
          errorMessage: 'File does not exist',
          fileSize: 0,
          originalName: originalName,
        );
      }

      // Получаем размер файла
      final fileSize = await file.length();

      // Получаем оригинальное расширение
      final originalExtension = _getFileExtension(originalName);

      // Генерируем уникальное имя С ОРИГИНАЛЬНЫМ РАСШИРЕНИЕМ
      final uniqueFileName = _generateUniqueFileNameWithOriginalExtension(
        originalName,
      );

      bool isSaved = false;
      String? savedPath;
      String? errorMessage;

      if (mimeType.startsWith('image/')) {
        final result = await _saveImageToGallery(file, uniqueFileName);
        isSaved = result.isSaved;
        savedPath = result.savedPath;
        errorMessage = result.errorMessage;
      } else if (mimeType.startsWith('video/')) {
        final result = await _saveVideoToGallery(
          file,
          uniqueFileName,
          originalExtension,
        );
        isSaved = result.isSaved;
        savedPath = result.savedPath;
        errorMessage = result.errorMessage;
      }

      return GallerySaveResult(
        isSaved: isSaved,
        savedPath: savedPath,
        errorMessage: errorMessage,
        fileSize: fileSize,
        originalName: originalName,
        savedName: uniqueFileName,
      );
    } catch (e, _) {
      print('❌ Ошибка сохранения в галерею: $e');

      return GallerySaveResult(
        isSaved: false,
        errorMessage: e.toString(),
        fileSize: 0,
        originalName: originalName,
      );
    }
  }

  // Основной метод генерации уникального имени С ОРИГИНАЛЬНЫМ РАСШИРЕНИЕМ
  String _generateUniqueFileNameWithOriginalExtension(String originalName) {
    final originalExtension = _getFileExtension(originalName);
    final nameWithoutExtension = _getFileNameWithoutExtension(originalName);

    // Убираем лишние символы и префиксы
    String baseName = _cleanFileName(nameWithoutExtension);

    // Если имя пустое, используем тип файла
    if (baseName.isEmpty) {
      baseName = _getFileTypePrefix(originalExtension);
    }

    // Генерируем уникальный суффикс
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final timeSuffix = timestamp.length > 8
        ? timestamp.substring(timestamp.length - 8)
        : timestamp;
    final randomSuffix = Random().nextInt(9999).toString().padLeft(4, '0');

    // Используем счетчик
    final counterKey = originalName;
    _fileNameCounters[counterKey] = (_fileNameCounters[counterKey] ?? 0) + 1;
    final counter = _fileNameCounters[counterKey]!;

    // Формируем окончательное имя
    final uniqueName =
        '${baseName}_${timeSuffix}_${counter}_$randomSuffix$originalExtension';

    return uniqueName;
  }

  // Очистка имени файла от ненужных префиксов
  String _cleanFileName(String fileName) {
    String cleaned = fileName;

    final uuidPattern = RegExp(
      r'^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}',
      caseSensitive: false,
    );
    if (uuidPattern.hasMatch(cleaned)) {
      // Находим где заканчивается UUID
      final match = uuidPattern.firstMatch(cleaned);
      if (match != null) {
        cleaned = cleaned.substring(match.end).trim();
        // Убираем подчеркивания или дефисы
        cleaned = cleaned.replaceAll(RegExp(r'^[_-]+'), '');
      }
    }

    // Убираем стандартные префиксы
    const prefixes = [
      'image_picker_',
      'IMG_',
      'VID_',
      'PXL_',
      'Screenshot_',
      'Screen_Recording_',
      'DCIM_',
      'output_',
      'temp_',
      'tmp_',
    ];

    for (final prefix in prefixes) {
      if (cleaned.toLowerCase().startsWith(prefix.toLowerCase())) {
        cleaned = cleaned.substring(prefix.length);
        break; // Удаляем первый найденный префикс
      }
    }

    // Ограничиваем длину имени
    if (cleaned.length > 30) {
      cleaned = cleaned.substring(0, 30);
    }

    // Убираем спецсимволы, оставляем только буквы, цифры, подчеркивания и дефисы
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\-]'), '_');

    // Если после очистки имя пустое, возвращаем пустую строку
    return cleaned.isEmpty ? '' : cleaned;
  }

  String _getFileTypePrefix(String extension) {
    if (extension == '.mov' ||
        extension == '.mp4' ||
        extension == '.avi' ||
        extension == '.mkv' ||
        extension == '.m4v' ||
        extension == '.3gp') {
      return 'video';
    } else if (extension == '.jpg' ||
        extension == '.jpeg' ||
        extension == '.png' ||
        extension == '.gif' ||
        extension == '.bmp' ||
        extension == '.webp') {
      return 'photo';
    } else if (extension == '.pdf') {
      return 'document';
    } else {
      return 'file';
    }
  }

  String _getFileExtension(String fileName) {
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex == -1) return '';

    final ext = fileName.substring(lastDotIndex).toLowerCase();

    // Проверяем, что расширение не содержит странных символов
    final extWithoutDot = ext.substring(1);
    if (extWithoutDot.isEmpty ||
        !RegExp(r'^[a-z0-9]+$').hasMatch(extWithoutDot)) {
      return '';
    }

    return ext;
  }

  String _getFileNameWithoutExtension(String fileName) {
    final lastDotIndex = fileName.lastIndexOf('.');
    return lastDotIndex != -1 ? fileName.substring(0, lastDotIndex) : fileName;
  }

  Future<GallerySaveResult> _saveVideoIOS(
    File file,
    String uniqueFileName,
    String originalExtension,
  ) async {
    try {
      print('⚠️ Сохранение видео на iOS: $uniqueFileName');

      // Для iOS видео копируем файл во временную директорию с правильным именем
      // Получаем временную директорию
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$uniqueFileName');

      // Копируем файл с правильным именем
      await file.copy(tempFile.path);

      // Теперь сохраняем через системный диалог
      final result = await ImageGallerySaverPlus.saveFile(
        tempFile.path,
        name: uniqueFileName,
        isReturnPathOfIOS: true,
      );

      // Удаляем временный файл
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        print('⚠️ Не удалось удалить временный файл: $e');
      }

      if (result is Map) {
        final success = result['isSuccess'] as bool? ?? false;
        final filePath = result['filePath'] as String?;

        if (success) {
          return GallerySaveResult(
            isSaved: true,
            savedPath: filePath,
            originalName: uniqueFileName,
          );
        }
      }

      print('❌ Не удалось сохранить видео на iOS через библиотеку');

      return GallerySaveResult(
        isSaved: false,
        errorMessage: 'Could not save video on iOS',
        originalName: uniqueFileName,
      );
    } catch (e, stackTrace) {
      print('❌ Ошибка при сохранении видео: $e');
      print('Stack: $stackTrace');

      return GallerySaveResult(
        isSaved: false,
        errorMessage: e.toString(),
        originalName: uniqueFileName,
      );
    }
  }

  Future<GallerySaveResult> _saveImageToGallery(
    File file,
    String uniqueFileName,
  ) async {
    try {
      final bytes = await file.readAsBytes();

      if (Platform.isIOS) {
        return await _saveImageIOS(bytes, uniqueFileName);
      } else {
        return await _saveImageAndroid(bytes, uniqueFileName);
      }
    } catch (e, stackTrace) {
      print('❌ Ошибка при сохранении изображения: $e');
      print('Stack: $stackTrace');
      return GallerySaveResult(
        isSaved: false,
        errorMessage: e.toString(),
        originalName: uniqueFileName,
      );
    }
  }

  Future<GallerySaveResult> _saveImageIOS(
    List<int> bytes,
    String uniqueFileName,
  ) async {
    try {
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(bytes),
        name: uniqueFileName,
        quality: 100,
        isReturnImagePathOfIOS: true,
      );

      if (result is Map) {
        final success = result['isSuccess'] as bool? ?? false;
        final filePath = result['filePath'] as String?;

        if (success) {
          return GallerySaveResult(
            isSaved: true,
            savedPath: filePath,
            originalName: uniqueFileName,
          );
        }
      }

      print('❌ Ошибка при сохранении изображения на iOS');
      return GallerySaveResult(
        isSaved: false,
        errorMessage: 'Failed to save image',
        originalName: uniqueFileName,
      );
    } catch (e, stackTrace) {
      print('❌ Ошибка сохранения изображения на iOS: $e');
      print('Stack: $stackTrace');
      return GallerySaveResult(
        isSaved: false,
        errorMessage: e.toString(),
        originalName: uniqueFileName,
      );
    }
  }

  Future<GallerySaveResult> _saveImageAndroid(
    List<int> bytes,
    String uniqueFileName,
  ) async {
    try {
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(bytes),
        name: uniqueFileName,
        quality: 100,
      );

      if (result is Map) {
        final success = result['isSuccess'] as bool? ?? false;
        if (success) {
          return GallerySaveResult(isSaved: true, originalName: uniqueFileName);
        }
      }

      print('❌ Ошибка при сохранении изображения на Android');
      return GallerySaveResult(
        isSaved: false,
        errorMessage: 'Failed to save image',
        originalName: uniqueFileName,
      );
    } catch (e, _) {
      print('❌ Ошибка сохранения изображения на Android: $e');
      return GallerySaveResult(
        isSaved: false,
        errorMessage: e.toString(),
        originalName: uniqueFileName,
      );
    }
  }

  Future<GallerySaveResult> _saveVideoToGallery(
    File file,
    String uniqueFileName,
    String originalExtension,
  ) async {
    try {
      if (Platform.isIOS) {
        return await _saveVideoIOS(file, uniqueFileName, originalExtension);
      } else {
        return await _saveVideoAndroid(file, uniqueFileName);
      }
    } catch (e, _) {
      print('❌ Ошибка при сохранении видео: $e');
      return GallerySaveResult(
        isSaved: false,
        errorMessage: e.toString(),
        originalName: uniqueFileName,
      );
    }
  }

  Future<GallerySaveResult> _saveVideoAndroid(
    File file,
    String uniqueFileName,
  ) async {
    try {
      final result = await ImageGallerySaverPlus.saveFile(
        file.path,
        name: uniqueFileName,
      );

      if (result is Map) {
        final success = result['isSuccess'] as bool? ?? false;
        if (success) {
          return GallerySaveResult(isSaved: true, originalName: uniqueFileName);
        }
      }

      print('❌ Ошибка при сохранении видео на Android');
      return GallerySaveResult(
        isSaved: false,
        errorMessage: 'Failed to save video',
        originalName: uniqueFileName,
      );
    } catch (e, _) {
      print('❌ Ошибка при сохранении видео на Android: $e');
      return GallerySaveResult(
        isSaved: false,
        errorMessage: e.toString(),
        originalName: uniqueFileName,
      );
    }
  }

  void clearCounters() {
    _fileNameCounters.clear();
  }
}

class GallerySaveResult {
  final bool isSaved;
  final String? savedPath;
  final String? errorMessage;
  final int? fileSize;
  final String originalName;
  final String? savedName;

  GallerySaveResult({
    required this.isSaved,
    this.savedPath,
    this.errorMessage,
    this.fileSize,
    required this.originalName,
    this.savedName,
  });
}
