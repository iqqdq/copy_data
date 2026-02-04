import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String? cancelTitle,
  }) async {
    final result = await showOkCancelAlertDialog(
      context: context,
      title: title,
      message: message,
      cancelLabel: cancelTitle ?? 'Close',
      okLabel: 'Settings',
      barrierDismissible: false,
    );

    if (result == OkCancelResult.ok) openAppSettings();
  }
}
