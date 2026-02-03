import 'dart:io';

import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/core.dart';

class LikeAppDialog {
  static Future<void> show(BuildContext context) async {
    final appSettings = AppSettingsService.instance;

    if (context.mounted && isSubscribed.value && !appSettings.isAppLiked) {
      final result = await showOkCancelAlertDialog(
        context: context,
        title: 'Do you like the app?',
        message: 'We Appreciate Your Feedback',
        cancelLabel: 'No',
        okLabel: 'Yes',
        barrierDismissible: false,
      );

      await appSettings.likeApp();

      if (context.mounted && result == OkCancelResult.ok) {
        await showOkAlertDialog(
          context: context,
          title: 'Please leave a review',
          message: 'Positive reviews are a powerful motivation for us to excel',
          okLabel: Platform.isIOS ? 'Go to the AppStore' : 'Go to Google Play',
        );

        launchUrlString(AppConstants.reviewUrl);
      }
    }
  }
}
