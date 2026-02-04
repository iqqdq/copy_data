import 'package:flutter/foundation.dart';
import '../../../core/core.dart';
import 'progress_state.dart';

class ProgressController extends ChangeNotifier {
  final bool isSending;
  final ShowToastCallback showToast;
  final ShowLikeAppDialogCallback showLikeAppDialog;
  final FileTransferService service;

  ProgressState _state;
  ProgressState get state => _state;

  ProgressController({
    required this.isSending,
    required this.showToast,
    required this.showLikeAppDialog,
    required this.service,
  }) : _state = ProgressState(
         isSending: isSending,
         cancelledTransfers: {},
         transferHistory: {},
       ) {
    // Колбэк для уведомления UI об отмене с другой стороны
    _setupRemoteCancellationCallback();
  }

  void _setupRemoteCancellationCallback() {
    service.setRemoteCancellationCallback((transferId) {
      handleRemoteCancellation(
        message: isSending
            ? 'The receiver canceled the transfer'
            : 'The sender canceled the transfer',
        transferId: transferId,
      );
    });
  }

  // Добавление отмененной передачи в историю
  void _addCancelledTransferToHistory(String transferId) {
    final transfer = service.activeTransfers[transferId];
    if (transfer != null) {
      addToTransferHistory(transferId, transfer.copy());
    }
    addCancelledTransfer(transferId);
  }

  // MARK: - State Updates

  void addCancelledTransfer(String transferId) {
    final newCancelledTransfers = Map<String, bool>.from(
      _state.cancelledTransfers,
    );
    newCancelledTransfers[transferId] = true;

    _state = _state.copyWith(cancelledTransfers: newCancelledTransfers);
    notifyListeners();
  }

  void addToTransferHistory(String transferId, FileTransfer transfer) {
    final newTransferHistory = Map<String, FileTransfer>.from(
      _state.transferHistory,
    );
    newTransferHistory[transferId] = transfer;

    _state = _state.copyWith(transferHistory: newTransferHistory);
    notifyListeners();
  }

  void _clearAll() {
    _state = _state.copyWith(
      cancelledTransfers: {},
      transferHistory: {},
      shouldShowCancellationToast: false,
      cancellationMessage: null,
    );
    notifyListeners();
  }

  // MARK: - Business Logic

  bool hasAnyTransferStarted() {
    if (service.activeTransfers.values.any((t) => t.receivedBytes > 0)) {
      return true;
    }

    if (_state.transferHistory.values.any((t) => t.receivedBytes > 0)) {
      return true;
    }

    return false;
  }

  int getTotalFileCount() {
    final transfers = service.activeTransfers.values;

    int totalCount = 0;
    for (final transfer in transfers) {
      totalCount += transfer.totalFiles;
    }
    return totalCount;
  }

  bool areAllTransfersCompleted() {
    if (service.activeTransfers.isEmpty) return false;

    return service.activeTransfers.values.every((transfer) {
      return transfer.progress >= 100.0;
    });
  }

  bool areAllTransfersCompleteOrCancelled() {
    final allTransfers = <String, FileTransfer>{};

    for (final transfer in service.activeTransfers.values) {
      allTransfers[transfer.transferId] = transfer;
    }

    for (final entry in _state.transferHistory.entries) {
      if (!allTransfers.containsKey(entry.key)) {
        allTransfers[entry.key] = entry.value;
      }
    }

    if (allTransfers.isEmpty) return false;

    for (final transfer in allTransfers.values) {
      final isCancelled =
          _state.cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100;

      if (!isCancelled && !isCompleted) return false;
    }

    return true;
  }

  List<FileTransfer> getAllTransfersForDisplay() {
    final allTransfersMap = <String, FileTransfer>{};

    for (final transfer in service.activeTransfers.values) {
      allTransfersMap[transfer.transferId] = transfer;
    }

    for (final entry in _state.transferHistory.entries) {
      final transfer = entry.value;
      final isCancelled =
          _state.cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100;

      if (isCancelled || isCompleted) {
        allTransfersMap[transfer.transferId] = transfer;
      }
    }

    return allTransfersMap.values.toList();
  }

  Map<String, List<FileTransfer>> groupTransfers(List<FileTransfer> transfers) {
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

  Future<void> cancelTransfer(String transferId) async {
    _addCancelledTransferToHistory(transferId);
    await service.cancelTransfer(transferId);
  }

  Future<void> cancelAllTransfers() async {
    final activeTransfers = service.activeTransfers.values.toList();

    for (final transfer in activeTransfers) {
      final isCancelled =
          _state.cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100;

      if (!isCancelled && !isCompleted) {
        _addCancelledTransferToHistory(transfer.transferId);
        await service.cancelTransfer(transfer.transferId);
      }
    }
  }

  void handleRemoteCancellation({
    required String message,
    required String? transferId,
  }) {
    if (transferId != null) {
      _addCancelledTransferToHistory(transferId);
    }

    // Показываем тост через коллбэк
    showToast(message);
  }

  // TODO: добавить handleAllTransfersComplete в FileTransferService
  Future<void> updateTransferFileCount() async {
    if (areAllTransfersCompleted()) {
      // TODO: CHECK
      // Увеличиваем кол-во переданных файлов
      final appSettings = AppSettingsService.instance;
      await appSettings.decreaseTransferFiles(getTotalFileCount());

      // Показывем диалог оценки приложения через коллбэк
      showLikeAppDialog();
    }
  }

  @override
  void dispose() {
    _clearAll();
    super.dispose();
  }
}
