// lib/screens/buyer_profile_screen.dart
//
// Buyer Profile screen for KrishiSetu.
// - Shows current user's profile (name, phone, role, location, avatar).
// - Allows editing and saving profile to Firestore via FirebaseService.createOrUpdateUserProfile.
// - Allows picking/updating avatar (uploads to Firebase Storage under `users/{uid}.{ext}`) and stores public url in user doc.
// - Shows quick list of recent transactions for this buyer (uses FirebaseService.streamTransactionsForBuyer).
// - Provides Sign out button.
//
// Assumptions:
// - Firebase initialized.
// - AppUser model exists at ../models/user.dart with fields (id, name, phone, role, location, createdAt, avatarUrl) and helpers.
// - FirebaseService has methods: getUserById, createOrUpdateUserProfile, uploadListingImage (we'll reuse for avatar by passing user id), streamTransactionsForBuyer.
// - TransactionModel exists at ../models/transaction.dart with fields used below.
//
// Usage:
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const BuyerProfileScreen()));
//

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/user.dart';
import '../models/transaction.dart';
import '../services/firebase_service.dart';

class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({Key? key}) : super(key: key);

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  AppUser? _user;
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
    setState(() => _loading = true);
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      // No auth user — fallback to demo lightweight profile
      final demo = AppUser(
        id: 'demo_buyer',
        name: 'Demo Buyer',
        phone: '',
        role: 'buyer',
        location: '',
        createdAt: DateTime.now(),
        avatarUrl: '',
      );
      setState(() {
        _user = demo;
        _nameCtrl.text = demo.name;
        _phoneCtrl.text = demo.phone ?? '';
        _locationCtrl.text = demo.location ?? '';
        _loading = false;
      });
      return;
    }

    try {
      final profile = await FirebaseService.instance.getUserById(firebaseUser.uid);
      if (profile != null) {
        _user = profile;
      } else {
        // create a minimal profile doc if not present
        _user = AppUser(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? '',
          phone: firebaseUser.phoneNumber ?? '',
          role: 'buyer',
          location: '',
          createdAt: DateTime.now(),
          avatarUrl: '',
        );
        await FirebaseService.instance.createOrUpdateUserProfile(_user!);
      }

      _nameCtrl.text = _user!.name;
      _phoneCtrl.text = _user!.phone ?? '';
      _locationCtrl.text = _user!.location ?? '';
    } catch (e) {
      // fallback to minimal ui and notify
      _user = AppUser(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? '',
        phone: firebaseUser.phoneNumber ?? '',
        role: 'buyer',
        location: '',
        createdAt: DateTime.now(),
        avatarUrl: '',
      );
      _nameCtrl.text = _user!.name;
      _phoneCtrl.text = _user!.phone ?? '';
      _locationCtrl.text = _user!.location ?? '';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
    }
  }

  Future<String> _uploadAvatar(File file, String uid) async {
    final ext = file.path.split('.').last;
    final ref = FirebaseStorage.instance.ref().child('users/$uid.$ext');
    final uploadTask = ref.putFile(file);

    final completer = Completer<String>();
    uploadTask.snapshotEvents.listen((snap) {
      final total = snap.totalBytes == 0 ? 1 : snap.totalBytes!;
      final progress = snap.bytesTransferred / total;
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

    setState(() => _saving = true);
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final uid = firebaseUser?.uid ?? _user?.id ?? 'demo_buyer';

    try {
      var avatarUrl = _user?.avatarUrl ?? '';

      if (_pickedImage != null) {
        avatarUrl = await _uploadAvatar(_pickedImage!, uid);
      }

      final updated = AppUser(
        id: uid,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: _user?.role ?? 'buyer',
        location: _locationCtrl.text.trim(),
        createdAt: _user?.createdAt ?? DateTime.now(),
        avatarUrl: avatarUrl,
      );

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
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Widget _avatarWidget() {
    final radius = 46.0;
    final avatarUrl = _user?.avatarUrl ?? '';
    final showLocal = _pickedImage != null;

    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: Colors.green[50],
          child: ClipOval(
            child: SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: showLocal
                  ? Image.file(_pickedImage!, fit: BoxFit.cover)
                  : (avatarUrl.isNotEmpty ? Image.network(avatarUrl, fit: BoxFit.cover) : Icon(Icons.person, size: 48, color: Colors.green[700])),
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Icon(Icons.camera_alt, size: 18, color: Colors.green[800]),
            ),
          ),
        )
      ],
    );
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

  Widget _buildTransactionTile(TransactionModel tx) {
    // TransactionModel assumed fields: id, listingId, buyerId, sellerId, finalPrice, quantity, status, createdAt
    final subtitle = '₹${tx.finalPrice.toStringAsFixed(0)} • ${tx.quantity.toStringAsFixed(0)} kg • ${tx.status}';
    final date = tx.createdAt != null ? tx.createdAt!.toLocal() : null;
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: const Icon(Icons.shopping_cart, color: Colors.green),
        title: Text('Listing: ${tx.listingId ?? tx.id}'),
        subtitle: Text('$subtitle\n$dateStr'),
        isThreeLine: true,
        trailing: Text(tx.status, style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: () {
          // Optionally navigate to transaction detail screen if available
        },
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

    final uid = _user?.id ?? FirebaseAuth.instance.currentUser?.uid ?? 'demo_buyer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadCurrentUser(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _avatarWidget()),
                const SizedBox(height: 12),
                Center(child: Text(_user?.role == 'buyer' ? 'Buyer Profile' : 'Profile', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                const SizedBox(height: 16),

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
                      decoration: const InputDecoration(labelText: 'Location (city)', border: OutlineInputBorder()),
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

                if (_uploadProgress > 0.0 && _uploadProgress < 1.0)
                  Column(children: [
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text('Uploading avatar ${(100 * _uploadProgress).toStringAsFixed(0)}%'),
                    const SizedBox(height: 12),
                  ]),

                const SizedBox(height: 8),
                const Text('Recent transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),

                // Stream of transactions for this buyer
                StreamBuilder<List<TransactionModel>>(
                  stream: FirebaseService.instance.streamTransactionsForBuyer(uid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('Failed to load transactions: ${snap.error}', style: const TextStyle(color: Colors.red)),
                      );
                    }
                    final txs = snap.data ?? [];
                    if (txs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('No transactions yet. Make an offer and confirm to create a transaction.', style: TextStyle(color: Colors.black54)),
                      );
                    }

                    // Show up to 6 recent transactions
                    final recent = txs.take(6).toList();
                    return Column(
                      children: recent.map((t) => _buildTransactionTile(t)).toList(),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Developer / debug panel
                ExpansionTile(
                  title: const Text('Developer / Debug'),
                  children: [
                    ListTile(
                      title: const Text('User ID'),
                      subtitle: Text(uid),
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Profile JSON'),
                      subtitle: Text(_user?.toMap().toString() ?? ''),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
