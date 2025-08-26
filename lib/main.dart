import 'package:flutter/material.dart';
import 'package:pinwall/screens/splash.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
    Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PinWall',
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
