import 'package:flutter/foundation.dart';

@immutable
class ScannerState {
  final bool isConnecting;
  final bool isConnected;
  final bool isDialogShowing;
  final String? qrData;
  final String? connectionError;

  const ScannerState({
    required this.isConnecting,
    required this.isConnected,
    required this.isDialogShowing,
    this.qrData,
    this.connectionError,
  });

  ScannerState copyWith({
    bool? isConnecting,
    bool? isConnected,
    bool? isDialogShowing,
    String? qrData,
    String? connectionError,
  }) {
    return ScannerState(
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      isDialogShowing: isDialogShowing ?? this.isDialogShowing,
      qrData: qrData ?? this.qrData,
      connectionError: connectionError ?? this.connectionError,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ScannerState &&
        other.isConnecting == isConnecting &&
        other.isConnected == isConnected &&
        other.isDialogShowing == isDialogShowing &&
        other.qrData == qrData &&
        other.connectionError == connectionError;
  }

  @override
  int get hashCode {
    return Object.hash(
      isConnecting,
      isConnected,
      isDialogShowing,
      qrData,
      connectionError,
    );
  }
}
