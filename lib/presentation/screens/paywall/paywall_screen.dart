import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _value = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // TODO: CHECK
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/images/get_unlimited_transfers.png',
                        width: 261.0,
                        height: 261.0,
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child:
                        Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Get Unlimited Transfers',
                                style: AppTypography.title24Medium,
                                textAlign: TextAlign.center,
                              ),
                            ),

                            Padding(
                              padding: EdgeInsets.only(bottom: 16.0),
                              child:
                                  'Unlock all features just for\n'
                                          r'$4.99/week'
                                      .toHighlightedText(
                                        highlightedWords: [
                                          r'$4.99/week',
                                          r'$4.99/week with 3-day free trial',
                                        ],
                                        style: AppTypography.body16Regular,
                                        textAlign: TextAlign.center,
                                      ),
                            ),

                            Padding(
                              padding: EdgeInsets.only(bottom: 16.0),
                              child:
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(right: 6.0),
                                          child: Text(
                                            '3-day free trial is enabled',
                                            style: AppTypography.body16Regular,
                                          ),
                                        ),
                                      ),

                                      CustomSwitch(
                                        value: _value,
                                        onChanged: (value) =>
                                            setState(() => _value = value),
                                      ),
                                    ],
                                  ).withDecoration(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10.0,
                                      vertical: 12.0,
                                    ),
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(32.0),
                                    borderWidth: 3.0,
                                    borderColor: AppColors.black,
                                  ),
                            ),

                            CustomButton.primary(
                              title: 'Continue',
                              isLoading: _isLoading, // TODO:
                              onPressed: () {
                                isSubscribed.value = true; // TODO: PURCHASE
                                Navigator.canPop(context)
                                    ? Navigator.pop(context)
                                    :
                                      // TODO: CHECK IF FIRST START
                                      Navigator.pushReplacementNamed(
                                        context,
                                        AppRoutes.main,
                                        // TODO: CHECK IF FIRST START ? AppRoutes.tutorial : AppRoutes.main,
                                      );
                              },
                            ),
                          ],
                        ).withDecoration(
                          padding: EdgeInsets.all(24.0),
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(32.0),
                          borderWidth: 3.0,
                          borderColor: AppColors.black,
                          offset: const Offset(0, 3),
                          blurRadius: 0,
                          spreadRadius: 0,
                        ),
                  ),

                  TermsGroup(onRestore: () {}), // TODO:
                ],
              ),
            ),

            _isLoading
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: CustomIconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/cross.svg',
                        colorFilter: ColorFilter.mode(
                          AppColors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                      onPressed: () => Navigator.canPop(context)
                          ? Navigator.pop(context)
                          : Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.main,
                            ), // TODO: Paywall.didClose
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
