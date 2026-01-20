import 'package:flutter/material.dart';

import 'package:flutter_svg/svg.dart';

import '../../../../core/core.dart';
import '../../../widgets/widgets.dart';

class PermissionAlert extends StatelessWidget {
  final VoidCallback onNextPressed;
  final VoidCallback onNotNowPressed;
  final List<bool> permissionStates;
  final int currentPermissionIndex;
  final bool isRequestingPermission;

  const PermissionAlert({
    super.key,
    required this.onNextPressed,
    required this.onNotNowPressed,
    required this.permissionStates,
    required this.currentPermissionIndex,
    this.isRequestingPermission = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.0),
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      color: AppColors.black.withValues(alpha: 0.65),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24.0).copyWith(bottom: 8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32.0),
              border: Border.all(color: AppColors.black, width: 3.0),
              color: AppColors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Permissions Required',
                    style: AppTypography.title20Medium,
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'To '),
                        TextSpan(
                          text: 'send or receive',
                          style: const TextStyle().copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' data, please allow the necessary permissions.',
                        ),
                      ],
                    ),
                    style: AppTypography.body16Light,
                  ),
                ),

                _PermissionInfo(
                  asset: 'assets/icons/wi-fi.svg',
                  title: 'Local Network',
                  isPermissionGranted: permissionStates[0],
                ),

                _PermissionInfo(
                  asset: 'assets/icons/image.svg',
                  title: 'Photos & Videos',
                  isPermissionGranted: permissionStates[1],
                ),

                _PermissionInfo(
                  asset: 'assets/icons/camera.svg',
                  title: 'Camera',
                  isPermissionGranted: permissionStates[2],
                ),

                Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: CustomButton.primary(
                    title: 'Next',
                    onPressed: isRequestingPermission ? null : onNextPressed,
                  ),
                ),

                CustomButton.transparent(
                  title: 'Not now',
                  onPressed: onNotNowPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionInfo extends StatelessWidget {
  final String asset;
  final String title;
  final bool isPermissionGranted;

  const _PermissionInfo({
    required this.asset,
    required this.title,
    required this.isPermissionGranted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          SvgPicture.asset(
            asset,
            colorFilter: ColorFilter.mode(AppColors.accent, BlendMode.srcIn),
          ),

          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                style: AppTypography.body16Light.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          IgnorePointer(child: CustomSwitch(value: isPermissionGranted)),
        ],
      ),
    );
  }
}
