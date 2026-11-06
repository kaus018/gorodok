import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens.dart';
import 'storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GorodokApp());
}

class GorodokApp extends StatelessWidget {
  const GorodokApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ГородОК',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      // Если пользователь уже входил - сразу на главную, иначе на авторизацию
      final next = Store.email != null ? const HomeShell() : const LoginScreen();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: c.primary,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.location_city, size: 96, color: c.onPrimary),
          const SizedBox(height: 16),
          Text('ГородОК',
              style: TextStyle(
                  fontSize: 36, fontWeight: FontWeight.bold, color: c.onPrimary)),
          const SizedBox(height: 8),
          Text('Заметил проблему - сообщи',
              style: TextStyle(color: c.onPrimary.withOpacity(0.8))),
        ]),
      ),
    );
  }
}