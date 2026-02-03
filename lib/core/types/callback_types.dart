import 'dart:ui';

import '../core.dart';

typedef ShowDialogCallback =
    Future<void> Function(String title, String message);
typedef NavigateCallback =
    Future<void> Function(String route, {Object? arguments});
typedef FileTransferServiceCallback = FileTransferService Function();
typedef ShowToastCallback = void Function(String message);
typedef ShowPremiumDialogCallback =
    Future<void> Function(
      String title,
      String message,
      VoidCallback onGetPremiumPressed,
    );
