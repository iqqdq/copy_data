import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../core/core.dart';

class SettingsTile extends StatelessWidget {
  final String asset;
  final String title;
  final VoidCallback onPressed;

  const SettingsTile({
    super.key,
    required this.asset,
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 24.0,
            ).copyWith(right: 8.0),
            child: SvgPicture.asset(
              'assets/icons/$asset.svg',
              colorFilter: ColorFilter.mode(AppColors.accent, BlendMode.srcIn),
            ),
          ),

          Text(
            title,
            style: AppTypography.body16Light.copyWith(color: AppColors.black),
          ),
        ],
      ),
    );

    return Platform.isIOS
        ? CupertinoButton(
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            child: child,
          )
        : MaterialButton(
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            child: child,
          );
  }
}
