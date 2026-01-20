import 'dart:io';

import 'package:flutter/gestures.dart';
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
      appBar: CustomAppBar(title: 'Tutorial', automaticallyImplyLeading: false),
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
                ? _ClickablePlatformText(
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
                ? _TutorialHint(
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

class _ClickablePlatformText extends StatelessWidget {
  final String title;
  final String highlighted;
  final VoidCallback onPressed;

  const _ClickablePlatformText({
    required this.title,
    required this.highlighted,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final parts = title.split(highlighted);

    return RichText(
      text: TextSpan(
        style: AppTypography.body16Light.copyWith(color: AppColors.black),
        children: [
          TextSpan(text: parts[0]),
          TextSpan(
            text: 'iOS',
            style: AppTypography.body16Light.copyWith(
              color: AppColors.accent,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent,
            ),
            recognizer: TapGestureRecognizer()..onTap = onPressed,
          ),
          TextSpan(
            text: ' / ',
            style: AppTypography.body16Light.copyWith(color: AppColors.accent),
          ),
          TextSpan(
            text: 'Android',
            style: AppTypography.body16Light.copyWith(
              color: AppColors.accent,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent,
            ),
            recognizer: TapGestureRecognizer()..onTap = onPressed,
          ),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
  }
}

class _TutorialHint extends StatelessWidget {
  final String title;
  final String highlighted;

  const _TutorialHint({required this.title, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Image.asset(
              'assets/images/warning.png',
              width: 24.0,
              height: 24.0,
            ),
          ),
          Expanded(
            child:
                'If Wi‑Fi isn’t available, enable hotspot mode on one device and connect the other to it'
                    .toMultiColoredText(
                      baseStyle: AppTypography.body16Light,
                      highlights: [
                        TextHighlight(
                          text: 'Wi‑Fi isn’t available',
                          color: AppColors.orange,
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
