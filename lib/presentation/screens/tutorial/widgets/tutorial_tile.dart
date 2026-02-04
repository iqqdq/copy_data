import 'package:flutter/material.dart';
import '../../../../core/core.dart';

class TutorialTile extends StatelessWidget {
  final String asset;
  final String title;
  final Widget subtitle;
  final Widget? hint;

  const TutorialTile({
    super.key,
    required this.asset,
    required this.title,
    required this.subtitle,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Image.asset(
            'assets/images/$asset.png',
            width: 74.0,
            height: 74.0,
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(title, style: AppTypography.title20Medium),
        ),

        subtitle,

        hint == null ? const SizedBox.shrink() : hint!,
      ],
    ).withDecoration(
      padding: const EdgeInsets.all(24.0),
      color: AppColors.white,
      borderRadius: BorderRadius.circular(32.0),
      borderWidth: 3.0,
      borderColor: AppColors.black,
    );
  }
}
