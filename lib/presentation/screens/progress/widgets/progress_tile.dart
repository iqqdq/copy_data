import 'package:flutter/material.dart';
import 'package:local_file_transfer/presentation/presentation.dart';

import '../../../../core/core.dart';

class ProgressTile extends StatelessWidget {
  final bool isPhoto;
  final bool isSending;
  final FileTransferService service;
  final List<FileTransfer> transfers;
  final Map<String, bool> cancelledTransfers;
  final Function(String id) onTransferCancel;

  const ProgressTile({
    super.key,
    required this.isPhoto,
    required this.isSending,
    required this.service,
    required this.transfers,
    required this.cancelledTransfers,
    required this.onTransferCancel,
  });

  @override
  Widget build(BuildContext context) {
    final progress = _calculateAverageProgress(transfers);
    final completedFiles = transfers.first.completedFiles;
    final totalFiles = transfers.first.totalFiles;
    final transferId = transfers.first.transferId;
    final isCancelled = cancelledTransfers[transferId] ?? false;
    final isCompleted = progress >= 100;

    int totalReceived = 0;
    int totalSize = 0;

    for (final transfer in transfers) {
      totalReceived += transfer.receivedBytes;
      totalSize += transfer.fileSize;
    }

    return SizedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок и прогресс
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: Image.asset(
                  'assets/images/${isPhoto ? 'photo' : 'video'}.png',
                  width: 32.0,
                  height: 32.0,
                ),
              ),

              Padding(
                padding: EdgeInsets.only(bottom: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Text(
                              isPhoto ? 'Sending Photos' : 'Sending Videos',
                              style: AppTypography.link16Medium,
                            ),
                          ),

                          if (isCompleted && !isCancelled)
                            Image.asset(
                              'assets/images/done.png',
                              width: 24.0,
                              height: 24.0,
                            ),
                        ],
                      ),
                    ),

                    Text(
                      '$completedFiles of $totalFiles',
                      style: AppTypography.link12Regular.copyWith(
                        color: AppColors.lightGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Прогресс бар
          Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 8.0,
                backgroundColor: AppColors.extraLightGray,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCancelled ? AppColors.extraLightGray : AppColors.accent,
                ),
              ),
            ),
          ),

          // Детали прогресса
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${progress.toStringAsFixed(0)}%',
                style: AppTypography.link12Regular.copyWith(
                  color: AppColors.accent,
                ),
              ),

              // Виджет с текстом прогресса
              _buildProgressText(isCompleted, totalReceived, totalSize),
            ],
          ),

          // Кнопка отмены (показываем только если передача не завершена и не отменена)
          if (progress < 100 && !isCancelled)
            Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: CustomButton.primary(
                title: isSending ? 'Cancel sending' : 'Cancel receiving',
                onPressed: () => onTransferCancel(transferId),
              ),
            ),
        ],
      ),
    ).withDecoration(
      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      color: AppColors.white,
      borderRadius: BorderRadius.circular(32.0),
      borderWidth: 3.0,
      borderColor: AppColors.black,
    );
  }

  Widget _buildProgressText(
    bool isCompleted,
    int totalReceived,
    int totalSize,
  ) {
    if (isCompleted) {
      // Показываем только общий размер с акцентным цветом
      return Text(
        FileUtils.formatBytes(totalSize, totalSize, showBoth: false),
        style: AppTypography.link12Regular.copyWith(color: AppColors.accent),
      );
    } else {
      // Показываем прогресс с выделением переданных байтов
      final fullText = FileUtils.formatBytes(
        totalReceived,
        totalSize,
        showBoth: true,
      );
      final parts = fullText.split(' / ');

      if (parts.length != 2) {
        return Text(
          fullText,
          style: AppTypography.link12Regular.copyWith(
            color: AppColors.lightGray,
          ),
        );
      }

      final bytesPart = parts[0];

      return fullText.toHighlightedText(
        highlightedWords: [bytesPart],
        style: AppTypography.link12Regular.copyWith(color: AppColors.lightGray),
        highlightColor: AppColors.accent,
      );
    }
  }

  double _calculateAverageProgress(List<FileTransfer> transfers) {
    if (transfers.isEmpty) return 0.0;
    final total = transfers.fold(
      0.0,
      (sum, transfer) => sum + transfer.progress,
    );
    return total / transfers.length;
  }
}
