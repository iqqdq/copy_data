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
  bool _isTransferCompleted = false;

  bool _checkShowGoToMainMenu(FileTransferService service) {
    final transfers = service.activeTransfers.values.toList();

    if (transfers.isEmpty) {
      return true;
    }

    // Проверяем, все ли передачи завершены (прогресс = 100%)
    final allCompleted = transfers.every((t) => t.progress >= 100);
    return allCompleted;
  }

  bool _checkAllTransfersCancelled(FileTransferService service) {
    final transfers = service.activeTransfers.values.toList();

    if (transfers.isEmpty) return false;

    // Проверяем, все ли передачи отменены (есть в карте _cancelledTransfers)
    final activeTransferIds = transfers.map((t) => t.transferId).toSet();
    final cancelledTransferIds = _cancelledTransfers.keys
        .where((id) => _cancelledTransfers[id] == true)
        .toSet();

    // Все активные передачи должны быть отменены
    return activeTransferIds.every((id) => cancelledTransferIds.contains(id));
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
        setState(() => _cancelledTransfers[transferId] = true);

        await service.cancelTransfer(transferId);

        if (mounted) {
          // TODO: SEND MESSAGE TO SENDER/RECEIVER
          CustomToast.showToast(
            context: context,
            message: widget.isSending
                ? 'The sender canceled the transfer'
                : 'The receiver canceled the transfer',
          );

          // Обновляем состояние кнопки после отмены
          final showButton = _checkShowGoToMainMenu(service);

          if (showButton != _isTransferCompleted) {
            setState(() => _isTransferCompleted = showButton);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);
    final transfers = service.activeTransfers.values.toList();

    // Автоматически показываем кнопку "В главное меню" при завершении
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final showButton = _checkShowGoToMainMenu(service);
        if (showButton != _isTransferCompleted) {
          setState(() {
            _isTransferCompleted = showButton;
          });
        }
      }
    });

    // Группируем по типу
    final photoTransfers = transfers
        .where(
          (t) => t.fileType.startsWith('image/') || t.fileType == 'image/mixed',
        )
        .toList();

    final videoTransfers = transfers
        .where(
          (t) => t.fileType.startsWith('video/') || t.fileType == 'video/mixed',
        )
        .toList();

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.isSending ? 'Sending files' : 'Receiving files',
      ),
      body: photoTransfers.isEmpty && videoTransfers.isEmpty
          ? const Center(child: CustomLoader())
          : ListView(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              children: [
                if (photoTransfers.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: ProgressTile(
                      isPhoto: true,
                      isSending: widget.isSending,
                      service: service,
                      transfers: transfers,
                      cancelledTransfers: _cancelledTransfers,
                      onTransferCancel: (id) =>
                          _cancelTransfer(service: service, transferId: id),
                    ),
                  ),

                // Карточка для видео
                if (videoTransfers.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 24.0),
                    child: ProgressTile(
                      isPhoto: false,
                      isSending: widget.isSending,
                      service: service,
                      transfers: transfers,
                      cancelledTransfers: _cancelledTransfers,
                      onTransferCancel: (id) =>
                          _cancelTransfer(service: service, transferId: id),
                    ),
                  ),

                // Кнопка "В главное меню" показывается только при завершении всех передач
                if (_isTransferCompleted && transfers.isNotEmpty)
                  CustomButton.primary(
                    title: 'Go to main menu',
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
    );
  }
}
