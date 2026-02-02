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
  // Храним, какие передачи отменены локально (для UI)
  final Map<String, bool> _cancelledTransfers = {};
  bool _shouldShowCancellationToast = false;
  String? _cancellationMessage;

  // Храним историю передач для отображения даже после завершения
  final Map<String, FileTransfer> _transferHistory = {};

  @override
  void initState() {
    super.initState();

    // Устанавливаем колбэк для получения уведомлений об отмене
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = Provider.of<FileTransferService>(context, listen: false);
      service.setRemoteCancellationCallback((message) {
        _handleRemoteCancellation('The transfer was canceled', message);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

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

  // Метод для проверки, началась ли хоть одна передача
  bool _hasAnyTransferStarted(FileTransferService service) {
    // Проверяем активные передачи
    if (service.activeTransfers.values.any((t) => t.receivedBytes > 0)) {
      return true;
    }

    // Проверяем историю передач
    if (_transferHistory.values.any((t) => t.receivedBytes > 0)) {
      return true;
    }

    return false;
  }

  // Метод для проверки, все ли передачи завершены или отменены
  bool _areAllTransfersCompleteOrCancelled(FileTransferService service) {
    // Собираем все передачи: активные + история
    final allTransfers = <String, FileTransfer>{};

    // Активные передачи
    for (final transfer in service.activeTransfers.values) {
      allTransfers[transfer.transferId] = transfer;
    }

    // Исторические передачи
    for (final entry in _transferHistory.entries) {
      if (!allTransfers.containsKey(entry.key)) {
        allTransfers[entry.key] = entry.value;
      }
    }

    if (allTransfers.isEmpty) {
      return false; // Не было передач
    }

    // Проверяем каждую передачу
    for (final transfer in allTransfers.values) {
      final isCancelled = _cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100;

      if (!isCancelled && !isCompleted) {
        // Нашли незавершенную и неотмененную передачу
        return false;
      }
    }

    // Все передачи либо завершены, либо отменены
    return true;
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

        // Обновляем UI
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  // Метод для отмены всех активных передач
  Future<void> _cancelAllTransfers(FileTransferService service) async {
    // Собираем все активные передачи
    final activeTransfers = service.activeTransfers.values.toList();

    if (activeTransfers.isEmpty) {
      // Нет активных передач, просто выходим
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    // Проверяем, есть ли незавершенные/неотмененные передачи
    bool hasActiveTransfers = false;
    for (final transfer in activeTransfers) {
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
        // Отменяем все передачи
        for (final transfer in activeTransfers) {
          final isCancelled = _cancelledTransfers[transfer.transferId] == true;
          final isCompleted = transfer.progress >= 100;

          if (!isCancelled && !isCompleted) {
            // Сохраняем в историю
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

            // Помечаем как отмененную
            if (mounted) {
              setState(() => _cancelledTransfers[transfer.transferId] = true);
            }

            // Отменяем передачу
            await service.cancelTransfer(transfer.transferId);
          }
        }

        // Обновляем UI
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _handleRemoteCancellation(String message, String? transferId) {
    if (mounted) {
      setState(() {
        _shouldShowCancellationToast = true;
        _cancellationMessage = message;

        if (transferId != null) {
          // Помечаем КОНКРЕТНУЮ передачу как отмененную
          _cancelledTransfers[transferId] = true;

          // Сохраняем эту конкретную передачу в историю
          final service = Provider.of<FileTransferService>(
            context,
            listen: false,
          );

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
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          CustomToast.showToast(
            context: context,
            message: _cancellationMessage!,
          );
          _shouldShowCancellationToast = false;
          _cancellationMessage = null;
        }
      });
    }
  }

  // Получаем все передачи для отображения (активные + исторические завершенные/отмененные)
  List<FileTransfer> _getAllTransfersForDisplay(FileTransferService service) {
    final allTransfersMap = <String, FileTransfer>{};

    // Добавляем активные передачи
    for (final transfer in service.activeTransfers.values) {
      allTransfersMap[transfer.transferId] = transfer;
    }

    // Добавляем исторические передачи, которые завершены или отменены
    for (final entry in _transferHistory.entries) {
      final transfer = entry.value;
      final isCancelled = _cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100;

      if (isCancelled || isCompleted) {
        allTransfersMap[transfer.transferId] = transfer;
      }
    }

    return allTransfersMap.values.toList();
  }

  // Группируем передачи по типу
  Map<String, List<FileTransfer>> _groupTransfers(
    List<FileTransfer> transfers,
  ) {
    final groups = <String, List<FileTransfer>>{'photos': [], 'videos': []};

    for (final transfer in transfers) {
      if (transfer.transferId.startsWith('photos_') ||
          transfer.fileType == 'image/mixed' ||
          (transfer.fileType.startsWith('image/') &&
              !transfer.transferId.startsWith('videos_'))) {
        groups['photos']!.add(transfer);
      } else if (transfer.transferId.startsWith('videos_') ||
          transfer.fileType == 'video/mixed' ||
          (transfer.fileType.startsWith('video/') &&
              !transfer.transferId.startsWith('photos_'))) {
        groups['videos']!.add(transfer);
      }
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context, listen: true);

    // Проверяем состояние
    final hasAnyTransferStarted = _hasAnyTransferStarted(service);
    final areAllTransfersCompleteOrCancelled =
        _areAllTransfersCompleteOrCancelled(service);

    // Получаем все передачи для отображения
    final allTransfers = _getAllTransfersForDisplay(service);
    final groupedTransfers = _groupTransfers(allTransfers);

    final photoTransfers = groupedTransfers['photos']!;
    final videoTransfers = groupedTransfers['videos']!;

    // Определяем, были ли фото/видео передачи
    final hadPhotoTransfers = photoTransfers.isNotEmpty;
    final hadVideoTransfers = videoTransfers.isNotEmpty;

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.isSending ? 'Sending files' : 'Receiving files',
        onBackPressed: () async {
          // Проверяем, все ли передачи завершены или отменены
          if (areAllTransfersCompleteOrCancelled) {
            // Все завершены, просто выходим
            if (mounted) {
              Navigator.pop(context);
            }
          } else {
            // Есть активные передачи, показываем диалог отмены ВСЕХ передач
            await _cancelAllTransfers(service);
          }
        },
      ),
      body: !hasAnyTransferStarted && allTransfers.isEmpty
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

                // Кнопка "В главное меню" показывается только когда ВСЕ передачи завершены или отменены
                if (areAllTransfersCompleteOrCancelled &&
                    allTransfers.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 16.0, bottom: 24.0),
                    child: CustomButton.primary(
                      title: 'Go to main menu',
                      onPressed: () async {
                        // Очищаем в зависимости от роли
                        if (widget.isSending) {
                          await service.stopServer();
                        } else {
                          await service.clearClientTransfers();
                        }

                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
