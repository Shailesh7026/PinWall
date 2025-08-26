import 'package:flutter/material.dart';

import 'package:pinwall/widgets/bootomnavbar.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const CustomBottomNavBar()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Text("Loading...")],
      ),
    );
  }
}
