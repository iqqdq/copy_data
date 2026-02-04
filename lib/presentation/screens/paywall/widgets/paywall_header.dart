import 'package:flutter/material.dart';

import '../../../../core/core.dart';

class PaywallHeader extends StatelessWidget {
  const PaywallHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: IntrinsicHeight(
                      child: Center(
                        child: Image.asset(
                          'assets/images/get_unlimited_transfers.png',
                        ),
                      ),
                    ),
                  ),

                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Image.asset(
                            'assets/images/left_arrow.png',
                            height: 34.0,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child:
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Features',
                              style: AppTypography.link12Regular,
                            ),
                          ),

                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: 16.0),
                              child: Text(
                                'Free',
                                textAlign: TextAlign.end,
                                style: AppTypography.link12Regular,
                              ),
                            ),
                          ),

                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: Text(
                                'Premium',
                                textAlign: TextAlign.end,
                                style: AppTypography.link12Regular,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Transfer files',
                              style: AppTypography.link16Medium,
                            ),
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(right: 4.0),
                                  child: Text(
                                    'Max 10',
                                    textAlign: TextAlign.end,
                                    style: AppTypography.link16Medium,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    'per week',
                                    textAlign: TextAlign.end,
                                    style: AppTypography.link10Regular,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: Text(
                              'Unlimited',
                              textAlign: TextAlign.end,
                              style: AppTypography.link16Medium,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Receive files',
                            style: AppTypography.link16Medium,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            'Unlimited',
                            textAlign: TextAlign.end,
                            style: AppTypography.link16Medium,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            'Unlimited',
                            textAlign: TextAlign.end,
                            style: AppTypography.link16Medium,
                          ),
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
                  offset: const Offset(0, 3),
                ),
          ),

          Padding(
            padding: EdgeInsets.only(bottom: 29.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Image.asset('assets/images/right_arrow.png', height: 34.0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
