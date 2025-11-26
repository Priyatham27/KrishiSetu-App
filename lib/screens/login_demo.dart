// lib/screens/login_demo.dart
//
// A self-contained, ready-to-paste login/demo screen used in the KrishiSetu prototype.
// - Email/password sign-in with password visibility toggle
// - Phone OTP flow (send OTP, enter code, verify)
// - Anonymous "Demo mode" quick sign-in (for judges/demoing)
// - Uses AuthService (lib/services/auth_service.dart) for Firebase operations
//
// NOTE: during development you can show a local debug logo stored at:
//   /mnt/data/3092cec7-47a1-481d-a69d-d5aee694bb52.png
// If you want the image packaged into the app, copy it to assets/images/logo.png
// and add it to pubspec.yaml.
//
// Replace any usages of Routes.buyerFeed with your desired post-login route if needed.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../routes.dart';

class LoginDemoScreen extends StatefulWidget {
  const LoginDemoScreen({Key? key}) : super(key: key);

  @override
  State<LoginDemoScreen> createState() => _LoginDemoScreenState();
}

class _LoginDemoScreenState extends State<LoginDemoScreen> {
  // Email sign-in
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loadingEmail = false;

  // Phone OTP flow
  final _phoneCtrl = TextEditingController(); // expect +91... or full international
  final _smsCtrl = TextEditingController();
  String? _verificationId;
  bool _otpSent = false;
  bool _loadingPhone = false;
  bool _verifyingOtp = false;

  // General
  bool _demoSigningIn = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _smsCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      _showSnackbar('Enter email and password');
      return;
    }

    setState(() => _loadingEmail = true);
    try {
      await AuthService.instance.signInWithEmail(email, password);
      _showSnackbar('Signed in');
      // After auth, the app-level auth listener will route to appropriate screen.
      // As an immediate fallback, navigate to buyer feed.
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(Routes.buyerFeed);
    } on FirebaseAuthException catch (e) {
      _showSnackbar('Sign-in failed: ${e.message ?? e.code}');
    } catch (e) {
      _showSnackbar('Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _loadingEmail = false);
    }
  }

  Future<void> _sendPhoneOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _showSnackbar('Enter phone number (e.g. +919XXXXXXXXX)');
      return;
    }

    setState(() => _loadingPhone = true);
    try {
      await AuthService.instance.verifyPhone(
        phoneNumber: phone,
        onCodeSent: (verificationId, _) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
          });
          _showSnackbar('OTP sent to $phone');
        },
        onVerified: (credential) async {
          // Auto verification on some Android devices
          try {
            await AuthService.instance.signInWithSmsCode(
                credential.verificationId!, credential.smsCode!);
            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed(Routes.buyerFeed);
          } catch (e) {
            _showSnackbar('Auto verification failed: $e');
          }
        },
        onFailed: (err) {
          _showSnackbar('Phone verification failed: ${err.message}');
        },
      );
    } catch (e) {
      _showSnackbar('Failed to send OTP: $e');
    } finally {
      if (mounted) setState(() => _loadingPhone = false);
    }
  }

  Future<void> _verifySmsCode() async {
    final code = _smsCtrl.text.trim();
    final vId = _verificationId;
    if (vId == null || code.isEmpty) {
      _showSnackbar('Enter the OTP code');
      return;
    }

    setState(() => _verifyingOtp = true);
    try {
      await AuthService.instance.signInWithSmsCode(vId, code);
      _showSnackbar('Phone sign-in successful');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(Routes.buyerFeed);
    } on FirebaseAuthException catch (e) {
      _showSnackbar('OTP verify failed: ${e.message ?? e.code}');
    } catch (e) {
      _showSnackbar('OTP verify failed: $e');
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  Future<void> _signInAnonymouslyDemo() async {
    setState(() => _demoSigningIn = true);
    try {
      await AuthService.instance.signInAnonymously();
      _showSnackbar('Signed in anonymously (Demo)');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(Routes.buyerFeed);
    } catch (e) {
      _showSnackbar('Demo sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _demoSigningIn = false);
    }
  }

  void _showSnackbar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _buildLogo() {
    // Use the uploaded dev image path if present in dev environment.
    const debugLocalLogo = '/mnt/data/3092cec7-47a1-481d-a69d-d5aee694bb52.png';
    // If you added assets/images/logo.png to assets, replace with AssetImage.
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            // Try to load file only if it exists on dev machine; otherwise fallback to Icon.
            File(debugLocalLogo),
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.agriculture, size: 92, color: Colors.green),
          ),
        ),
        const SizedBox(height: 12),
        const Text('KrishiSetu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Farmers → Buyers • List • Negotiate', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keep it simple — login card centered
      appBar: AppBar(
        title: const Text('Sign in (Demo)'),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Center(child: _buildLogo()),
            const SizedBox(height: 18),

            // EMAIL SIGN-IN
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Sign in with Email', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadingEmail ? null : _signInWithEmail,
                      child: _loadingEmail
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Sign in with Email'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // PHONE OTP
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Sign in with Phone (OTP)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (e.g. +919XXXXXXXXX)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loadingPhone ? null : _sendPhoneOtp,
                            child: _loadingPhone
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Send OTP'),
                          ),
                        ),
                      ],
                    ),

                    if (_otpSent) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _smsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Enter OTP'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _verifyingOtp ? null : _verifySmsCode,
                        child: _verifyingOtp
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Verify OTP'),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Demo / Misc actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _demoSigningIn ? null : _signInAnonymouslyDemo,
                      icon: _demoSigningIn ? const SizedBox.shrink() : const Icon(Icons.flash_on),
                      label: _demoSigningIn
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Quick Demo (Anonymous)'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        // Go to role select / register - route name used in routes.dart
                        Navigator.of(context).pushReplacementNamed(Routes.roleSelect);
                      },
                      child: const Text('New user? Select role & sign up'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
            Text(
              'Tip: For OTP tests use a real phone number enabled in Firebase console (or test numbers you configured).',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

