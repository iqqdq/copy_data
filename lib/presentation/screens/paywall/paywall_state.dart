import 'package:flutter/foundation.dart';

@immutable
class PaywallState {
  final bool isTrial;
  final bool isLoading;

  const PaywallState({required this.isTrial, required this.isLoading});

  PaywallState copyWith({bool? isTrial, bool? isLoading}) {
    return PaywallState(
      isTrial: isTrial ?? this.isTrial,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PaywallState &&
        other.isTrial == isTrial &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode {
    return Object.hash(isTrial, isLoading);
  }
}
