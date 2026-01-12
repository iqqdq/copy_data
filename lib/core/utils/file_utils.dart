import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core.dart';

class FileUtils {
  static Future<FileInfo> createFileInfo(File file) async {
    final stats = await file.stat();
    final bytes = await file.readAsBytes();

    return FileInfo(
      id: _generateFileId(file.path),
      name: path.basename(file.path),
      path: file.path,
      size: await file.length(),
      hash: md5.convert(bytes).toString(),
      mimeType: lookupMimeType(file.path) ?? 'application/octet-stream',
      modifiedDate: stats.modified,
    );
  }

  static String _generateFileId(String filePath) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash = md5.convert(utf8.encode(filePath)).toString();
    return '${timestamp}_$hash';
  }

  static String getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return '🖼️';
    if (mimeType.startsWith('video/')) return '🎬';
    if (mimeType.startsWith('audio/')) return '🎵';
    if (mimeType.contains('pdf')) return '📄';
    if (mimeType.contains('word') || mimeType.contains('document')) return '📝';
    if (mimeType.contains('excel') || mimeType.contains('sheet')) return '📊';
    if (mimeType.contains('zip') || mimeType.contains('rar')) return '📦';
    return '📁';
  }

  static Future<Directory> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    }
    return await getDownloadsDirectory() ?? Directory.current;
  }

  static bool isSupportedFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    final unsupported = ['exe', 'bat', 'cmd', 'sh', 'apk', 'ipa'];
    return !unsupported.contains(extension);
  }
}
