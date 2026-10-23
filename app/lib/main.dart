import 'package:flutter/material.dart';

import 'home_page.dart';
import 'light_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LightStore()..start();
  runApp(GoboApp(store: store));
}

class GoboApp extends StatelessWidget {
  const GoboApp({super.key, required this.store});
  final LightStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFFB347),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Gobo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0E0E10),
        useMaterial3: true,
        sliderTheme: const SliderThemeData(trackHeight: 28, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 0)),
      ),
      home: HomePage(store: store),
    );
  }
}
