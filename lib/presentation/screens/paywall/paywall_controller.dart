import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class PaywallController with ChangeNotifier {
  PaywallState _state;
  PaywallState get state => _state;

  PaywallController({bool isTrial = false})
    : _state = PaywallState(isTrial: isTrial, isLoading: false);

  void switchTrial(bool value) {
    _state = _state.copyWith(isTrial: value);
    notifyListeners();
  }

  Future<void> purchase() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    await PurchaseService.instance.purchase(
      priceProductService: _state.isTrial ? weekTrialProduct : weekProduct,
    );

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }

  Future<void> restore() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      final result = await PurchaseService.instance.restore();

      if (!result) {
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
      }
    } catch (e) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      rethrow;
    }

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }

  String getCurrentPrice() => _state.isTrial
      ? weekTrialProduct.getPriceAndDurationPlus()
      : weekProduct.getPrice();
}
