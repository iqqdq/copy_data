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
    if (transfers.isEmpty) return SizedBox.shrink();

    // Проверяем, есть ли отмененные передачи в этой группе
    bool hasCancelledTransfer = transfers.any(
      (t) => cancelledTransfers[t.transferId] == true,
    );

    // Считаем общую статистику по всем передачам в группе
    final progress = _calculateAverageProgress(transfers);
    int totalFiles = 0;
    int completedFiles = 0;
    int totalReceived = 0;
    int totalSize = 0;

    for (final transfer in transfers) {
      totalFiles += transfer.totalFiles;
      completedFiles += transfer.completedFiles;
      totalReceived += transfer.receivedBytes;
      totalSize += transfer.fileSize;
    }

    // Если передача отменена, но прогресс 100%, считаем ее завершенной
    // (возможно отмена произошла уже после фактического завершения)
    final isCancelled = hasCancelledTransfer;

    // Передача считается завершенной если:
    // 1. Прогресс 100% ИЛИ
    // 2. Все файлы получены (для клиента) И при этом не отменена
    final isCompleted = _isTransferCompleted(
      progress: progress,
      hasCancelledTransfer: hasCancelledTransfer,
      totalFiles: totalFiles,
      completedFiles: completedFiles,
      isSending: isSending,
    );

    // Определяем финальное состояние для отображения
    final isFinalState = isCompleted || isCancelled;
    final showAsCompleted = isCompleted && !isCancelled;

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
                              isPhoto
                                  ? (isSending
                                        ? 'Sending Photos'
                                        : 'Receiving Photos')
                                  : (isSending
                                        ? 'Sending Videos'
                                        : 'Receiving Videos'),
                              style: AppTypography.link16Medium,
                            ),
                          ),

                          if (showAsCompleted)
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
              child: Stack(
                children: [
                  // Фоновый прогресс бар
                  Container(
                    height: 8.0,
                    decoration: BoxDecoration(
                      color: AppColors.extraLightGray,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),

                  // Заполненная часть прогресса
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    height: 8.0,
                    width:
                        (MediaQuery.of(context).size.width - 96) *
                        (progress / 100),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                ],
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
              _buildProgressText(
                showAsCompleted,
                progress,
                totalReceived,
                totalSize,
                isSending: isSending,
              ),
            ],
          ),

          // Кнопка отмены показываем только если передача не в финальном состоянии
          if (!isFinalState)
            Padding(
              padding: EdgeInsets.only(top: 16.0),
              child: CustomButton.primary(
                title: isSending ? 'Cancel sending' : 'Cancel receiving',
                onPressed: () {
                  // Отменяем все неотмененные передачи в этой группе
                  for (final transfer in transfers) {
                    if (cancelledTransfers[transfer.transferId] != true) {
                      onTransferCancel(transfer.transferId);
                    }
                  }
                },
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

  // Логика определения завершенности передачи - ФИКС ДЛЯ 100% ПРОГРЕССА
  bool _isTransferCompleted({
    required double progress,
    required bool hasCancelledTransfer,
    required int totalFiles,
    required int completedFiles,
    required bool isSending,
  }) {
    // ВАЖНО: Если прогресс 100%, передача считается завершенной независимо от флага отмены
    // (возможно отмена произошла уже после фактического завершения)
    if (progress >= 100) return true;

    // Если передача отменена, она не считается завершенной (кроме случая выше)
    if (hasCancelledTransfer) return false;

    // Для клиента (прием): завершено, если получены все файлы
    if (!isSending) {
      return completedFiles >= totalFiles && totalFiles > 0;
    }

    // Для сервера (отправка): завершено, если прогресс 100%
    return false; // уже проверено выше
  }

  Widget _buildProgressText(
    bool showAsCompleted,
    double progress,
    int totalReceived,
    int totalSize, {
    required bool isSending,
  }) {
    if (showAsCompleted) {
      // Для завершенных показываем общий размер с акцентным цветом
      return Text(
        FileUtils.formatBytes(totalSize, totalSize, showBoth: false),
        style: AppTypography.link12Regular.copyWith(color: AppColors.accent),
      );
    } else {
      // Для незавершенных показываем прогресс с выделением
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
