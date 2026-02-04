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
  late final ProgressController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProgressController(
      service: Provider.of<FileTransferService>(context, listen: false),
      isSending: widget.isSending,
      showToast: (message) {
        if (mounted) {
          CustomToast.showToast(context: context, message: message);
        }
      },
      showLikeAppDialog: () {
        // TODO: CHECK
        if (mounted) {
          LikeAppDialog.show(context);
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cancelTransferWithDialog(String transferId) async {
    await DestructiveDialog.show(
      context,
      message: _controller.state.isSending
          ? 'Are you sure you want to stop sending files? Your transfer will be interrupted'
          : 'Are you sure you want to stop receiving files? Your transfer will be interrupted',
      cancelTitle: _controller.state.isSending
          ? 'Keep sending'
          : 'Keep receiving',
      onDestructivePressed: () async =>
          await _controller.cancelTransfer(transferId),
    );
  }

  Future<void> _cancelAllTransfersWithDialog() async {
    if (!_controller.hasAnyTransferStarted()) {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (_controller.areAllTransfersCompleteOrCancelled()) {
      if (mounted) Navigator.pop(context);
      return;
    }

    await DestructiveDialog.show(
      context,
      message: widget.isSending
          ? 'Are you sure you want to stop sending all files? All transfers will be interrupted'
          : 'Are you sure you want to stop receiving all files? All transfers will be interrupted',
      cancelTitle: widget.isSending ? 'Keep sending' : 'Keep receiving',
      onDestructivePressed: () async => await _controller.cancelAllTransfers(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;

        final activeTransfers = context
            .watch<FileTransferService>()
            .activeTransfers;

        final hasAnyTransferStarted = _controller.hasAnyTransferStarted();

        final allTransfers = _controller.getAllTransfersForDisplay();

        final groupedTransfers = _controller.groupTransfers(allTransfers);
        final photoTransfers = groupedTransfers['photos']!;
        final videoTransfers = groupedTransfers['videos']!;

        final hadPhotoTransfers = photoTransfers.isNotEmpty;
        final hadVideoTransfers = videoTransfers.isNotEmpty;

        final areAllTransfersCompleteOrCancelled = _controller
            .areAllTransfersCompleteOrCancelled();

        return Scaffold(
          appBar: CustomAppBar(
            title: state.isSending ? 'Sending files' : 'Receiving files',
            onBackPressed: _cancelAllTransfersWithDialog,
          ),
          body: !hasAnyTransferStarted && allTransfers.isEmpty
              ? const Center(child: CustomLoader())
              : ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  children: [
                    if (hadPhotoTransfers)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: hadVideoTransfers ? 16.0 : 24.0,
                        ),
                        child: ProgressTile(
                          isPhoto: true,
                          isSending: state.isSending,
                          activeTransfers: activeTransfers,
                          transfers: photoTransfers,
                          cancelledTransfers: state.cancelledTransfers,
                          onTransferCancel: _cancelTransferWithDialog,
                        ),
                      ),

                    if (hadVideoTransfers)
                      Padding(
                        padding: EdgeInsets.only(bottom: 24.0),
                        child: ProgressTile(
                          isPhoto: false,
                          isSending: state.isSending,
                          activeTransfers: activeTransfers,
                          transfers: videoTransfers,
                          cancelledTransfers: state.cancelledTransfers,
                          onTransferCancel: _cancelTransferWithDialog,
                        ),
                      ),

                    if (areAllTransfersCompleteOrCancelled &&
                        allTransfers.isNotEmpty)
                      CustomButton.primary(
                        title: 'Go to main menu',
                        onPressed: () async {
                          state.isSending
                              ? await _controller.service.stopServer()
                              : await _controller.service
                                    .clearClientTransfers();
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                  ],
                ),
        );
      },
    );
  }
}
