import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'app.dart';
import 'core/core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        // ChangeNotifierProvider(create: (_) => PurchaseService()), // TODO: UNCOMMENT
        ChangeNotifierProvider(create: (_) => FileTransferService()),
      ],
      child: App(),
    ),
  );
}
