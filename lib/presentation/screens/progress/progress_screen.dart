import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class ProgressScreen extends StatefulWidget {
  final bool isSending;

  const ProgressScreen({super.key, required this.isSending});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final Map<String, bool> _cancelledTransfers = {};
  bool _showGoToMainMenu = false;
  bool _shouldShowCancellationToast = false;
  String? _cancellationMessage;
  bool _hasTransferStarted = false;

  // Храним историю передач с их последним состоянием
  final Map<String, FileTransfer> _transferHistory = {};
  bool _allTransfersCancelled = false;

  @override
  void initState() {
    super.initState();

    // Устанавливаем колбэк для получения уведомлений об отмене
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = Provider.of<FileTransferService>(context, listen: false);
      service.setRemoteCancellationCallback((message) {
        _handleRemoteCancellation(message);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _checkTransferCompletion();

    // Проверяем, нужно ли показать уведомление об отмене
    if (_shouldShowCancellationToast && _cancellationMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomToast.showToast(context: context, message: _cancellationMessage!);
        _shouldShowCancellationToast = false;
        _cancellationMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _cancelledTransfers.clear();
    _transferHistory.clear();

    super.dispose();
  }

  void _cancelTransfer({
    required FileTransferService service,
    required String transferId,
  }) async {
    await DestructiveDialog.show(
      context,
      message: widget.isSending
          ? 'Are you sure you want to stop sending files? Your transfer will be interrupted'
          : 'Are you sure you want to stop receiving files? Your transfer will be interrupted',
      cancelTitle: widget.isSending ? 'Keep sending' : 'Keep receiving',
      onDestructivePressed: () async {
        // Сохраняем текущее состояние передачи перед отменой
        final transfer = service.activeTransfers[transferId];
        if (transfer != null) {
          _transferHistory[transfer.transferId] = FileTransfer(
            transferId: transfer.transferId,
            fileName: transfer.fileName,
            fileSize: transfer.fileSize,
            fileType: transfer.fileType,
            file: transfer.file,
            targetPath: transfer.targetPath,
            onProgress: transfer.onProgress,
            onComplete: transfer.onComplete,
            onError: transfer.onError,
            sendMessage: transfer.sendMessage,
            totalFiles: transfer.totalFiles,
            completedFiles: transfer.completedFiles,
          )..receivedBytes = transfer.receivedBytes;
        }

        // Помечаем передачу как отмененную
        if (mounted) {
          setState(() => _cancelledTransfers[transferId] = true);
        }

        // Отменяем только эту передачу
        await service.cancelTransfer(transferId);

        // Обновляем состояние кнопки после отмены
        _checkTransferCompletion();

        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  // Метод для отмены всех активных передач
  Future<void> _cancelAllTransfers(FileTransferService service) async {
    // Собираем ВСЕ передачи - активные и из истории
    final allTransfers = <String, FileTransfer>{};

    // Добавляем активные передачи
    for (final transfer in service.activeTransfers.values) {
      allTransfers[transfer.transferId] = transfer;
    }

    // Добавляем исторические передачи
    for (final entry in _transferHistory.entries) {
      if (!allTransfers.containsKey(entry.key)) {
        allTransfers[entry.key] = entry.value;
      }
    }

    if (allTransfers.isEmpty) {
      // Нет активных передач, просто выходим
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    // Проверяем, есть ли незавершенные/неотмененные передачи
    bool hasActiveTransfers = false;
    for (final transfer in allTransfers.values) {
      final isCancelled = _cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100;
      if (!isCancelled && !isCompleted) {
        hasActiveTransfers = true;
        break;
      }
    }

    if (!hasActiveTransfers) {
      // Все передачи уже завершены или отменены, просто выходим
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    // Показываем диалог отмены ВСЕХ передач
    await DestructiveDialog.show(
      context,
      message: widget.isSending
          ? 'Are you sure you want to stop sending all files? All transfers will be interrupted'
          : 'Are you sure you want to stop receiving all files? All transfers will be interrupted',
      cancelTitle: widget.isSending ? 'Keep sending' : 'Keep receiving',
      onDestructivePressed: () async {
        // Отменяем все передачи (и активные, и исторические)
        for (final transfer in allTransfers.values) {
          final isCancelled = _cancelledTransfers[transfer.transferId] == true;
          final isCompleted = transfer.progress >= 100;

          if (!isCancelled && !isCompleted) {
            // Помечаем передачу как отмененную
            if (mounted) {
              setState(() => _cancelledTransfers[transfer.transferId] = true);
            }

            // Отменяем только если передача активна в сервисе
            if (service.activeTransfers.containsKey(transfer.transferId)) {
              await service.cancelTransfer(transfer.transferId);
            } else {
              // Если передачи нет в активных, просто обновляем историю
              _transferHistory[transfer.transferId] = FileTransfer(
                transferId: transfer.transferId,
                fileName: transfer.fileName,
                fileSize: transfer.fileSize,
                fileType: transfer.fileType,
                file: transfer.file,
                targetPath: transfer.targetPath,
                onProgress: transfer.onProgress,
                onComplete: transfer.onComplete,
                onError: transfer.onError,
                sendMessage: transfer.sendMessage,
                totalFiles: transfer.totalFiles,
                completedFiles: transfer.completedFiles,
              )..receivedBytes = transfer.receivedBytes;
            }
          }
        }

        // Обновляем состояние после отмены всех передач
        _checkTransferCompletion();

        // После отмены всех передач очищаем в зависимости от роли
        await _clearClientTransfers(service);

        // Выходим из экрана
        if (mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  // Метод для обработки уведомления об отмене с другой стороны
  void _handleRemoteCancellation(String message) {
    if (mounted) {
      setState(() {
        _shouldShowCancellationToast = true;
        _cancellationMessage = message;

        // Сохраняем текущее состояние передач
        final service = Provider.of<FileTransferService>(
          context,
          listen: false,
        );
        final currentTransfers = service.activeTransfers.values.toList();
        for (final transfer in currentTransfers) {
          _transferHistory[transfer.transferId] = FileTransfer(
            transferId: transfer.transferId,
            fileName: transfer.fileName,
            fileSize: transfer.fileSize,
            fileType: transfer.fileType,
            file: transfer.file,
            targetPath: transfer.targetPath,
            onProgress: transfer.onProgress,
            onComplete: transfer.onComplete,
            onError: transfer.onError,
            sendMessage: transfer.sendMessage,
            totalFiles: transfer.totalFiles,
            completedFiles: transfer.completedFiles,
          )..receivedBytes = transfer.receivedBytes;

          // Помечаем как отмененную с другой стороны
          _cancelledTransfers[transfer.transferId] = true;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkTransferCompletion();
        });
      });
    }
  }

  void _checkTransferCompletion() {
    final service = Provider.of<FileTransferService>(context, listen: false);
    final transfers = service.activeTransfers.values.toList();

    // Сохраняем текущие передачи в историю
    for (final transfer in transfers) {
      // ВАЖНО: Если прогресс 100%, передача считается завершенной
      // и не должна быть помечена как отмененная
      if (transfer.progress >= 100) {
        // Если передача завершена, удаляем ее из списка отмененных
        _cancelledTransfers.remove(transfer.transferId);
      }

      // Сохраняем в историю всегда
      _transferHistory[transfer.transferId] = FileTransfer(
        transferId: transfer.transferId,
        fileName: transfer.fileName,
        fileSize: transfer.fileSize,
        fileType: transfer.fileType,
        file: transfer.file,
        targetPath: transfer.targetPath,
        onProgress: transfer.onProgress,
        onComplete: transfer.onComplete,
        onError: transfer.onError,
        sendMessage: transfer.sendMessage,
        totalFiles: transfer.totalFiles,
        completedFiles: transfer.completedFiles,
      )..receivedBytes = transfer.receivedBytes;
    }

    // Проверяем, начались ли передачи (есть хотя бы один байт получено или передача отменена)
    if (!_hasTransferStarted) {
      _hasTransferStarted =
          transfers.any(
            (t) =>
                t.receivedBytes > 0 ||
                _cancelledTransfers[t.transferId] == true,
          ) ||
          _transferHistory.values.any(
            (t) =>
                t.receivedBytes > 0 ||
                _cancelledTransfers[t.transferId] == true,
          );
    }

    // Объединяем активные передачи и историю для проверки состояния
    final allTransfersMap = <String, FileTransfer>{};

    // Добавляем активные передачи
    for (final transfer in transfers) {
      allTransfersMap[transfer.transferId] = transfer;
    }

    // Добавляем исторические передачи, которые не активны сейчас
    for (final entry in _transferHistory.entries) {
      if (!allTransfersMap.containsKey(entry.key)) {
        allTransfersMap[entry.key] = entry.value;
      }
    }

    final allTransfers = allTransfersMap.values.toList();

    if (allTransfers.isEmpty) {
      // Никогда не было передач
      _showGoToMainMenu = false;
      _allTransfersCancelled = false;
    } else {
      // Проверяем состояние всех передач
      bool allCompletedOrCancelled = true;
      bool anyActive = false;

      for (final transfer in allTransfers) {
        final isCancelled = _cancelledTransfers[transfer.transferId] == true;
        final isCompleted = transfer.progress >= 100;
        final hasStarted = transfer.receivedBytes > 0;

        // ВАЖНО: Если передача завершена (100%), она не считается активной
        if (isCompleted) {
          // Завершенная передача - не активна
        } else if (hasStarted && !isCancelled) {
          // Активная незавершенная и неотмененная передача
          allCompletedOrCancelled = false;
          anyActive = true;
        } else if (!hasStarted &&
            !isCancelled &&
            transfers.any((t) => t.transferId == transfer.transferId)) {
          // Передача еще не началась, но она в активных - считаем как активную
          allCompletedOrCancelled = false;
        }
      }

      // Показываем кнопку только если ВСЕ передачи завершены ИЛИ отменены
      _showGoToMainMenu = allCompletedOrCancelled;

      // Все передачи отменены только если нет активных и все отменены
      _allTransfersCancelled =
          allTransfers.isNotEmpty &&
          !anyActive &&
          allTransfers.every((t) => _cancelledTransfers[t.transferId] == true);
    }

    _stopServerIfAllTransfersComplete(service, transfers);

    if (mounted) {
      setState(() {});
    }
  }

  void _stopServerIfAllTransfersComplete(
    FileTransferService service,
    List<FileTransfer> transfers,
  ) {
    // Проверяем условия для остановки сервера
    final shouldStopServer =
        (_showGoToMainMenu || _allTransfersCancelled) &&
        service.isServerRunning &&
        mounted;

    if (shouldStopServer) {
      // Дополнительная проверка: все ли передачи действительно завершены
      final allTransfersFinished =
          transfers.isEmpty ||
          transfers.every(
            (t) =>
                t.progress >= 100 || _cancelledTransfers[t.transferId] == true,
          );

      if (allTransfersFinished) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            print('🔄 Все передачи завершены, останавливаю сервер...');
            await service.stopServer();
          } catch (e) {
            print('⚠️ Ошибка при остановке сервера: $e');
          }
        });
      }
    }
  }

  // Получаем все передачи для отображения (активные + исторические)
  List<FileTransfer> _getAllTransfersForDisplay(FileTransferService service) {
    final allTransfersMap = <String, FileTransfer>{};

    // Добавляем активные передачи
    for (final transfer in service.activeTransfers.values) {
      allTransfersMap[transfer.transferId] = transfer;
    }

    // Добавляем исторические передачи, которые не активны сейчас
    for (final entry in _transferHistory.entries) {
      if (!allTransfersMap.containsKey(entry.key)) {
        allTransfersMap[entry.key] = entry.value;
      }
    }

    return allTransfersMap.values.toList();
  }

  Future<void> _clearClientTransfers(FileTransferService service) async {
    if (widget.isSending) {
      await service.stopServer();
    } else {
      await service.clearClientTransfers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);

    // Получаем ВСЕ передачи для отображения (активные + исторические)
    final allTransfers = _getAllTransfersForDisplay(service);

    // Правильная группировка передач из всех доступных
    final photoTransfers = allTransfers
        .where(
          (t) =>
              t.transferId.startsWith('photos_') ||
              t.fileType == 'image/mixed' ||
              (t.fileType.startsWith('image/') &&
                  !t.transferId.startsWith('videos_')),
        )
        .toList();

    final videoTransfers = allTransfers
        .where(
          (t) =>
              t.transferId.startsWith('videos_') ||
              t.fileType == 'video/mixed' ||
              (t.fileType.startsWith('video/') &&
                  !t.transferId.startsWith('photos_')),
        )
        .toList();

    // Определяем, были ли фото/видео передачи
    final hadPhotoTransfers = photoTransfers.isNotEmpty;
    final hadVideoTransfers = videoTransfers.isNotEmpty;

    // Для отладки
    if (photoTransfers.isNotEmpty) {
      print('📸 Фото передач для отображения: ${photoTransfers.length} шт.');
      for (final t in photoTransfers) {
        print(
          '  - ${t.transferId}: ${t.fileName}, файлов: ${t.totalFiles}, '
          'завершено: ${t.completedFiles}, прогресс: ${t.progress}%, '
          'отменена: ${_cancelledTransfers[t.transferId] == true}',
        );
      }
    }

    if (videoTransfers.isNotEmpty) {
      print('🎥 Видео передач для отображения: ${videoTransfers.length} шт.');
      for (final t in videoTransfers) {
        print(
          '  - ${t.transferId}: ${t.fileName}, файлов: ${t.totalFiles}, '
          'завершено: ${t.completedFiles}, прогресс: ${t.progress}%, '
          'отменена: ${_cancelledTransfers[t.transferId] == true}',
        );
      }
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.isSending ? 'Sending files' : 'Receiving files',
        onBackPressed: () async {
          // Проверяем, есть ли активные незавершенные/неотмененные передачи
          // Проверяем ВСЕ передачи (активные и исторические)
          bool hasActiveTransfers = false;
          for (final transfer in allTransfers) {
            final isCancelled =
                _cancelledTransfers[transfer.transferId] == true;
            final isCompleted = transfer.progress >= 100;
            if (!isCancelled && !isCompleted) {
              hasActiveTransfers = true;
              break;
            }
          }

          if (!hasActiveTransfers) {
            // Все передачи завершены или отменены, просто выходим
            if (mounted) {
              Navigator.pop(context);
            }
          } else {
            // Есть активные передачи, показываем диалог отмены ВСЕХ передач
            await _cancelAllTransfers(service);
          }
        },
      ),
      body:
          (!_hasTransferStarted &&
              !_showGoToMainMenu &&
              !_allTransfersCancelled)
          ? const Center(child: CustomLoader())
          : ListView(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              children: [
                // Показываем карточку фото только если были фото передачи
                if (hadPhotoTransfers)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: hadVideoTransfers ? 16.0 : 24.0,
                    ),
                    child: ProgressTile(
                      isPhoto: true,
                      isSending: widget.isSending,
                      service: service,
                      transfers: photoTransfers,
                      cancelledTransfers: _cancelledTransfers,
                      onTransferCancel: (id) =>
                          _cancelTransfer(service: service, transferId: id),
                    ),
                  ),

                // Показываем карточку видео только если были видео передачи
                if (hadVideoTransfers)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: ProgressTile(
                      isPhoto: false,
                      isSending: widget.isSending,
                      service: service,
                      transfers: videoTransfers,
                      cancelledTransfers: _cancelledTransfers,
                      onTransferCancel: (id) =>
                          _cancelTransfer(service: service, transferId: id),
                    ),
                  ),

                // Кнопка "В главное меню" показывается только при завершении всех передач
                // или отмене всех передач
                if (_showGoToMainMenu || _allTransfersCancelled)
                  CustomButton.primary(
                    title: 'Go to main menu',
                    onPressed: () async {
                      // После отмены всех передач очищаем в зависимости от роли
                      await _clearClientTransfers(service);

                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ],
            ),
    );
  }
}
