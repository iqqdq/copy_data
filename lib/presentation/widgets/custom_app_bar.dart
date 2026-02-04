import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../core/core.dart';

import 'custom_icon_button.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.actions,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset(
      'assets/icons/back.svg',
      colorFilter: ColorFilter.mode(AppColors.black, BlendMode.srcIn),
    );

    return AppBar(
      forceMaterialTransparency: true,
      backgroundColor: AppColors.white,
      elevation: 0.0,
      leading:
          leading ??
          (automaticallyImplyLeading
              ? CustomIconButton(
                  onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                  icon: icon,
                )
              : const SizedBox.shrink()),
      title: Text(title),
      titleTextStyle: AppTypography.link16Medium.copyWith(
        color: AppColors.black,
      ),
      centerTitle: true,
      actions: actions,
      actionsPadding: EdgeInsets.symmetric(horizontal: 8.0),
    );
  }
}
