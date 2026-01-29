class FileUtils {
  FileUtils._();

  static String formatBytes(int bytes, int totalBytes, {bool showBoth = true}) {
    // Определяем единицу измерения на основе общего размера
    String unit;
    double bytesValue;
    double totalValue;

    if (totalBytes >= 1024 * 1024) {
      unit = 'MB';
      bytesValue = bytes / (1024 * 1024);
      totalValue = totalBytes / (1024 * 1024);
    } else if (totalBytes >= 1024) {
      unit = 'KB';
      bytesValue = bytes / 1024;
      totalValue = totalBytes / 1024;
    } else {
      unit = 'B';
      bytesValue = bytes.toDouble();
      totalValue = totalBytes.toDouble();
    }

    // Форматируем значения с точностью
    final formattedBytes = _formatValue(bytesValue, unit);
    final formattedTotal = _formatValue(totalValue, unit);

    if (showBoth) {
      return '$formattedBytes / $formattedTotal';
    } else {
      return formattedTotal;
    }
  }

  static String _formatValue(double value, String unit) {
    if (unit == 'B') {
      // Для байтов показываем целое число
      return '${value.toInt()} $unit';
    } else {
      // Для KB и MB показываем 2 знака после запятой
      return '${value.toStringAsFixed(2)} $unit';
    }
  }

  // Дополнительные утилиты для работы с файлами
  static String getFileSizeString(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '$bytes B';
    }
  }
}
