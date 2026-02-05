import 'package:flutter/material.dart';

import '../../../core/core.dart';
import 'onboard_state.dart';

class OnboardController with ChangeNotifier {
  OnboardState _state;
  OnboardState get state => _state;

  OnboardController() : _state = OnboardState(index: 0, isLoading: false);

  void updatePage() {
    _state = _state.copyWith(index: _state.index + 1);
    notifyListeners();
  }

  Future completeOnboarding() async =>
      await AppSettingsService.instance.skipOnboard();

  Future restore() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    await PurchaseService.instance.restore();

    _state = _state.copyWith(isLoading: false);
    notifyListeners();
  }
}
