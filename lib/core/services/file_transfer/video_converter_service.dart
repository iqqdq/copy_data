import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class VideoConverterService {
  bool _isProgressListenerActive = false;
  bool _isCancelled = false;
  Completer<void>? _cancelCompleter;

  bool isMovFile(File file) {
    final fileName = path.basename(file.path).toLowerCase();
    return fileName.endsWith('.mov') || fileName.endsWith('.quicktime');
  }

  Future<File?> convertMovToMp4(
    File file,
    Function(double) onProgress, {
    Completer<void>? cancelCompleter,
  }) async {
    _cancelCompleter = cancelCompleter ?? Completer<void>();
    _isCancelled = false;

    // Подписываемся на отмену
    _cancelCompleter!.future.then((_) {
      _isCancelled = true;
      print('🛑 Получен сигнал отмены конвертации');
    });

    try {
      print('⚠️ Конвертация HEVC (iPhone) в H.264 (Android)...');

      if (!await file.exists()) {
        print('❌ Файл не найден');
        onProgress(100.0);
        return null;
      }

      final fileSize = await file.length();
      print('⚠️ Размер: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      final duration = await _getVideoDuration(file);
      if (duration == null) {
        print('❌ Не удалось получить длительность видео');
        onProgress(100.0);
        return null;
      }

      print('⚠️ Длительность видео: $duration секунд');
      onProgress(0.0);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = path.join(
        tempDir.path,
        'android_compatible_$timestamp.mp4',
      );

      final conversionCommand =
          '''
      -i "${file.path}"
      -c:v libx264
      -preset faster
      -crf 24
      -profile:v high
      -level 4.2
      -pix_fmt yuv420p
      -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2"
      -movflags +faststart
      -c:a aac
      -b:a 128k
      -ac 2
      -ar 44100
      -y "$outputPath"
    '''
              .replaceAll(RegExp(r'\s+'), ' ');

      final completer = Completer<File?>();
      double lastSentProgress = -1.0;

      // Включаем слушатель прогресса
      _setupFfmpegProgressListener((progress) {
        if (_isCancelled) return;

        if (progress - lastSentProgress >= 1.0 || progress >= 100.0) {
          onProgress(progress);
          lastSentProgress = progress;
        }
      }, duration);

      // Запускаем FFmpeg асинхронно с возможностью отслеживания
      FFmpegKit.executeAsync(conversionCommand, (session) async {
        // Проверяем отмену сразу после получения сессии
        if (_isCancelled) {
          print('🛑 Конвертация отменена перед началом');
          await _tryCancelFfmpegSession(session);
          completer.complete(null);
          return;
        }

        final returnCode = await session.getReturnCode();

        // Отключаем слушатель
        _disableFfmpegProgressListener();

        // Проверяем отмену
        if (_isCancelled) {
          print('🛑 Конвертация отменена пользователем во время выполнения');
          // Удаляем временный файл если создан
          final tempFile = File(outputPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          completer.complete(null);
          return;
        }

        if (ReturnCode.isSuccess(returnCode)) {
          final outputFile = File(outputPath);

          if (await outputFile.exists()) {
            final convertedSize = await outputFile.length();

            print('✅ Конвертация успешна!');
            print(
              '📊 Новый размер: ${(convertedSize / 1024 / 1024).toStringAsFixed(2)} MB',
            );

            onProgress(100.0);
            completer.complete(outputFile);
          } else {
            onProgress(100.0);
            completer.complete(null);
          }
        } else {
          final output = await session.getOutput();
          print('❌ Конвертация не удалась: $output');
          onProgress(100.0);
          completer.complete(null);
        }
      });

      // Ожидаем завершения или отмены
      return await completer.future.timeout(
        Duration(minutes: 20),
        onTimeout: () {
          if (!_isCancelled) {
            print('❌ Конвертация превысила лимит времени');
            onProgress(100.0);
          }
          return null;
        },
      );
    } catch (e, _) {
      _disableFfmpegProgressListener();
      print('❌ Ошибка при конвертации: $e');
      onProgress(100.0);
      return null;
    }
  }

  Future<double?> _getVideoDuration(File videoFile) async {
    try {
      // Пробуем через FFprobe
      final command =
          '-i "${videoFile.path}" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1';
      final session = await FFprobeKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        if (output != null && output.trim().isNotEmpty) {
          final durationStr = output.trim();
          final duration = double.tryParse(durationStr);
          if (duration != null) {
            return duration;
          }
        }
      }

      // Альтернативный способ через FFmpeg
      final ffmpegCommand = '-i "${videoFile.path}" 2>&1 | grep Duration';
      final ffmpegSession = await FFmpegKit.execute(ffmpegCommand);
      final ffmpegOutput = await ffmpegSession.getOutput();

      if (ffmpegOutput != null) {
        final durationMatch = RegExp(
          r'Duration:\s+(\d+):(\d+):(\d+\.\d+)',
        ).firstMatch(ffmpegOutput);
        if (durationMatch != null) {
          final hours = int.parse(durationMatch.group(1)!);
          final minutes = int.parse(durationMatch.group(2)!);
          final seconds = double.parse(durationMatch.group(3)!);
          return hours * 3600 + minutes * 60 + seconds;
        }
      }

      return null;
    } catch (e) {
      print('⚠️ Не удалось получить длительность видео: $e');
      return null;
    }
  }

  void _setupFfmpegProgressListener(
    Function(double) onProgress,
    double totalDuration,
  ) {
    if (_isProgressListenerActive) return;

    _isProgressListenerActive = true;

    // Включаем callback для логов FFmpeg
    FFmpegKitConfig.enableLogCallback((log) {
      if (!_isProgressListenerActive) return;

      final message = log.getMessage();

      // Парсим прогресс из сообщений FFmpeg
      if (message.contains('time=')) {
        final progress = _parseProgressFromFfmpegOutput(message, totalDuration);
        if (progress != null && progress >= 0 && progress <= 100) {
          onProgress(progress);
        }
      }
    });
  }

  void _disableFfmpegProgressListener() {
    if (!_isProgressListenerActive) return;

    _isProgressListenerActive = false;

    // Отключаем callback
    FFmpegKitConfig.enableLogCallback(null);
  }

  double? _parseProgressFromFfmpegOutput(String output, double totalDuration) {
    try {
      // Ищем время в формате time=00:00:09.38
      final timeMatch = RegExp(
        r'time=(\d{2}):(\d{2}):(\d{2}\.\d{2})',
      ).firstMatch(output);
      if (timeMatch != null) {
        final hours = int.parse(timeMatch.group(1)!);
        final minutes = int.parse(timeMatch.group(2)!);
        final seconds = double.parse(timeMatch.group(3)!);
        final currentTime = hours * 3600 + minutes * 60 + seconds;

        if (totalDuration > 0) {
          final progress = (currentTime / totalDuration) * 100.0;
          return progress;
        }
      }

      // Альтернативный формат: frame=  543 fps= 42 q=32.0 size=    5632kB time=00:00:09.38
      final altMatch = RegExp(
        r'time=(\d+):(\d+):(\d+\.\d+)',
      ).firstMatch(output);
      if (altMatch != null) {
        final hours = int.parse(altMatch.group(1)!);
        final minutes = int.parse(altMatch.group(2)!);
        final seconds = double.parse(altMatch.group(3)!);
        final currentTime = hours * 3600 + minutes * 60 + seconds;

        if (totalDuration > 0) {
          final progress = (currentTime / totalDuration) * 100.0;
          return progress;
        }
      }

      return null;
    } catch (e) {
      print('❌ Ошибка парсинга времени FFmpeg: $e');
      return null;
    }
  }

  Future<void> _tryCancelFfmpegSession(FFmpegSession session) async {
    try {
      await session.cancel();
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) {
      print('❌ Не удалось отменить FFmpeg сессию: $e');
    }
  }

  void cancel() {
    if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
      _cancelCompleter!.complete();
    }
  }

  void dispose() {
    _disableFfmpegProgressListener();
    cancel();
  }
}
