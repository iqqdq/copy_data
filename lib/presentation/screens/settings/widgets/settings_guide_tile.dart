import 'package:flutter/material.dart';

import '../../../../core/core.dart';
import '../../../presentation.dart';

class SettingsGuideTile extends StatelessWidget {
  final VoidCallback onPressed;

  const SettingsGuideTile({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32.0),
          border: Border.all(color: AppColors.black, width: 3.0),
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.black,
              offset: const Offset(0, 3),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
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
                    baseStyle: AppTypography.body16Light,
                    highlightColor: AppColors.accent,
                  ),
            ),

            CustomButton.primary(title: 'Read guide', onPressed: onPressed),
          ],
        ),
      ),
    );
  }
}
