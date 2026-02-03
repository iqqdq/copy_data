import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final assets = ['lock', 'document', 'share', 'headset'];
    final titles = ['Privacy Policy', 'Terms of Use', 'Share App', 'Support'];

    return Scaffold(
      appBar: CustomAppBar(title: 'Settings'),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 8.0,
        ).copyWith(bottom: MediaQuery.of(context).padding.bottom),
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: isSubscribed,
            builder: (context, value, _) {
              return value
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: SettingsPremiumTile(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.paywall),
                      ),
                    );
            },
          ),

          Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: SettingsGuideTile(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.tutorial),
            ),
          ),

          ValueListenableBuilder<bool>(
            valueListenable: isSubscribed,
            builder: (context, value, _) {
              // TODO: CHECK SUB ID
              return value
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: CustomButton.primary(
                        title: 'Subscription plans',
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.subscriptionPlans,
                        ),
                      ),
                    );
            },
          ),

          Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child:
                ListView.separated(
                  padding: Platform.isIOS
                      ? EdgeInsets.symmetric(vertical: 12.0)
                      : EdgeInsets.symmetric(vertical: 24.0),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: titles.length,
                  separatorBuilder: (context, index) => Container(
                    margin: EdgeInsets.symmetric(horizontal: 24.0),
                    height: 1.0,
                    color: AppColors.extraLightGray,
                  ),
                  itemBuilder: (context, index) {
                    return SettingsTile(
                      asset: assets[index],
                      title: titles[index],
                      onPressed: () {
                        // TODO:
                      },
                    );
                  },
                ).withDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(32.0),
                  borderWidth: 3.0,
                  borderColor: AppColors.black,
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
          ),
        ],
      ),
    );
  }
}
