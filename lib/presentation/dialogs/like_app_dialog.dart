import 'dart:io';

import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../app.dart';

class LikeAppDialog {
  static Future<void> show(BuildContext context) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final isAppLiked = prefs.getBool('is_app_liked') ?? false;

    if (context.mounted && isSubscribed.value && !isAppLiked) {
      final result = await showOkCancelAlertDialog(
        context: context,
        title: 'Do you like the app?',
        message: 'We Appreciate Your Feedback',
        cancelLabel: 'No',
        okLabel: 'Yes',
        barrierDismissible: false,
      );

      await prefs.setBool('is_app_liked', true);

      if (context.mounted && result == OkCancelResult.ok) {
        await showOkAlertDialog(
          context: context,
          title: 'Please leave a review',
          message: 'Positive reviews are a powerful motivation for us to excel',
          okLabel: Platform.isIOS ? 'Go to the AppStore' : 'Go to Google Play',
        );

        // launchUrlString(AppConstants.reviewUrl); // TODO:
      }
    }
  }
}
