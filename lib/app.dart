import 'package:flutter/material.dart';

import '../core/core.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(scaffoldBackgroundColor: AppColors.white),
      initialRoute: AppNavigation.initialRoute,
      onGenerateRoute: AppNavigation.onGenerateRoute,
      routes: AppNavigation.routes,
    );
  }
}
