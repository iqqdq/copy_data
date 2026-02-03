import 'package:flutter/material.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:provider/provider.dart';

import 'app.dart';
import 'core/core.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await _init();
  FlutterNativeSplash.remove();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => FileTransferService())],
      child: const App(),
    ),
  );
}

Future<void> _init() async {
  await AppSettingsService.instance.init();
  await PurchaseService.instance.init();
}
