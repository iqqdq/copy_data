import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Open the App',
      'Connect Devices',
      'Enable Permissions',
      'Select a Mode',
      'Choose Files',
      'Complete Transfer',
    ];

    final subtitles = [
      'Download and launch the app on both devices (iOS / Android)',
      'Make sure both devices are connected to the same Wi‑Fi network',
      'Allow the app to access files, Wi‑Fi, and camera settings',
      'Tap Transfer to send files, or Receive to get them',
      'Pick the photos or videos you want to transfer',
      'Scan the QR code and wait for the process to finish',
    ];

    final highlights = [
      ['iOS / Android'],
      ['both devices'],
      ['to access'],
      ['Transfer', 'Receive'],
      ['Pick'],
      ['QR code'],
    ];

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Tutorial',
        automaticallyImplyLeading: Navigator.canPop(context),
      ),
      body: ListView.separated(
        padding: EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 8.0,
        ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 20.0),
        itemCount: titles.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16.0),
        itemBuilder: (context, index) {
          final item = TutorialTile(
            asset: titles[index].toLowerCase().replaceAll(' ', '_'),
            title: '${index + 1}. ${titles[index]}',
            subtitle: index == 0
                ? ClickablePlatformText(
                    title: subtitles[index],
                    highlighted: 'iOS / Android',
                    onPressed: () {
                      if (Platform.isIOS) {
                        // TODO: OPEN STORE
                        print('Open AppStore');
                      } else {
                        print('Open GooglePlay');
                      }
                    },
                  )
                : subtitles[index].toHighlightedText(
                    highlightedWords: highlights[index],
                    baseStyle: AppTypography.body16Light,
                    highlightColor: AppColors.accent,
                  ),
            hint: index == 1
                ? TutorialHint(
                    title: '''
If Wi-Fi isn't available,
enable hotspot mode on one device
and connect the other to it.
''',
                    highlighted: 'Wi-Fi isn-t available',
                  )
                : const SizedBox.shrink(),
          );

          return index == titles.length - 1
              ? CustomButton.primary(
                  title: 'Got it',
                  onPressed: () =>
                      // TODO: REPLACE WITH NAMED ROUTE & SAVE STATUS
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (builder) => const MainScreen(),
                        ),
                      ),
                )
              : item;
        },
      ),
    );
  }
}
