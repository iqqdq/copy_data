import 'package:flutter/material.dart';

import '../../presentation/presentation.dart';

abstract class AppRoutes {
  static String get splash => '/';
  static String get onboard => '/onboard';
  static String get paywall => '/paywall';
  static String get main => '/main';
  static String get receive => '/receive';
  static String get scanner => '/scanner';
  static String get send => '/send';
  static String get progress => '/progress';
  static String get settings => '/settings';
  static String get subscriptionPlans => '/subscription_plans';
  static String get tutorial => '/tutorial';
}

abstract class AppNavigation {
  static final initialRoute = AppRoutes.splash;

  static final routes = <String, Widget Function(BuildContext)>{
    AppRoutes.splash: (_) => const SplashScreen(),
    AppRoutes.main: (_) => const MainScreen(),
    AppRoutes.receive: (_) => const ReceiveScreen(),
    AppRoutes.scanner: (_) => const ScannerScreen(),
    AppRoutes.send: (_) => const SendScreen(),
    AppRoutes.settings: (_) => const SettingsScreen(),
    AppRoutes.subscriptionPlans: (_) => const SubscriptionPlansScreen(),
    AppRoutes.tutorial: (_) => const TutorialScreen(),
  };

  static Route? onGenerateRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.onboard) {
      return PageRouteBuilder(
        pageBuilder: (context, _, _) => const OnboardScreen(),
        transitionDuration: Duration.zero,
      );
    }

    if (settings.name == AppRoutes.paywall) {
      return MaterialPageRoute(
        builder: (_) => const PaywallScreen(),
        fullscreenDialog: true,
      );
    }

    if (settings.name == AppRoutes.progress) {
      return MaterialPageRoute(
        builder: (_) => ProgressScreen(isSending: settings.arguments as bool),
      );
    }

    return null;
  }
}
