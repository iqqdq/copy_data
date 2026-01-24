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
          SettingsGuideTile(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TutorialScreen()),
            ),
          ),

          Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: CustomButton.primary(
              title: 'Subscription plans',
              onPressed: () {},
            ),
          ),

          Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32.0),
                border: Border.all(color: AppColors.black, width: 3.0),
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black,
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ListView.separated(
                padding: EdgeInsets.symmetric(vertical: 24.0),
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
                    onPressed: () {},
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
