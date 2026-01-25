import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../core/core.dart';

import 'presentation/presentation.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: AppColors.white),
      home: ChangeNotifierProvider(
        create: (_) => FileTransferService(),
        child: OnboardScreen(),
      ),
    );
  }
}
