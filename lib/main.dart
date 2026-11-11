import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinwall/services/background_worker.dart';
import 'package:pinwall/services/wallpaper_provider.dart';
import 'package:pinwall/widgets/bootomnavbar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundScheduler.initialize();
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

/// Loads local SQLite cache & queues immediately, wakes Render in background,
/// and opens the main app cleanly.
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
    await provider.refreshLocalState();
    // Wake Render in the background without blocking cached UI startup
    unawaited(provider.warmUp());
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
            Image.asset(
              'assets/images/logo.png',
              width: 80,
              errorBuilder: (_, _, _) => const Icon(
                Icons.photo_library,
                size: 80,
                color: Color(0xFFE60023),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'PinWall',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Color(0xFFE60023)),
          ],
        ),
      ),
    );
  }
}
