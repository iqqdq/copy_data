import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:url_launcher/url_launcher_string.dart';

import '../../../core/core.dart';
import 'settings_state.dart';

class SettingsController with ChangeNotifier {
  final SettingsState _state;
  SettingsState get state => _state;

  SettingsController()
    : _state = SettingsState(
        isLoading: false,
        titles: ['Privacy Policy', 'Terms of Use', 'Share App', 'Support'],
        assets: ['lock', 'document', 'share', 'headset'],
      );

  Future<void> openUrl(int index) async {
    final url = index == 0
        ? AppConstants.privacyUrl
        : index == 1
        ? AppConstants.termsUrl
        : AppConstants.supportUrl;

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    }
  }

  void shareApp() => SharePlus.instance.share(
    ShareParams(uri: Uri(path: AppConstants.shareUrl)),
  );
}
