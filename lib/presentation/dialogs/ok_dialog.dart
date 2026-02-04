import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';

class OkDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
  }) async =>
      await showOkAlertDialog(context: context, title: title, message: message);
}
