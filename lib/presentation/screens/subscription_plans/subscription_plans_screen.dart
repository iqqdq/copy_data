import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() =>
      _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  final subscriptions = [
    // TODO: REPLACE
    r'$4.99/week with a 3-day free trial',
    r'$4.99/week',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Subscription plans'),
      body: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        itemCount: subscriptions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 24.0),
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TODO: HAS ACTIVE SUBSCRIPTION
              Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  index == 0
                      ? 'Your active subscription'
                      : 'Other subscriptions',
                  style: AppTypography.link16Medium,
                ),
              ),

              SubscriptionTile(
                child: subscriptions[index].toHighlightedText(
                  highlightedWords: [r'$4.99/week'],
                  baseStyle: AppTypography.body16Regular,
                  highlightColor: AppColors.accent,
                ),
                onPressed: () {
                  // TODO:
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
