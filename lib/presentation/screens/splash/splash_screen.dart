import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../../core/core.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      FlutterNativeSplash.remove();
      await Future.delayed(Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboard);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TODO: REPLACE WITH IMAGE WITH TEXT
            Padding(
              padding: EdgeInsets.only(bottom: 37.0),
              child: Image.asset(
                'assets/images/splash.png',
                width: 261.0,
                height: 261.0,
                fit: BoxFit.fitWidth,
              ),
            ),

            Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Copy data', style: AppTypography.title24Medium),
            ),

            'Easy transfer app'.toHighlightedText(
              highlightedWords: ['transfer', 'app'],
              style: AppTypography.body20Light,
            ),
          ],
        ),
      ),
    );
  }
}
