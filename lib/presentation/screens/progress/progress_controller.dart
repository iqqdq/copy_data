import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class ProgressController with ChangeNotifier {
  ProgressState _state;
  ProgressState get state => _state;

  final FileTransferService _service;
  final BuildContext _context;

  ProgressController({
    required BuildContext context,
    required bool isSending,
    required FileTransferService service,
  }) : _context = context,
       _service = service,
       _state = ProgressState(
         isSending: isSending,
         cancelledTransfers: {},
         showGoToMainMenu: false,
         shouldShowCancellationToast: false,
         cancellationMessage: null,
         hasTransferStarted: false,
         transferHistory: {},
         allTransfersCancelled: false,
         photoTransfers: null,
         videoTransfers: null,
         hadPhotoTransfers: false,
         hadVideoTransfers: false,
       ) {
    _init();
  }

  void _init() {
    // Устанавливаем колбэк для получения уведомлений об отмене
    _service.setRemoteCancellationCallback(_handleRemoteCancellation);

    // Слушаем изменения в сервисе
    _service.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    // Когда сервис обновляется (например, появляются новые передачи),
    // проверяем состояние передач
    _checkTransferCompletion();
  }

  void showCancellationToastIfNeeded() {
    if (_state.shouldShowCancellationToast &&
        _state.cancellationMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomToast.showToast(
          context: _context,
          message: _state.cancellationMessage!,
        );
        _state = _state.copyWith(
          shouldShowCancellationToast: false,
          cancellationMessage: null,
        );
        notifyListeners();
      });
    }
  }

  Future<void> cancelTransfer(String transferId) async {
    await DestructiveDialog.show(
      _context,
      message: _state.isSending
          ? 'Are you sure you want to stop sending files? Your transfer will be interrupted'
          : 'Are you sure you want to stop receiving files? Your transfer will be interrupted',
      cancelTitle: _state.isSending ? 'Keep sending' : 'Keep receiving',
      onDestructivePressed: () async {
        // Сохраняем текущее состояние передачи перед отменой
        final transfer = _service.activeTransfers[transferId];
        if (transfer != null) {
          final history = Map<String, FileTransfer>.from(
            _state.transferHistory,
          );
          history[transfer.transferId] = FileTransfer(
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

          _state = _state.copyWith(transferHistory: history);
        }

        // Помечаем передачу как отмененную
        final cancelled = Map<String, bool>.from(_state.cancelledTransfers);
        cancelled[transferId] = true;
        _state = _state.copyWith(cancelledTransfers: cancelled);

        // Отменяем только эту передачу
        await _service.cancelTransfer(transferId);

        // Обновляем состояние кнопки после отмены
        _checkTransferCompletion();
        notifyListeners();
      },
    );
  }

  Future<void> cancelAllTransfers() async {
    // Собираем ВСЕ передачи - активные и из истории
    final allTransfers = <String, FileTransfer>{};

    // Добавляем активные передачи
    for (final transfer in _service.activeTransfers.values) {
      allTransfers[transfer.transferId] = transfer;
    }

    // Добавляем исторические передачи
    for (final entry in _state.transferHistory.entries) {
      if (!allTransfers.containsKey(entry.key)) {
        allTransfers[entry.key] = entry.value;
      }
    }

    if (allTransfers.isEmpty) {
      // Нет активных передач, просто выходим
      if (_context.mounted) {
        Navigator.pop(_context);
      }
      return;
    }

    // Проверяем, есть ли незавершенные/неотмененные передачи
    bool hasActiveTransfers = false;
    for (final transfer in allTransfers.values) {
      final isCancelled =
          _state.cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100;
      if (!isCancelled && !isCompleted) {
        hasActiveTransfers = true;
        break;
      }
    }

    if (!hasActiveTransfers) {
      // Все передачи уже завершены или отменены, просто выходим
      if (_context.mounted) {
        Navigator.pop(_context);
      }
      return;
    }

    // Показываем диалог отмены ВСЕХ передач
    await DestructiveDialog.show(
      _context,
      message: _state.isSending
          ? 'Are you sure you want to stop sending all files? All transfers will be interrupted'
          : 'Are you sure you want to stop receiving all files? All transfers will be interrupted',
      cancelTitle: _state.isSending ? 'Keep sending' : 'Keep receiving',
      onDestructivePressed: () async {
        // Отменяем все передачи (и активные, и исторические)
        for (final transfer in allTransfers.values) {
          final isCancelled =
              _state.cancelledTransfers[transfer.transferId] == true;
          final isCompleted = transfer.progress >= 100;

          if (!isCancelled && !isCompleted) {
            // Помечаем передачу как отмененную
            final cancelled = Map<String, bool>.from(_state.cancelledTransfers);
            cancelled[transfer.transferId] = true;
            _state = _state.copyWith(cancelledTransfers: cancelled);

            // Отменяем только если передача активна в сервисе
            if (_service.activeTransfers.containsKey(transfer.transferId)) {
              await _service.cancelTransfer(transfer.transferId);
            } else {
              // Если передачи нет в активных, просто обновляем историю
              final history = Map<String, FileTransfer>.from(
                _state.transferHistory,
              );
              history[transfer.transferId] = FileTransfer(
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
              _state = _state.copyWith(transferHistory: history);
            }
          }
        }

        // Обновляем состояние после отмены всех передач
        _checkTransferCompletion();

        // После отмены всех передач очищаем в зависимости от роли
        await _clearClientTransfers();

        // Выходим из экрана
        if (_context.mounted) {
          Navigator.pop(_context);
        }
      },
    );
  }

  void _handleRemoteCancellation(String message) {
    _state = _state.copyWith(
      shouldShowCancellationToast: true,
      cancellationMessage: message,
    );

    // Сохраняем текущее состояние передач
    final currentTransfers = _service.activeTransfers.values.toList();
    final history = Map<String, FileTransfer>.from(_state.transferHistory);
    final cancelled = Map<String, bool>.from(_state.cancelledTransfers);

    for (final transfer in currentTransfers) {
      history[transfer.transferId] = FileTransfer(
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
      cancelled[transfer.transferId] = true;
    }

    _state = _state.copyWith(
      transferHistory: history,
      cancelledTransfers: cancelled,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTransferCompletion();
    });

    notifyListeners();
  }

  void checkTransferCompletion() {
    _checkTransferCompletion();
  }

  void _checkTransferCompletion() {
    final transfers = _service.activeTransfers.values.toList();

    // Отладка
    if (transfers.isNotEmpty) {
      print('🔄 Проверка передач. Активных: ${transfers.length}');
      for (final transfer in transfers) {
        print(
          '  - ${transfer.transferId}: ${transfer.fileName}, '
          'прогресс: ${transfer.progress}%, '
          'получено: ${transfer.receivedBytes} байт',
        );
      }
    }

    // Сохраняем текущие передачи в историю
    final history = Map<String, FileTransfer>.from(_state.transferHistory);
    final cancelled = Map<String, bool>.from(_state.cancelledTransfers);

    for (final transfer in transfers) {
      // ВАЖНО: Если прогресс 100%, передача считается завершенной
      // и не должна быть помечена как отмененная
      if (transfer.progress >= 100) {
        // Если передача завершена, удаляем ее из списка отмененных
        cancelled.remove(transfer.transferId);
      }

      // Сохраняем в историю всегда
      history[transfer.transferId] = FileTransfer(
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
    bool hasTransferStarted = _state.hasTransferStarted;
    if (!hasTransferStarted) {
      hasTransferStarted =
          transfers.any(
            (t) => t.receivedBytes > 0 || cancelled[t.transferId] == true,
          ) ||
          history.values.any(
            (t) => t.receivedBytes > 0 || cancelled[t.transferId] == true,
          );

      if (hasTransferStarted && !_state.hasTransferStarted) {
        print('🚀 Передача началась! hasTransferStarted = true');
      }
    }

    // Объединяем активные передачи и историю для проверки состояния
    final allTransfersMap = <String, FileTransfer>{};

    // Добавляем активные передачи
    for (final transfer in transfers) {
      allTransfersMap[transfer.transferId] = transfer;
    }

    // Добавляем исторические передачи, которые не активны сейчас
    for (final entry in history.entries) {
      if (!allTransfersMap.containsKey(entry.key)) {
        allTransfersMap[entry.key] = entry.value;
      }
    }

    final allTransfers = allTransfersMap.values.toList();

    bool showGoToMainMenu = false;
    bool allTransfersCancelled = false;

    if (allTransfers.isEmpty) {
      // Никогда не было передач
      showGoToMainMenu = false;
      allTransfersCancelled = false;
    } else {
      // Проверяем состояние всех передач
      bool allCompletedOrCancelled = true;
      bool anyActive = false;

      for (final transfer in allTransfers) {
        final isCancelled = cancelled[transfer.transferId] == true;
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
      showGoToMainMenu = allCompletedOrCancelled;

      // Все передачи отменены только если нет активных и все отменены
      allTransfersCancelled =
          allTransfers.isNotEmpty &&
          !anyActive &&
          allTransfers.every((t) => cancelled[t.transferId] == true);
    }

    // Вычисляем данные для отображения
    final displayData = _getDisplayData(allTransfers);

    _state = _state.copyWith(
      hasTransferStarted: hasTransferStarted,
      transferHistory: history,
      cancelledTransfers: cancelled,
      showGoToMainMenu: showGoToMainMenu,
      allTransfersCancelled: allTransfersCancelled,
      photoTransfers: displayData['photoTransfers'] as List<FileTransfer>?,
      videoTransfers: displayData['videoTransfers'] as List<FileTransfer>?,
      hadPhotoTransfers: displayData['hadPhotoTransfers'] as bool,
      hadVideoTransfers: displayData['hadVideoTransfers'] as bool,
    );

    _stopServerIfAllTransfersComplete(transfers);

    // Уведомляем слушателей об изменении состояния
    if (_context.mounted) {
      notifyListeners();
    }
  }

  void _stopServerIfAllTransfersComplete(List<FileTransfer> transfers) {
    // Проверяем условия для остановки сервера
    final shouldStopServer =
        (_state.showGoToMainMenu || _state.allTransfersCancelled) &&
        _service.isServerRunning &&
        _context.mounted;

    if (shouldStopServer) {
      // Дополнительная проверка: все ли передачи действительно завершены
      final allTransfersFinished =
          transfers.isEmpty ||
          transfers.every(
            (t) =>
                t.progress >= 100 ||
                _state.cancelledTransfers[t.transferId] == true,
          );

      if (allTransfersFinished) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            print('🔄 Все передачи завершены, останавливаю сервер...');
            await _service.stopServer();
          } catch (e) {
            print('⚠️ Ошибка при остановке сервера: $e');
          }
        });
      }
    }
  }

  Map<String, dynamic> _getDisplayData(List<FileTransfer> allTransfers) {
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

    return {
      'photoTransfers': photoTransfers,
      'videoTransfers': videoTransfers,
      'hadPhotoTransfers': photoTransfers.isNotEmpty,
      'hadVideoTransfers': videoTransfers.isNotEmpty,
    };
  }

  Future<void> _clearClientTransfers() async {
    if (_state.isSending) {
      await _service.stopServer();
    } else {
      await _service.clearClientTransfers();
    }
  }

  Future<void> goToMainMenu() async {
    await _clearClientTransfers();
    if (_context.mounted) Navigator.pop(_context);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _service.removeOnSubscriptionRequiredCallback();
    super.dispose();
  }
}
