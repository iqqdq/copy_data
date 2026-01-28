import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/core.dart';

class ClickablePlatformText extends StatelessWidget {
  final String title;
  final String highlighted;
  final VoidCallback onPressed;

  const ClickablePlatformText({
    super.key,
    required this.title,
    required this.highlighted,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final parts = title.split(highlighted);

    return RichText(
      text: TextSpan(
        style: AppTypography.body16Regular.copyWith(color: AppColors.black),
        children: [
          TextSpan(text: parts[0]),
          TextSpan(
            text: 'iOS',
            style: AppTypography.body16Regular.copyWith(
              color: AppColors.accent,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent,
            ),
            recognizer: TapGestureRecognizer()..onTap = onPressed,
          ),
          TextSpan(
            text: ' / ',
            style: AppTypography.body16Regular.copyWith(
              color: AppColors.accent,
            ),
          ),
          TextSpan(
            text: 'Android',
            style: AppTypography.body16Regular.copyWith(
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
