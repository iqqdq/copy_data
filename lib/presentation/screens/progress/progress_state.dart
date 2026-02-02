import 'package:flutter/foundation.dart';

import '../../../core/core.dart';

@immutable
class ProgressState {
  final bool isSending;
  final Map<String, bool> cancelledTransfers;
  final bool showGoToMainMenu;
  final bool shouldShowCancellationToast;
  final String? cancellationMessage;
  final bool hasTransferStarted;
  final Map<String, FileTransfer> transferHistory;
  final bool allTransfersCancelled;

  // Кэшированные данные для отображения
  final List<FileTransfer>? photoTransfers;
  final List<FileTransfer>? videoTransfers;
  final bool hadPhotoTransfers;
  final bool hadVideoTransfers;

  const ProgressState({
    required this.isSending,
    required this.cancelledTransfers,
    required this.showGoToMainMenu,
    required this.shouldShowCancellationToast,
    this.cancellationMessage,
    required this.hasTransferStarted,
    required this.transferHistory,
    required this.allTransfersCancelled,
    this.photoTransfers,
    this.videoTransfers,
    required this.hadPhotoTransfers,
    required this.hadVideoTransfers,
  });

  ProgressState copyWith({
    bool? isSending,
    Map<String, bool>? cancelledTransfers,
    bool? showGoToMainMenu,
    bool? shouldShowCancellationToast,
    String? cancellationMessage,
    bool? hasTransferStarted,
    Map<String, FileTransfer>? transferHistory,
    bool? allTransfersCancelled,
    List<FileTransfer>? photoTransfers,
    List<FileTransfer>? videoTransfers,
    bool? hadPhotoTransfers,
    bool? hadVideoTransfers,
  }) {
    return ProgressState(
      isSending: isSending ?? this.isSending,
      cancelledTransfers: cancelledTransfers ?? this.cancelledTransfers,
      showGoToMainMenu: showGoToMainMenu ?? this.showGoToMainMenu,
      shouldShowCancellationToast:
          shouldShowCancellationToast ?? this.shouldShowCancellationToast,
      cancellationMessage: cancellationMessage ?? this.cancellationMessage,
      hasTransferStarted: hasTransferStarted ?? this.hasTransferStarted,
      transferHistory: transferHistory ?? this.transferHistory,
      allTransfersCancelled:
          allTransfersCancelled ?? this.allTransfersCancelled,
      photoTransfers: photoTransfers ?? this.photoTransfers,
      videoTransfers: videoTransfers ?? this.videoTransfers,
      hadPhotoTransfers: hadPhotoTransfers ?? this.hadPhotoTransfers,
      hadVideoTransfers: hadVideoTransfers ?? this.hadVideoTransfers,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProgressState &&
        other.isSending == isSending &&
        mapEquals(other.cancelledTransfers, cancelledTransfers) &&
        other.showGoToMainMenu == showGoToMainMenu &&
        other.shouldShowCancellationToast == shouldShowCancellationToast &&
        other.cancellationMessage == cancellationMessage &&
        other.hasTransferStarted == hasTransferStarted &&
        mapEquals(other.transferHistory, transferHistory) &&
        other.allTransfersCancelled == allTransfersCancelled &&
        listEquals(other.photoTransfers, photoTransfers) &&
        listEquals(other.videoTransfers, videoTransfers) &&
        other.hadPhotoTransfers == hadPhotoTransfers &&
        other.hadVideoTransfers == hadVideoTransfers;
  }

  @override
  int get hashCode {
    return Object.hash(
      isSending,
      cancelledTransfers,
      showGoToMainMenu,
      shouldShowCancellationToast,
      cancellationMessage,
      hasTransferStarted,
      transferHistory,
      allTransfersCancelled,
      photoTransfers,
      videoTransfers,
      hadPhotoTransfers,
      hadVideoTransfers,
    );
  }
}
