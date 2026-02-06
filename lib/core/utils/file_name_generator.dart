import 'dart:math';

import 'package:uuid/uuid.dart';

class FileNameGenerator {
  static String generateUniqueFileName(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    final extension = _getExtension(originalName);
    final nameWithoutExtension = _getNameWithoutExtension(originalName);

    return '${nameWithoutExtension}_${timestamp}_$random$extension';
  }

  static String _getExtension(String fileName) {
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex != -1) {
      return fileName.substring(lastDotIndex);
    }
    return '';
  }

  static String _getNameWithoutExtension(String fileName) {
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex != -1) {
      return fileName.substring(0, lastDotIndex);
    }
    return fileName;
  }

  // Альтернативный вариант с UUID
  static String generateUniqueFileNameWithUuid(String originalName) {
    final uuid = const Uuid().v4().substring(0, 8); // Первые 8 символов UUID
    final extension = _getExtension(originalName);
    final nameWithoutExtension = _getNameWithoutExtension(originalName);

    return '${nameWithoutExtension}_$uuid$extension';
  }

  // Еще один вариант - короткое имя с временной меткой
  static String generateShortUniqueName(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(8);
    final extension = _getExtension(originalName);
    return '$timestamp$extension';
  }
}
