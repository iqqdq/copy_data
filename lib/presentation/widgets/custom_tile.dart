import 'package:flutter/material.dart';
import '../../core/core.dart';

class CustomTile extends StatelessWidget {
  final String asset;
  final String title;
  final Widget subtitle;
  final Widget? hint;
  final Widget? child;

  const CustomTile({
    super.key,
    required this.asset,
    required this.title,
    required this.subtitle,
    this.hint,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32.0),
        border: Border.all(color: AppColors.black, width: 3.0),
        color: AppColors.white,
      ),
      child: Column(
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

          child == null ? const SizedBox.shrink() : child!,
        ],
      ),
    );
  }
}
