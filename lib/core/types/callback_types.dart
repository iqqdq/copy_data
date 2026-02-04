import 'dart:ui';

typedef ShowDialogCallback =
    Future<void> Function(String title, String message);
typedef NavigateToCallback =
    Future<void> Function(String route, {Object? arguments});
typedef ShowToastCallback = void Function(String message);
typedef ShowLikeAppDialogCallback = void Function();
typedef ShowPremiumDialogCallback =
    Future<void> Function(
      String title,
      String message,
      VoidCallback onGetPremiumPressed,
    );
