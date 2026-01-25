import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class OnboardScreen extends StatefulWidget {
  const OnboardScreen({super.key});

  @override
  State<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends State<OnboardScreen> {
  final _images = [
    'fast_and_easy_file_transfer',
    'rate_your_experience',
    'connecting_devices',
    'get_unlimited_transfers',
  ];

  final _titles = [
    'Fast & Easy File Transfer',
    'Rate Your Experience',
    'Fast Transfer via QR',
    'Get Unlimited Transfers',
  ];

  final _subtitles = [
    'Share photos and videos instantly, no cables needed',
    'Help us improve by leaving a quick review',
    'Connect devices instantly and share files in seconds',
    'Unlock all features just for\n'
        r'$4.99/week',
  ];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Image.asset(
                    'assets/images/${_images[_index]}.png',
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
                        _index == _titles.length - 1
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: EdgeInsets.only(bottom: 24.0),
                                child: CustomSlider(
                                  length: _titles.length - 1,
                                  currentPage: _index,
                                  onPageChanged: (index) =>
                                      setState(() => _index = index),
                                ),
                              ),

                        Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _titles[_index],
                            style: AppTypography.title24Medium,
                            textAlign: TextAlign.center,
                          ),
                        ),

                        Padding(
                          padding: EdgeInsets.only(bottom: 16.0),
                          child: _index == _subtitles.length - 1
                              ? _subtitles[_index].toHighlightedText(
                                  highlightedWords: [
                                    r'$4.99/week',
                                    r'$4.99/week with 3-day free trial',
                                  ],
                                  baseStyle: AppTypography.body16Light,
                                  highlightColor: AppColors.accent,
                                  textAlign: TextAlign.center,
                                )
                              : Text(
                                  _subtitles[_index],
                                  style: AppTypography.body16Light,
                                  textAlign: TextAlign.center,
                                ),
                        ),

                        CustomButton.primary(
                          title: 'Continue',
                          onPressed: () => _index == _titles.length - 1
                              ? Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MainScreen(),
                                  ),
                                )
                              : setState(() => _index = (_index + 1)),
                        ),
                      ],
                    ).withDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(32.0),
                      borderWidth: 3.0,
                      borderColor: AppColors.black,
                      offset: const Offset(0, 3),
                      blurRadius: 0,
                      spreadRadius: 0,
                      padding: EdgeInsets.all(24.0),
                    ),
              ),

              TermsGroup(onRestore: () {}), // TODO:
            ],
          ),
        ),
      ),
    );
  }
}
