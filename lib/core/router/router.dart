import 'package:flutter/material.dart';

import '../../presentation/presentation.dart';
import '../core.dart';

abstract class AppRoutes {
  static const String onboard = '/onboard';
  static const String paywall = '/paywall';
  static const String main = '/main';
  static const String receive = '/receive';
  static const String scanner = '/scanner';
  static const String send = '/send';
  static const String progress = '/progress';
  static const String settings = '/settings';
  static const String subscriptionPlans = '/subscription_plans';
  static const String tutorial = '/tutorial';
}

abstract class AppNavigation {
  static final String initialRoute = isSubscribed.value
      ? AppRoutes.main
      : AppRoutes.paywall;

  static final routes = <String, Widget Function(BuildContext)>{
    AppRoutes.main: (_) => const MainScreen(),
    AppRoutes.receive: (_) => const ReceiveScreen(),
    AppRoutes.scanner: (_) => const ScannerScreen(),
    AppRoutes.send: (_) => const SendScreen(),
    AppRoutes.settings: (_) => const SettingsScreen(),
    AppRoutes.subscriptionPlans: (_) => const SubscriptionPlansScreen(),
    AppRoutes.tutorial: (_) => const TutorialScreen(),
  };

  static Route? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboard:
        return PageRouteBuilder(
          pageBuilder: (context, _, _) => const OnboardScreen(),
          transitionDuration: Duration.zero,
        );
      case AppRoutes.paywall:
        return MaterialPageRoute(
          builder: (_) => const PaywallScreen(),
          fullscreenDialog: true,
        );
      case AppRoutes.progress:
        return MaterialPageRoute(
          builder: (_) => ProgressScreen(isSending: settings.arguments as bool),
        );
      default:
        return null;
    }
  }
}
