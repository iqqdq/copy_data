import 'package:flutter/material.dart';

import '../../presentation/presentation.dart';

abstract class AppRoutes {
  static String get splash => '/';
  static String get onboard => '/onboard';
  static String get paywall => '/paywall';
  static String get main => '/main';
  static String get progress => '/progress';
  static String get receive => '/receive';
  static String get send => '/send';
  static String get settings => '/settings';
  static String get subscriptionPlan => '/subscription_plans';
  static String get tutorial => '/tutorial';
}

abstract class AppNavigation {
  static final initialRoute = AppRoutes.splash;

  static final routes = <String, Widget Function(BuildContext)>{
    AppRoutes.splash: (_) => const SplashScreen(),
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

    if (settings.name == AppRoutes.main) {
      return MaterialPageRoute(builder: (_) => const MainScreen());
    }

    if (settings.name == AppRoutes.progress) {
      return MaterialPageRoute(
        builder: (_) => ProgressScreen(isSending: settings.arguments as bool),
      );
    }

    if (settings.name == AppRoutes.receive) {
      return MaterialPageRoute(builder: (_) => const ReceiveScreen());
    }

    if (settings.name == AppRoutes.send) {
      return MaterialPageRoute(builder: (_) => const SendScreen());
    }

    if (settings.name == AppRoutes.settings) {
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
    }

    if (settings.name == AppRoutes.subscriptionPlan) {
      return MaterialPageRoute(builder: (_) => const SubscriptionPlansScreen());
    }

    if (settings.name == AppRoutes.tutorial) {
      return MaterialPageRoute(builder: (_) => const TutorialScreen());
    }

    return null;
  }
}
