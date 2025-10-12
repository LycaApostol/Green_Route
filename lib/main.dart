import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/map_route_screen.dart';
import 'widgets/bottom_nav_shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'green_route',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF2ECC71),
      ),
      home: FutureBuilder(
  future: Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ),
  builder: (context, snapshot) {
    // If Firebase init error
    if (snapshot.hasError) {
      return Scaffold(
        body: Center(
          child: Text('Error: ${snapshot.error}'),
        ),
      );
    }

    // Once Firebase is ready
    if (snapshot.connectionState == ConnectionState.done) {
      return StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (userSnapshot.hasData) {
            // ✅ User is logged in — go to HomeShell (Dashboard)
            return const HomeShell();
          } else {
            // 🚪 No user signed in — go to Welcome/Login flow
            return const WelcomeScreen();
          }
        },
      );
    }

    // Firebase still loading
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  },
),

      routes: {
        '/welcome': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignUpScreen(),
        '/map': (_) => const MapRouteScreen(),
        '/home': (_) => const HomeShell(),
      },
    );
  }
}