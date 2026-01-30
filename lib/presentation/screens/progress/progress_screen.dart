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

    // Показываем кнопку "Go to main menu" если нет активных передач
    _updateShowMainMenuButton();
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

    // Проверяем, все ли передачи завершены (прогресс = 100%) или отменены
    final allCompleted = transfers.every((t) => t.progress >= 100);
    // Проверяем, отменены ли все передачи
    final allCancelled = transfers.every(
      (t) =>
          _cancelledTransfers[t.transferId] == true ||
          t.progress < 100 && t.receivedBytes > 0,
    );

    _showGoToMainMenu = allCompleted || allCancelled;

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
          // НЕ показываем тост на этой стороне
          // Вместо этого запоминаем сообщение для отображения на противоположной стороне
          // Сообщение об отмене будет получено через WebSocket и обработано в FileTransferService

          // Показываем кнопку "Go to main menu" после отмены
          setState(() {
            _showGoToMainMenu = true;
          });
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
        _showGoToMainMenu = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<FileTransferService>(context);
    final transfers = service.activeTransfers.values.toList();

    // Слушаем сообщения об отмене из сервиса
    // В реальном приложении это может быть через Stream или другой механизм
    // Здесь используем условную логику

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
      body: transfers.isEmpty
          ? const Center(child: CustomLoader())
          : ListView(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              children: [
                if (photoTransfers.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: videoTransfers.isNotEmpty ? 16.0 : 24.0,
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

                // Карточка для видео
                if (videoTransfers.isNotEmpty)
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

                // Кнопка "В главное меню" показывается при завершении всех передач или отмене
                if (_showGoToMainMenu)
                  CustomButton.primary(
                    title: 'Go to main menu',
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
    );
  }
}
