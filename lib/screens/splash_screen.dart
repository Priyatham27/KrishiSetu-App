// lib/screens/splash_screen.dart
//
// Polished, mobile-first splash screen for KrishiSetu (Blinkit-like look).
// - Shows logo (development local file fallback -> asset -> icon)
// - Brief tagline and subtle animation
// - Checks Firebase auth state and routes to appropriate screen (role select / dashboards)
// - Replace debugLocalLogo with your packaged asset in production and add to pubspec.yaml.
//
// Usage: initialRoute in main.dart / app.dart points to Routes.splash

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../routes.dart';
import '../services/firebase_service.dart';
import '../models/user.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  // Path available in dev environment (provided earlier in conversation).
  // For production copy the file to assets/images/logo.png and use AssetImage.
  static const String debugLocalLogo = '/mnt/data/3092cec7-47a1-481d-a69d-d5aee694bb52.png';

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);

    // Start animation and then route after a short delay.
    _animController.forward();

    // Wait briefly to show splash then route.
    _checkAndNavigate();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAndNavigate() async {
    // show splash for minimum time for polish
    await Future.delayed(const Duration(milliseconds: 950));

    final user = FirebaseAuth.instance.currentUser;

    // If signed-in, attempt to fetch profile to route to farmer/buyer dashboards.
    if (user != null) {
      try {
        final profile = await FirebaseService.instance.getUserById(user.uid);
        if (profile != null) {
          if (profile.role == AppUser.ROLE_FARMER) {
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed(Routes.farmerDashboard);
            return;
          } else {
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed(Routes.buyerFeed);
            return;
          }
        } else {
          // signed-in but no profile - go to role select to capture role & profile
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed(Routes.roleSelect);
          return;
        }
      } catch (_) {
        // if profile lookup fails, fall back to role select
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(Routes.roleSelect);
        return;
      }
    }

    // Not signed-in -> present role select / login flow
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(Routes.roleSelect);
  }

  Widget _buildLogo(BuildContext context) {
    // Prefer local dev file for quick dev preview; fallback to asset or icon.
    final logoWidget = Builder(builder: (ctx) {
      try {
        final f = File(debugLocalLogo);
        if (f.existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(f, width: 110, height: 110, fit: BoxFit.cover),
          );
        }
      } catch (_) {
        // ignore
      }

      // Try asset (if packaged)
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/images/logo.png',
          width: 110,
          height: 110,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.agriculture, size: 92, color: Colors.white),
        ),
      );
    });

    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: 128,
        height: 128,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 6))],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1AA34A), Color(0xFF36C85D)],
          ),
        ),
        child: Center(child: logoWidget),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Logo
              _buildLogo(context),
              const SizedBox(height: 18),

              // Title
              Text(
                'KrishiSetu',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0E6F33),
                ),
              ),
              const SizedBox(height: 8),

              // Tagline
              Text(
                'Farmers → Buyers • List • Negotiate • Transact',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 22),

              // Small marketing bullet points
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dotText('Transparent pricing'),
                  const SizedBox(width: 12),
                  _dotText('Direct connect'),
                  const SizedBox(width: 12),
                  _dotText('Fast listings'),
                ],
              ),

              const Spacer(flex: 3),

              // Progress / CTA hint
              Column(
                children: [
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 160,
                    child: LinearProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF1AA34A)),
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Preparing your feed...', style: theme.textTheme.bodySmall),
                ],
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dotText(String text) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF1AA34A), shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
