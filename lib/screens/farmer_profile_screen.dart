// lib/screens/farmer_profile_screen.dart
//
// Farmer Profile screen for KrishiSetu.
// - Shows current user's profile (name, phone, role, location, avatar).
// - Allows editing and saving profile to Firestore via FirebaseService.createOrUpdateUserProfile.
// - Allows picking/updating avatar (uploads to Firebase Storage under `users/{uid}.jpg`) and stores public url in user doc.
// - Shows quick stats: count of active listings and pending offers for this farmer (uses FirebaseService streams).
// - Provides Sign out button.
//
// Requirements / assumptions:
// - Firebase initialized.
// - AppUser model is available at ../models/user.dart with fields: id, name, phone, role, location, createdAt, avatarUrl (optional).
//   and methods: AppUser.fromMap(String id, Map<String,dynamic> map) and toMap()
// - FirebaseService has methods used below: createOrUpdateUserProfile(AppUser), streamListingsForUser(userId),
//   streamPendingOffersForFarmer(farmerId).
// - image_picker is added to pubspec and configured for platforms.
// - This screen is intended for the farmer role but works for any logged in user.
//
// Usage:
//   Navigator.push(context, MaterialPageRoute(builder: (_) => FarmerProfileScreen()));
//

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/listing.dart';
import '../models/user.dart';
import '../services/firebase_service.dart';

class FarmerProfileScreen extends StatefulWidget {
  const FarmerProfileScreen({Key? key}) : super(key: key);

  @override
  State<FarmerProfileScreen> createState() => _FarmerProfileScreenState();
}

class _FarmerProfileScreenState extends State<FarmerProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  AppUser? _user; // local copy of profile
  bool _loading = true;
  bool _saving = false;

  File? _pickedImage;
  double _uploadProgress = 0.0;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    setState(() {
      _loading = true;
    });

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      // No auth user — create a demo user in UI (optional)
      setState(() {
        _user = AppUser(
          id: 'demo_farmer',
          name: 'Demo Farmer',
          phone: '',
          role: 'farmer',
          location: '',
          createdAt: DateTime.now(),
          avatarUrl: '',
        );
        _nameCtrl.text = _user!.name;
        _phoneCtrl.text = _user!.phone ?? '';
        _locationCtrl.text = _user!.location ?? '';
        _loading = false;
      });
      return;
    }

    try {
      final profile = await FirebaseService.instance.getUserById(firebaseUser.uid);
      if (profile != null) {
        _user = profile;
      } else {
        // Create a minimal profile doc if not present
        _user = AppUser(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? '',
          phone: firebaseUser.phoneNumber ?? '',
          role: 'farmer',
          location: '',
          createdAt: DateTime.now(),
          avatarUrl: '',
        );
        // save initial profile (non-blocking)
        await FirebaseService.instance.createOrUpdateUserProfile(_user!);
      }

      _nameCtrl.text = _user!.name;
      _phoneCtrl.text = _user!.phone ?? '';
      _locationCtrl.text = _user!.location ?? '';
    } catch (e) {
      // ignore, show minimal UI
      _user = AppUser(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? '',
        phone: firebaseUser.phoneNumber ?? '',
        role: 'farmer',
        location: '',
        createdAt: DateTime.now(),
        avatarUrl: '',
      );
      _nameCtrl.text = _user!.name;
      _phoneCtrl.text = _user!.phone ?? '';
      _locationCtrl.text = _user!.location ?? '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar(ImageSource src) async {
    try {
      final picked = await _picker.pickImage(source: src, imageQuality: 85, maxWidth: 1200);
      if (picked == null) return;
      setState(() => _pickedImage = File(picked.path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
    }
  }

  Future<String> _uploadAvatar(File file, String uid) async {
    final ext = file.path.split('.').last;
    final storageRef = FirebaseStorage.instance.ref().child('users/$uid.$ext');

    final uploadTask = storageRef.putFile(file);

    final completer = Completer<String>();
    uploadTask.snapshotEvents.listen((s) {
      final total = s.totalBytes;
      final progress = (s.bytesTransferred / total);
      if (mounted) setState(() => _uploadProgress = progress);
    }, onError: (err) {
      if (!completer.isCompleted) completer.completeError(err);
    });

    try {
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      if (!completer.isCompleted) completer.complete(url);
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }

    return completer.future;
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final uid = firebaseUser?.uid ?? _user?.id ?? 'demo_farmer';

    setState(() => _saving = true);

    try {
      String avatarUrl = _user?.avatarUrl ?? '';

      // 1) If a new avatar was picked, upload it and replace avatarUrl
      if (_pickedImage != null) {
        avatarUrl = await _uploadAvatar(_pickedImage!, uid);
      }

      // 2) Build user object
      final updated = AppUser(
        id: uid,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: _user?.role ?? 'farmer',
        location: _locationCtrl.text.trim(),
        createdAt: _user?.createdAt ?? DateTime.now(),
        avatarUrl: avatarUrl,
      );

      // 3) Save to Firestore
      await FirebaseService.instance.createOrUpdateUserProfile(updated);

      if (!mounted) return;
      setState(() {
        _user = updated;
        _pickedImage = null;
        _uploadProgress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _avatarWidget() {
    final avatarUrl = _pickedImage != null ? null : _user?.avatarUrl;
    final showLocal = _pickedImage != null;
    final radius = 46.0;

    return Stack(children: [
      CircleAvatar(
        radius: radius,
        backgroundColor: Colors.green[50],
        child: ClipOval(
          child: SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: showLocal
                ? Image.file(_pickedImage!, fit: BoxFit.cover)
                : (avatarUrl != null && avatarUrl.isNotEmpty
                ? Image.network(avatarUrl, fit: BoxFit.cover)
                : Icon(Icons.person, size: 48, color: Colors.green[700])),
          ),
        ),
      ),
      Positioned(
        right: 0,
        bottom: 0,
        child: InkWell(
          onTap: _showAvatarOptions,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
            ]),
            child: Icon(Icons.camera_alt, size: 18, color: Colors.green[800]),
          ),
        ),
      ),
    ]);
  }

  Future<void> _showAvatarOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Take photo'),
            onTap: () {
              Navigator.of(ctx).pop();
              _pickAvatar(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.of(ctx).pop();
              _pickAvatar(ImageSource.gallery);
            },
          ),
          if ((_user?.avatarUrl ?? '').isNotEmpty || _pickedImage != null)
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Remove photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _pickedImage = null;
                  _user = _user?.copyWith(avatarUrl: '');
                });
              },
            ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final uid = _user?.id ?? FirebaseAuth.instance.currentUser?.uid ?? 'demo_farmer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: _avatarWidget()),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _user?.role == 'farmer' ? 'Farmer Profile' : 'Profile',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 18),

            Form(
              key: _formKey,
              child: Column(children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder(), prefixText: '+91 '),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(labelText: 'Location (city / village)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      // revert changes
                      _nameCtrl.text = _user?.name ?? '';
                      _phoneCtrl.text = _user?.phone ?? '';
                      _locationCtrl.text = _user?.location ?? '';
                      setState(() {
                        _pickedImage = null;
                        _uploadProgress = 0.0;
                      });
                    },
                    child: const Text('Reset'),
                  ),
                ]),
              ]),
            ),

            const SizedBox(height: 20),

            // Quick stats (active listings, pending offers)
            StreamBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
              stream: FirebaseService.instance.streamListingsForUser(uid).map((l) => l.map((e) => e).toList()).asStream(),
              // Note: streamListingsForUser returns Stream<List<Listing>> in our service; we adapt to count by listening to same stream.
              builder: (context, snap) {
                // Because of type differences across implementations, use FirebaseService directly for counts below
                return StreamBuilder<List>(
                  stream: FirebaseService.instance.streamListingsForUser(uid).map((lst) => lst),
                  builder: (context, s2) {
                    final listings = s2.data ?? [];
                    final openCount = listings.where((l) => (l.status == Listing.STATUS_OPEN)).length;
                    return FutureBuilder<int>(
                      future: _getPendingOffersCount(uid),
                      builder: (context, pendingSnap) {
                        final pending = pendingSnap.data ?? 0;
                        return Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(children: [Text(openCount.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 6), const Text('Open listings')]),
                                Column(children: [Text(pending.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 6), const Text('Pending offers')]),
                                Column(children: [Text(_user?.role ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 6), const Text('Role')]),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 16),

            if (_uploadProgress > 0.0 && _uploadProgress < 1.0)
              Column(children: [
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 8),
                Text('Uploading avatar ${(100 * _uploadProgress).toStringAsFixed(0)}%'),
                const SizedBox(height: 12),
              ]),

            const SizedBox(height: 8),

            // Developer / debug area
            ExpansionTile(
              title: const Text('Developer / Debug'),
              children: [
                ListTile(
                  title: const Text('User ID'),
                  subtitle: Text(uid),
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app),
                  title: const Text('Sign out'),
                  onTap: _signOut,
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  /// Helper to get pending offers count for farmer — uses service stream that collects offers for farmer's listings.
  Future<int> _getPendingOffersCount(String farmerId) async {
    try {
      // Because streamPendingOffersForFarmer returns Stream<List<Offer>>, we can listen for a single snapshot using first
      final stream = FirebaseService.instance.streamPendingOffersForFarmer(farmerId);
      final offers = await stream.first;
      return offers.length;
    } catch (_) {
      return 0;
    }
  }
}

extension on Stream<List<Listing>> {
  asStream() {}
}
