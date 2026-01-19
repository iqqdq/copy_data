import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'app.dart';
import 'core/core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FontManager.loadFonts();
  } catch (e) {
    print('Failed to load font: $e');
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => FileTransferService())],
      child: App(),
    ),
  );
}

class FontManager {
  static Future<void> loadFonts() async {
    // Явно загрузите каждый файл шрифта
    final fontLoader = FontLoader('Morn');

    fontLoader.addFont(rootBundle.load('assets/fonts/morn-light.ttf'));
    fontLoader.addFont(rootBundle.load('assets/fonts/morn-regular.ttf'));
    fontLoader.addFont(rootBundle.load('assets/fonts/morn-medium.ttf'));

    await fontLoader.load();
    print('Font Morn loaded successfully');
  }
}
