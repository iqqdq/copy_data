import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../presentation.dart';

class OnboardScreen extends StatefulWidget {
  const OnboardScreen({super.key});

  @override
  State<OnboardScreen> createState() => _OnboardScreenState();
}

class _OnboardScreenState extends State<OnboardScreen> {
  late final OnboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OnboardController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final isLastPage =
        _controller.state.index == _controller.state.titles.length - 1;

    if (isLastPage) {
      await _controller.completeOnboarding();
      if (mounted) {
        isSubscribed.value
            ? Navigator.pushReplacementNamed(context, AppRoutes.main)
            : Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, _, _) => PaywallScreen(),
                  transitionDuration: Duration.zero,
                ),
              );
      }
    } else {
      _controller.updatePage();
    }
  }

  Future<void> _restore() async {
    await _controller.restore();
    if (mounted && isSubscribed.value) {
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final state = _controller.state;
          final image = state.images[state.index];
          final title = state.titles[state.index];
          final subtitle = state.subtitles[state.index];

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Image.asset(
                        'assets/images/$image.png',
                        width: 261.0,
                        height: 261.0,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child:
                        Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: 24.0),
                              child: CustomSlider(
                                length: state.titles.length,
                                currentPage: state.index,
                              ),
                            ),

                            Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                title,
                                style: AppTypography.title24Medium,
                                textAlign: TextAlign.center,
                              ),
                            ),

                            Padding(
                              padding: EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                subtitle,
                                style: AppTypography.body16Regular,
                                textAlign: TextAlign.center,
                              ),
                            ),

                            CustomButton.primary(
                              title: 'Continue',
                              isLoading: _controller.state.isLoading,
                              onPressed: _handleContinue,
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

                  TermsGroup(onRestore: _restore),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
