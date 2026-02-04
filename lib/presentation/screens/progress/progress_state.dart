import 'package:flutter/foundation.dart';

import '../../../core/core.dart';

@immutable
class ProgressState {
  final bool isSending;
  final Map<String, bool> cancelledTransfers;
  final Map<String, FileTransfer> transferHistory;

  const ProgressState({
    required this.isSending,
    required this.cancelledTransfers,
    required this.transferHistory,
  });

  ProgressState copyWith({
    bool? isSending,
    Map<String, FileTransfer>? activeTransfets,
    Map<String, bool>? cancelledTransfers,
    bool? shouldShowCancellationToast,
    String? cancellationMessage,
    Map<String, FileTransfer>? transferHistory,
  }) {
    return ProgressState(
      isSending: isSending ?? this.isSending,
      cancelledTransfers: cancelledTransfers ?? this.cancelledTransfers,
      transferHistory: transferHistory ?? this.transferHistory,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProgressState &&
        other.isSending == isSending &&
        mapEquals(other.cancelledTransfers, cancelledTransfers) &&
        mapEquals(other.transferHistory, transferHistory);
  }

  @override
  int get hashCode {
    return Object.hash(isSending, cancelledTransfers, transferHistory);
  }
}
