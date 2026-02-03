import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../../../core/core.dart';

class TermsGroup extends StatelessWidget {
  final VoidCallback onRestore;

  const TermsGroup({super.key, required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TermButton(
          title: 'Terms of use',
          onPressed: () => launchUrlString(AppConstants.termsUrl),
        ),

        const Spacer(),

        _TermButton(title: 'Restore', onPressed: onRestore),

        const Spacer(),

        _TermButton(
          title: 'Privacy Policy',
          onPressed: () => launchUrlString(AppConstants.privacyUrl),
        ),
      ],
    );
  }
}

class _TermButton extends StatelessWidget {
  const _TermButton({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Text(
      title,
      style: AppTypography.link12Regular.copyWith(color: AppColors.grey),
    );

    return SizedBox(
      height: 48.0,
      child: Platform.isIOS
          ? CupertinoButton(
              onPressed: onPressed,
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              minimumSize: Size.zero,
              child: child,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(32.0),
              child: MaterialButton(
                onPressed: onPressed,
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: child,
              ),
            ),
    );
  }
}
