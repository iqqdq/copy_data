import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';

class PremiumRequiredDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onGetPermiumPressed,
  }) async {
    final result = await showOkCancelAlertDialog(
      context: context,
      title: title,
      message: message,
      okLabel: 'Get Premium',
    );

    if (result == OkCancelResult.ok) onGetPermiumPressed();
  }
}
