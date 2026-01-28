import 'package:flutter/material.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:provider/provider.dart';

import 'app.dart';
import 'core/core.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(
    MultiProvider(
      providers: [
        // ChangeNotifierProvider(create: (_) => PurchaseService()), // TODO: UNCOMMENT
        ChangeNotifierProvider(create: (_) => FileTransferService()),
      ],
      child: const App(),
    ),
  );
}
