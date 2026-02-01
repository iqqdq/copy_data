import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';

class PremiumRequiredDialog {
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onGetPermiumPressed,
  }) async {
    final result = await showOkCancelAlertDialog(
      context: context,
      title: 'Premium Required',
      message:
          'Sending files to Android devices is available only with a Premium subscription',
      okLabel: 'Get Premium',
    );

    if (result == OkCancelResult.ok) ;
  }
}
