import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FileOpener {
  // Открыть файл любым доступным способом
  static Future<void> openFile(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw Exception('Файл не существует: $filePath');
      }

      print('Открываем файл: $filePath');

      // Используем open_file пакет (работает на всех платформах)
      final result = await OpenFile.open(filePath);

      print('Результат открытия файла: ${result.type} - ${result.message}');

      if (result.type != ResultType.done) {
        // Если не удалось открыть через open_file, пробуем другие способы
        await _tryAlternativeOpenMethods(filePath);
      }
    } catch (e) {
      print('Ошибка открытия файла: $e');
      rethrow;
    }
  }

  // Альтернативные методы открытия
  static Future<void> _tryAlternativeOpenMethods(String filePath) async {
    final uri = Uri.file(filePath);

    // Для некоторых типов файлов используем url_launcher
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception(
        'Не удалось открыть файл. Установите приложение для этого типа файлов.',
      );
    }
  }

  // Проверить разрешения на доступ к файлам
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
      return true;
    } else if (Platform.isIOS) {
      // На iOS обычно не нужно явное разрешение для открытия файлов из Documents
      return true;
    }
    return true;
  }

  // Получить путь к директории для сохранения файлов
  static Future<String> getDownloadDirectoryPath() async {
    if (Platform.isAndroid) {
      // На Android используем Downloads директорию
      final directory = Directory('/storage/emulated/0/Download');
      if (await directory.exists()) {
        return directory.path;
      }
    }

    // Для других платформ или если не нашли
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  // Проверить, поддерживается ли тип файла
  static bool isFileTypeSupported(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;

    // Список поддерживаемых расширений
    final supportedExtensions = {
      // Изображения
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic',
      // Документы
      'pdf', 'txt', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
      // Аудио
      'mp3', 'wav', 'ogg', 'm4a',
      // Видео
      'mp4', 'avi', 'mov', 'mkv', 'wmv',
      // Архивы
      'zip', 'rar', '7z',
    };

    return supportedExtensions.contains(extension);
  }

  // Получить иконку для типа файла
  static String getFileIcon(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;

    switch (extension) {
      case 'pdf':
        return '📄';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return '🖼️';
      case 'mp4':
      case 'avi':
      case 'mov':
        return '🎬';
      case 'mp3':
      case 'wav':
        return '🎵';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
        return '📊';
      case 'zip':
      case 'rar':
        return '📦';
      default:
        return '📁';
    }
  }

  // Получить MIME тип файла по расширению
  static String getMimeType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;

    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}
