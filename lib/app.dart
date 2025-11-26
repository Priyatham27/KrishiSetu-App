// lib/app.dart
//
// Main app widget for KrishiSetu.
// - Listens to Firebase Auth state and fetches users/{uid} profile
// - Routes users to Farmer / Buyer screens when authenticated and profile exists
// - Provides a polished theme (Blinkit-like) and centralized routing
//
// Note: During development you can temporarily reference a local demo logo path:
//   /mnt/data/3092cec7-47a1-481d-a69d-d5aee694bb52.png
// For production, copy that file into assets/images/logo.png and add to pubspec.yaml.
//
// Matches expectation in lib/main.dart which calls `runApp(const KrishiSetuApp())`.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'routes.dart';
import 'services/auth_service.dart';
import 'services/firebase_service.dart';
import 'models/user.dart';
import 'screens/splash_screen.dart';
import 'screens/role_select.dart';
import 'screens/farmer_dashboard.dart';
import 'screens/buyer_feed.dart';
import 'screens/login_demo.dart';

class KrishiSetuApp extends StatefulWidget {
  const KrishiSetuApp({Key? key}) : super(key: key);

  @override
  State<KrishiSetuApp> createState() => _KrishiSetuAppState();
}

class _KrishiSetuAppState extends State<KrishiSetuApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<User?>? _authSub;
  bool _initialized = false;
  User? _user;
  AppUser? _profile;

  @override
  void initState() {
    super.initState();
    // Listen to auth changes and fetch the corresponding user profile document.
    _authSub = AuthService.instance.authStateChanges().listen((u) async {
      _user = u;
      if (u != null) {
        try {
          final profile = await FirebaseService.instance.getUserById(u.uid);
          _profile = profile;
        } catch (_) {
          _profile = null;
        }
      } else {
        _profile = null;
      }

      // After resolving profile, update UI
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  ThemeData _buildTheme() {
    // Blinkit-like fresh palette
    const primaryGreen = Color(0xFF1AA34A);
    const accentYellow = Color(0xFFFCB03C);

    return ThemeData(
      primaryColor: primaryGreen,
      colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green)
          .copyWith(secondary: accentYellow),
      scaffoldBackgroundColor: Colors.white,
      brightness: Brightness.light,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryGreen),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.withOpacity(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
    );
  }

  /// Decide initial landing after initialization
  Widget _landingWidget() {
    if (!_initialized) {
      return const SplashScreen();
    }

    if (_user == null) {
      // Not signed in -> show splash which should lead to login/role selection
      return const SplashScreen();
    }

    // Signed in; route by role if profile exists
    if (_profile != null) {
      if (_profile!.role == AppUser.ROLE_FARMER) {
        return const FarmerDashboardScreen();
      } else {
        return const BuyerFeedScreen();
      }
    }

    // Signed in but no profile document yet -> ask role select
    return const RoleSelectScreen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _buildTheme();

    return MaterialApp(
      key: const Key('KrishiSetuApp'),
      navigatorKey: _navigatorKey,
      title: 'KrishiSetu',
      debugShowCheckedModeBanner: false,
      theme: theme,
      // Keep centralized named routes (routes.dart)
      initialRoute: Routes.splash,
      onGenerateRoute: RouteGenerator.generateRoute,
      // Provide an immediate home depending on auth/profile resolution to avoid flashing wrong pages.
      home: _landingWidget(),
    );
  }
}
