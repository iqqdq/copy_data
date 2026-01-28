import 'package:flutter/material.dart';

import '../../../../core/core.dart';
import '../../../presentation.dart';

class ConnectionStatusAlert extends StatelessWidget {
  final bool isConnecting;

  const ConnectionStatusAlert({super.key, required this.isConnecting});

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
          child:
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Connecting Devices…',
                      style: AppTypography.title20Medium,
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.only(bottom: 24.0),
                    child: 'Please wait while we link your devices'
                        .toHighlightedText(
                          highlightedWords: ['link', 'your', 'devices'],
                          baseStyle: AppTypography.body16Regular,
                          highlightColor: AppColors.accent,
                        ),
                  ),

                  Padding(
                    padding: EdgeInsets.only(
                      bottom: isConnecting ? 48.0 : 32.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/connecting_devices.png',
                          width: 252.0,
                          height: 215.0,
                        ),
                      ],
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isConnecting
                          ? SizedBox(
                              width: 57.0,
                              height: 57.0,
                              child: Center(child: const CustomLoader()),
                            )
                          : Image.asset(
                              'assets/images/done.png',
                              width: 73.0,
                              height: 73.0,
                            ),
                    ],
                  ),
                ],
              ).withDecoration(
                padding: EdgeInsets.all(24.0),
                color: AppColors.white,
                borderRadius: BorderRadius.circular(32.0),
                borderWidth: 3.0,
                borderColor: AppColors.black,
              ),
        ),
      ),
    );
  }
}
