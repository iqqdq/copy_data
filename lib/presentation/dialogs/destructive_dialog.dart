import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';

class DestructiveDialog {
  static Future<void> show(
    BuildContext context, {
    required String message,
    required String cancelTitle,
    required VoidCallback onDestructivePressed,
    String? title,
    String? destructiveTitle,
  }) async {
    final result = await showOkCancelAlertDialog(
      context: context,
      title: title ?? 'Cancel File Transfer?',
      message: message,
      cancelLabel: cancelTitle,
      okLabel: destructiveTitle ?? 'Cancel',
      isDestructiveAction: true,
    );

    if (result == OkCancelResult.ok) onDestructivePressed();
  }
}
