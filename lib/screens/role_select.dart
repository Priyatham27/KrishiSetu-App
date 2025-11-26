// lib/screens/role_select.dart
//
// Role selection + simple profile creation screen for KrishiSetu prototype.
// - Choose role: Farmer or Buyer
// - Enter name, phone (prefilled from FirebaseAuth if available), optional location
// - Saves user profile into Firestore via FirebaseService.createOrUpdateUserProfile
// - If user is not authenticated, will sign in anonymously first (demo flow).
// - After saving, navigates to Farmer or Buyer dashboard.
//
// Note: This file expects AppUser model (lib/models/user.dart), AuthService (lib/services/auth_service.dart)
// and FirebaseService (lib/services/firebase_service.dart) to exist and match the project's structure.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../routes.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({Key? key}) : super(key: key);

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  String? _selectedRole; // 'farmer' or 'buyer'
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Prefill phone if current firebase user exists
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null && fbUser.phoneNumber != null && fbUser.phoneNumber!.isNotEmpty) {
      _phoneCtrl.text = fbUser.phoneNumber!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureSignedIn() async {
    // If not signed in, sign in anonymously for demo flow.
    if (FirebaseAuth.instance.currentUser == null) {
      await AuthService.instance.signInAnonymously();
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final loc = _locationCtrl.text.trim();

    if (_selectedRole == null) {
      _showSnackbar('Please select a role: Farmer or Buyer');
      return;
    }
    if (name.isEmpty) {
      _showSnackbar('Please enter your name');
      return;
    }
    if (phone.isEmpty) {
      _showSnackbar('Please enter your phone number (use +91... format if possible)');
      return;
    }

    setState(() => _saving = true);

    try {
      await _ensureSignedIn();

      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'demo_${DateTime.now().millisecondsSinceEpoch}';

      final appUser = AppUser(
        id: uid,
        name: name,
        phone: phone,
        role: _selectedRole == 'farmer' ? AppUser.ROLE_FARMER : AppUser.ROLE_BUYER,
        location: loc.isNotEmpty ? {'place': loc} : null,
        createdAt: DateTime.now(),
      );

      await FirebaseService.instance.createOrUpdateUserProfile(appUser);

      _showSnackbar('Profile saved');

      // Navigate to appropriate dashboard
      if (!mounted) return;
      if (appUser.role == AppUser.ROLE_FARMER) {
        Navigator.of(context).pushReplacementNamed(Routes.farmerDashboard);
      } else {
        Navigator.of(context).pushReplacementNamed(Routes.buyerFeed);
      }
    } catch (e) {
      _showSnackbar('Failed to save profile: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _roleTile({
    required String roleKey,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _selectedRole == roleKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = roleKey),
      child: Card(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: selected ? Colors.green : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: selected ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 28, color: selected ? Colors.green : Colors.black54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                ]),
              ),
              if (selected) const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _roleTile(
          roleKey: 'farmer',
          title: 'Farmer',
          subtitle: 'List produce, receive offers from buyers',
          icon: Icons.agriculture,
        ),
        _roleTile(
          roleKey: 'buyer',
          title: 'Buyer',
          subtitle: 'Browse listings, make offers',
          icon: Icons.shopping_basket,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Location (village/town) - optional'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProfile,
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save & Continue'),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            // Optionally allow demo quick sign-in
            _showDemoSignInDialog();
          },
          child: const Text('Use quick demo (anonymous)'),
        ),
      ],
    );
  }

  void _showDemoSignInDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quick Demo'),
        content: const Text('This will create an anonymous session and let you try the app quickly. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                setState(() => _saving = true);
                await AuthService.instance.signInAnonymously();
                _showSnackbar('Signed in anonymously. Please select role & save profile.');
              } catch (e) {
                _showSnackbar('Demo sign-in failed: $e');
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Role'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 6),
            const Text(
              'Who are you?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text('Choose your role to continue. You can change this later in profile settings.'),
            const SizedBox(height: 14),
            _buildForm(),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'KrishiSetu • Build direct links between farmers and buyers',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
