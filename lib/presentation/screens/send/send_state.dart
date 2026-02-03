import 'package:flutter/foundation.dart';

@immutable
class SendState {
  final int selectedIndex;
  final bool autoSendTriggered;
  final bool isConnecting;
  final bool isConnected;
  final Map<int, bool> tabInitialized;
  final bool isClientConnected;
  final String? sendError;

  const SendState({
    required this.selectedIndex,
    required this.autoSendTriggered,
    required this.isConnecting,
    required this.isConnected,
    required this.tabInitialized,
    required this.isClientConnected,
    this.sendError,
  });

  SendState copyWith({
    int? selectedIndex,
    bool? autoSendTriggered,
    bool? isConnecting,
    bool? isConnected,
    Map<int, bool>? tabInitialized,
    bool? isClientConnected,
    String? sendError,
  }) {
    return SendState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      autoSendTriggered: autoSendTriggered ?? this.autoSendTriggered,
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      tabInitialized: tabInitialized ?? this.tabInitialized,
      isClientConnected: isClientConnected ?? this.isClientConnected,
      sendError: sendError ?? this.sendError,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SendState &&
        other.selectedIndex == selectedIndex &&
        other.autoSendTriggered == autoSendTriggered &&
        other.isConnecting == isConnecting &&
        other.isConnected == isConnected &&
        mapEquals(other.tabInitialized, tabInitialized) &&
        other.isClientConnected == isClientConnected &&
        other.sendError == sendError;
  }

  @override
  int get hashCode {
    return Object.hash(
      selectedIndex,
      autoSendTriggered,
      isConnecting,
      isConnected,
      tabInitialized,
      isClientConnected,
      sendError,
    );
  }
}
