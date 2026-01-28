import 'package:flutter/cupertino.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';

class SubscriptionRequiredDialog {
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? message,
    String? okTitle,
    String? cancelTitle,
  }) async => await showOkCancelAlertDialog(
    context: context,
    title: title ?? 'Subscription Required',
    message:
        message ??
        'To receive files, the connected iOS device must have an active Premium subscription. Please purchase it on the iOS device',
    okLabel: okTitle ?? 'OK',
    barrierDismissible: false,
  );
}
