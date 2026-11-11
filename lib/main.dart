import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinwall/services/wallpaper_provider.dart';
import 'package:pinwall/widgets/bootomnavbar.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WallpaperProvider()),
      ],
      child: MaterialApp(
        title: 'PinWall',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE60023)),
          useMaterial3: true,
        ),
        home: const AppStartup(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Warms up the Render API (free plan sleeps after 15 min),
/// then shows the main app.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final provider = context.read<WallpaperProvider>();
    await provider.warmUp();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CustomBottomNavBar()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 80, errorBuilder: (_, __, ___) =>
              const Icon(Icons.photo_library, size: 80, color: Color(0xFFE60023))),
            const SizedBox(height: 24),
            const Text(
              'PinWall',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Color(0xFFE60023)),
            const SizedBox(height: 12),
            const Text('Connecting to server…', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
