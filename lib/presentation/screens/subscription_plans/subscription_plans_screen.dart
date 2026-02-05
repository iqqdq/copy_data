import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class SubscriptionPlansScreen extends StatelessWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subscriptions = [weekTrialProduct, weekProduct];

    return Scaffold(
      appBar: CustomAppBar(title: 'Subscription plans'),
      body: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        itemCount: subscriptions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 24.0),
        itemBuilder: (context, index) {
          final priceAndDuration = index == 0
              ? subscriptions[index].getPriceAndDurationPlus()
              : subscriptions[index].getPriceAndDuration(omitOneUnit: true);
          final price = subscriptions[index].getPrice();
          final isTrial = index == 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SubscriptionTile(
                child: priceAndDuration.toHighlightedText(
                  highlightedWords: [price],
                  style: AppTypography.body16Regular,
                ),
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    AppRoutes.paywall,
                    arguments: isTrial,
                  );

                  if (context.mounted && isSubscribed.value) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
