import 'package:flutter/material.dart';

import '../../../../core/core.dart';
import '../../../presentation.dart';

class SettingsGuideTile extends StatelessWidget {
  final VoidCallback onPressed;

  const SettingsGuideTile({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: 3.0),
                child: Image.asset(
                  'assets/images/guide.png',
                  width: 28.0,
                  height: 28.0,
                ),
              ),

              Expanded(
                child: Text(
                  'Guide how to use the app',
                  style: AppTypography.title20Medium,
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.only(bottom: 16.0),
          child: 'Learn how to send and receive files step by step'
              .toHighlightedText(
                highlightedWords: ['Learn', 'send and receive'],
                baseStyle: AppTypography.body16Regular,
                highlightColor: AppColors.accent,
              ),
        ),

        CustomButton.primary(title: 'Read guide', onPressed: onPressed),
      ],
    ).withDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(32.0),
      borderWidth: 3.0,
      borderColor: AppColors.black,
      offset: const Offset(0, 3),
      blurRadius: 0,
      spreadRadius: 0,
      padding: EdgeInsets.all(24.0),
    );
  }
}
