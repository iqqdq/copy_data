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

  // Храним историю передач, чтобы показывать карточки даже после отмены
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

    _updateShowMainMenuButton();

    // Проверяем, нужно ли показать уведомление об отмене
    if (_shouldShowCancellationToast && _cancellationMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CustomToast.showToast(context: context, message: _cancellationMessage!);
        _shouldShowCancellationToast = false;
        _cancellationMessage = null;
      });
    }
  }

  void _updateShowMainMenuButton() {
    final service = Provider.of<FileTransferService>(context, listen: false);
    final transfers = service.activeTransfers.values.toList();

    // Обновляем историю передач
    for (final transfer in transfers) {
      if (!_transferHistory.containsKey(transfer.transferId)) {
        _transferHistory[transfer.transferId] = transfer;
      }
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

    if (transfers.isEmpty && _transferHistory.isEmpty) {
      // Никогда не было передач
      _showGoToMainMenu = false;
      _allTransfersCancelled = false;
    } else {
      // Проверяем состояние текущих и исторических передач
      final allTransfers = [...transfers, ..._transferHistory.values];
      final uniqueTransfers = <String, FileTransfer>{};

      for (final transfer in allTransfers) {
        uniqueTransfers[transfer.transferId] = transfer;
      }

      final allTransfersList = uniqueTransfers.values.toList();

      if (allTransfersList.isEmpty) {
        _showGoToMainMenu = false;
        _allTransfersCancelled = false;
      } else {
        bool allCompletedOrCancelled = true;
        bool anyActive = false;

        for (final transfer in allTransfersList) {
          final isCancelled = _cancelledTransfers[transfer.transferId] == true;
          final isCompleted = transfer.progress >= 100;
          final hasStarted = transfer.receivedBytes > 0;

          if (hasStarted && !isCancelled && !isCompleted) {
            allCompletedOrCancelled = false;
            anyActive = true;
          } else if (!hasStarted && !isCancelled) {
            // Передача еще не началась и не отменена - считаем как активную
            allCompletedOrCancelled = false;
          }
        }

        // Показываем кнопку только если ВСЕ передачи завершены ИЛИ отменены
        _showGoToMainMenu = allCompletedOrCancelled;

        _allTransfersCancelled =
            allTransfersList.isNotEmpty &&
            !anyActive &&
            allTransfersList.every(
              (t) => _cancelledTransfers[t.transferId] == true,
            );
      }
    }

    if (mounted) {
      setState(() {});
    }
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
        // Помечаем передачу как отмененную
        setState(() => _cancelledTransfers[transferId] = true);

        // Отменяем передачу в сервисе
        await service.cancelTransfer(transferId);

        // Обновляем состояние кнопки после отмены
        _updateShowMainMenuButton();

        if (mounted) {
          // Показываем кнопку "Go to main menu" только если все передачи отменены
          _updateShowMainMenuButton();
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
        // Показываем кнопку только после проверки всех передач
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateShowMainMenuButton();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);
    final transfers = service.activeTransfers.values.toList();

    // Используем историю передач, если текущие передачи пустые
    final allTransfers = transfers.isNotEmpty
        ? transfers
        : _transferHistory.values.toList();

    // Группируем по типу из всех доступных передач
    final photoTransfers = allTransfers
        .where(
          (t) => t.fileType.startsWith('image/') || t.fileType == 'image/mixed',
        )
        .toList();

    final videoTransfers = allTransfers
        .where(
          (t) => t.fileType.startsWith('video/') || t.fileType == 'video/mixed',
        )
        .toList();

    // Определяем, были ли фото/видео передачи (даже если отменены)
    final hadPhotoTransfers = photoTransfers.isNotEmpty;
    final hadVideoTransfers = videoTransfers.isNotEmpty;

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.isSending ? 'Sending files' : 'Receiving files',
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
                      transfers: allTransfers,
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
                      transfers: allTransfers,
                      cancelledTransfers: _cancelledTransfers,
                      onTransferCancel: (id) =>
                          _cancelTransfer(service: service, transferId: id),
                    ),
                  ),

                // Кнопка "В главное меню" показывается только при завершении ВСЕХ передач
                // или отмене ВСЕХ передач
                if (_showGoToMainMenu || _allTransfersCancelled)
                  CustomButton.primary(
                    title: 'Go to main menu',
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
    );
  }
}
