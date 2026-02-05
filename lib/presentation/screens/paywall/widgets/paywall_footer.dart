import 'package:flutter/material.dart';

import '../../../../core/core.dart';
import '../../../presentation.dart';

class PaywallFooter extends StatelessWidget {
  final bool isLoading;
  final String price;
  final String duration;
  final bool value;
  final Function(bool) onChanged;
  final VoidCallback onPressed;

  const PaywallFooter({
    super.key,
    required this.isLoading,
    required this.price,
    required this.duration,
    required this.value,
    required this.onChanged,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                            '$price'
                        .toHighlightedText(
                          highlightedWords: [price],
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
                              '$duration free trial is enabled',
                              style: AppTypography.body16Regular,
                            ),
                          ),
                        ),

                        CustomSwitch(value: value, onChanged: onChanged),
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
                isLoading: isLoading,
                onPressed: onPressed,
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
    );
  }
}
