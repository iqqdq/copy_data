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

  // Отслеживаем завершенные передачи для предотвращения повторных уведомлений
  final Set<String> _completedTransfers = {};
  bool _hasShownCompletionDialog = false;

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
    _setupServiceCallbacks();
    _startMonitoring();
  }

  // MARK: - Настройка колбэков

  void _setupServiceCallbacks() {
    // Колбэк для удаленной отмены
    service.setRemoteCancellationCallback((transferId) {
      _handleRemoteCancellation(transferId);
    });
  }

  void _startMonitoring() {
    // Слушаем изменения в сервисе
    service.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    _checkForCompletedTransfers();
    notifyListeners();
  }

  // MARK: - Проверка завершения передач

  void _checkForCompletedTransfers() {
    final activeTransfers = service.activeTransfers;

    if (activeTransfers.isEmpty) return;

    // Проверяем каждую активную передачу
    for (final transfer in activeTransfers.values) {
      final transferId = transfer.transferId;
      final isCancelled = _state.cancelledTransfers[transferId] == true;
      final isCompleted = transfer.progress >= 100.0;
      final isInHistory = _state.transferHistory.containsKey(transferId);

      // Если передача завершена и еще не в истории
      if (isCompleted && !isCancelled && !isInHistory) {
        _handleTransferCompleted(transferId, transfer);
      }
    }

    // Проверяем, все ли передачи завершены
    if (_areAllTransfersCompleted()) {
      _handleAllTransfersCompleted();
    }
  }

  bool _areAllTransfersCompleted() {
    final activeTransfers = service.activeTransfers;
    if (activeTransfers.isEmpty) return false;

    bool hasCompletedTransfer = false;

    for (final transfer in activeTransfers.values) {
      final transferId = transfer.transferId;
      final isCancelled = _state.cancelledTransfers[transferId] == true;
      final isCompleted = transfer.progress >= 100.0;

      // Если есть хоть одна неотмененная и незавершенная передача
      if (!isCancelled && !isCompleted) {
        return false;
      }

      // Проверяем, есть ли хотя бы одна успешно завершенная передача
      if (!isCancelled && isCompleted) {
        hasCompletedTransfer = true;
      }
    }

    return hasCompletedTransfer;
  }

  // MARK: - Обработчики событий

  void _handleRemoteCancellation(String transferId) {
    final message = isSending
        ? 'The receiver canceled the transfer'
        : 'The sender canceled the transfer';

    handleRemoteCancellation(message: message, transferId: transferId);
  }

  void _handleTransferCompleted(String transferId, FileTransfer transfer) {
    print('✅ Передача завершена: ${transfer.fileName} ($transferId)');

    // Добавляем в историю
    addToTransferHistory(transferId, transfer.copy());

    // Добавляем в отслеживаемые завершенные
    _completedTransfers.add(transferId);

    // Обновляем счетчик файлов
    _updateFileCountForTransfer(transfer);

    notifyListeners();
  }

  void _handleAllTransfersCompleted() {
    if (_hasShownCompletionDialog) return;

    print('✅ Все передачи успешно завершены!');
    _hasShownCompletionDialog = true;

    // Показываем диалог оценки
    Future.delayed(Duration(milliseconds: 500), () {
      if (isSending) {
        showLikeAppDialog();
      }
    });
  }

  // MARK: - Работа со счетчиком файлов

  Future<void> _updateFileCountForTransfer(FileTransfer transfer) async {
    try {
      if (transfer.totalFiles > 0) {
        final appSettings = AppSettingsService.instance;
        await appSettings.increaseTransferFiles(transfer.totalFiles);

        print(
          '✅ Передано файлов: ${transfer.totalFiles} из ${transfer.fileName}',
        );
      }
    } catch (e) {
      print('❌ Ошибка обновления счетчика файлов: $e');
    }
  }

  // MARK: - State Updates

  void addCancelledTransfer(String transferId) {
    final newCancelledTransfers = Map<String, bool>.from(
      _state.cancelledTransfers,
    );
    newCancelledTransfers[transferId] = true;

    _state = _state.copyWith(cancelledTransfers: newCancelledTransfers);

    // Добавляем в историю, если передача была активна
    final transfer = service.activeTransfers[transferId];
    if (transfer != null && !_state.transferHistory.containsKey(transferId)) {
      addToTransferHistory(transferId, transfer.copy());
    }

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

  void clearAll() {
    service.clearClientTransfers();

    _state = _state.copyWith(
      cancelledTransfers: {},
      transferHistory: {},
      shouldShowCancellationToast: false,
      cancellationMessage: null,
    );

    _completedTransfers.clear();
    _hasShownCompletionDialog = false;

    notifyListeners();
  }

  // MARK: - Публичные методы

  bool hasAnyTransferStarted() {
    // Проверяем активные передачи
    if (service.activeTransfers.values.any((t) => t.receivedBytes > 0)) {
      return true;
    }

    // Проверяем историю
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
    return _areAllTransfersCompleted();
  }

  bool areAllTransfersCompleteOrCancelled() {
    final allTransfers = <String, FileTransfer>{};

    // Активные передачи
    for (final transfer in service.activeTransfers.values) {
      allTransfers[transfer.transferId] = transfer;
    }

    // Передачи из истории
    for (final entry in _state.transferHistory.entries) {
      if (!allTransfers.containsKey(entry.key)) {
        allTransfers[entry.key] = entry.value;
      }
    }

    if (allTransfers.isEmpty) return false;

    for (final transfer in allTransfers.values) {
      final isCancelled =
          _state.cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100.0;

      if (!isCancelled && !isCompleted) {
        return false;
      }
    }

    return true;
  }

  List<FileTransfer> getAllTransfersForDisplay() {
    final allTransfersMap = <String, FileTransfer>{};

    // 1. Активные передачи (все)
    for (final transfer in service.activeTransfers.values) {
      allTransfersMap[transfer.transferId] = transfer;
    }

    // 2. Передачи из истории (только завершенные или отмененные)
    for (final entry in _state.transferHistory.entries) {
      final transfer = entry.value;
      final isCancelled =
          _state.cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100.0;

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
    addCancelledTransfer(transferId);
    await service.cancelTransfer(transferId);
  }

  Future<void> cancelAllTransfers() async {
    final activeTransfers = service.activeTransfers.values.toList();

    for (final transfer in activeTransfers) {
      final isCancelled =
          _state.cancelledTransfers[transfer.transferId] == true;
      final isCompleted = transfer.progress >= 100.0;

      if (!isCancelled && !isCompleted) {
        addCancelledTransfer(transfer.transferId);
        await service.cancelTransfer(transfer.transferId);
      }
    }
  }

  void handleRemoteCancellation({
    required String message,
    required String? transferId,
  }) {
    if (transferId != null) {
      addCancelledTransfer(transferId);
    }

    // Показываем тост
    showToast(message);
  }

  @override
  void dispose() {
    service.removeListener(_onServiceChanged);
    clearAll();
    super.dispose();
  }
}
