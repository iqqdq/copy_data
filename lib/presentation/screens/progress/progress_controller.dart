import 'package:flutter/foundation.dart';
import '../../../core/core.dart';
import 'progress_state.dart';

typedef ShowToastCallback = void Function(String message);
typedef NavigateBackCallback = void Function();

class ProgressController extends ChangeNotifier {
  final bool isSending;
  ProgressState _state;

  ProgressState get state => _state;

  // Проверка, все ли коллбэки установлены
  bool get isReady =>
      _showToastCallback != null &&
      _navigateBackCallback != null &&
      _fileTransferService != null;

  // Коллбэки для UI
  ShowToastCallback? _showToastCallback;
  NavigateBackCallback? _navigateBackCallback;

  // Коллбэк для запросов к FileTransferService
  FileTransferService? _fileTransferService;

  ProgressController({required this.isSending})
    : _state = ProgressState(
        isSending: isSending,
        cancelledTransfers: {},
        shouldShowCancellationToast: false,
        cancellationMessage: null,
        transferHistory: {},
      );

  // Установка коллбэков
  void setCallbacks({
    required ShowToastCallback showToast,
    required NavigateBackCallback navigateBack,
    required FileTransferService service,
  }) {
    _showToastCallback = showToast;
    _navigateBackCallback = navigateBack;
    _fileTransferService = service;
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

  void showCancellationToast(String message) {
    _state = _state.copyWith(
      shouldShowCancellationToast: true,
      cancellationMessage: message,
    );
    notifyListeners();
  }

  void hideCancellationToast() {
    _state = _state.copyWith(
      shouldShowCancellationToast: false,
      cancellationMessage: null,
    );
    notifyListeners();
  }

  void clearAll() {
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
    final service = _fileTransferService;
    if (service == null) return false;

    if (service.activeTransfers.values.any((t) => t.receivedBytes > 0)) {
      return true;
    }

    if (_state.transferHistory.values.any((t) => t.receivedBytes > 0)) {
      return true;
    }

    return false;
  }

  bool areAllTransfersCompleteOrCancelled() {
    final service = _fileTransferService;
    if (service == null) return false;

    final allTransfers = <String, FileTransfer>{};

    for (final transfer in service.activeTransfers.values) {
      allTransfers[transfer.transferId] = transfer;
    }

    for (final entry in _state.transferHistory.entries) {
      if (!allTransfers.containsKey(entry.key)) {
        allTransfers[entry.key] = entry.value;
      }
    }

    if (allTransfers.isEmpty) {
      return false;
    }

    for (final transfer in allTransfers.values) {
      final isCancelled =
          _state.cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100;

      if (!isCancelled && !isCompleted) {
        return false;
      }
    }

    return true;
  }

  List<FileTransfer> getAllTransfersForDisplay() {
    final service = _fileTransferService;
    if (service == null) return [];

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
    final service = _fileTransferService;
    if (service == null) return;

    final transfer = service.activeTransfers[transferId];
    if (transfer != null) {
      final transferCopy = FileTransfer(
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

      addToTransferHistory(transfer.transferId, transferCopy);
    }

    addCancelledTransfer(transferId);
    await service.cancelTransfer(transferId);
  }

  Future<void> cancelAllTransfers() async {
    final service = _fileTransferService;
    if (service == null) return;

    final activeTransfers = service.activeTransfers.values.toList();

    for (final transfer in activeTransfers) {
      final isCancelled =
          _state.cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100;

      if (!isCancelled && !isCompleted) {
        final transferCopy = FileTransfer(
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

        addToTransferHistory(transfer.transferId, transferCopy);
        addCancelledTransfer(transfer.transferId);
        await service.cancelTransfer(transfer.transferId);
      }
    }
  }

  void handleRemoteCancellation({
    required String message,
    required String? transferId,
  }) {
    showCancellationToast(message);

    if (transferId != null) {
      addCancelledTransfer(transferId);

      final service = _fileTransferService;
      if (service != null) {
        final transfer = service.activeTransfers[transferId];
        if (transfer != null) {
          final transferCopy = FileTransfer(
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

          addToTransferHistory(transfer.transferId, transferCopy);
        }
      }
    }

    // Показываем тост через коллбэк
    if (_showToastCallback != null) {
      _showToastCallback!(message);
      hideCancellationToast();
    }
  }

  Future<void> handleGoToMainMenu() async {
    final service = _fileTransferService;
    if (service == null) return;

    if (_state.isSending) {
      await service.stopServer();
    } else {
      await service.clearClientTransfers();
    }

    // Навигация через коллбэк
    if (_navigateBackCallback != null) {
      _navigateBackCallback!();
    }
  }

  @override
  void dispose() {
    clearAll();
    _showToastCallback = null;
    _navigateBackCallback = null;
    _fileTransferService = null;

    super.dispose();
  }
}
