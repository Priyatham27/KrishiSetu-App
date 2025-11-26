// lib/screens/add_listing.dart
//
// Add Listing screen for KrishiSetu prototype.
// - Farmer can create a listing with: crop, quantity (kg), pricePerUnit, location, photo.
// - Uploads image to Firebase Storage (using FirebaseService.uploadListingImage).
// - Creates Firestore listing doc (using FirebaseService.addListing) and updates the doc with imageUrl.
// - Shows upload progress and disables UI while uploading.
//
// Notes / Assumptions:
// - There is a Listing model with a constructor similar to:
//     Listing({required String id, required String userId, required String crop, required double quantity,
//              required String unit, required double pricePerUnit, required String imageUrl, required String location,
//              required String status, required DateTime createdAt})
//   and a .toMap() method used by FirebaseService.addListing.
// - FirebaseService.instance.addListing(Listing) returns the created document ID.
// - FirebaseService.instance.uploadListingImage(File, listingId, onProgress: (p) {}) uploads and returns download URL.
// - Firebase must be initialized before this screen is used (e.g., in main()).
// - image_picker and permission handling are expected to be configured in Android/iOS native files.
//
// If your model/signatures differ, adapt the Listing constructor/field names accordingly.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/listing.dart';
import '../services/firebase_service.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({Key? key}) : super(key: key);

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _cropCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  File? _imageFile;
  double _uploadProgress = 0.0;
  bool _submitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _cropCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
      if (picked == null) return;
      setState(() {
        _imageFile = File(picked.path);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
      }
    }
  }

  Future<void> _showImageOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final crop = _cropCtrl.text.trim();
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final location = _locationCtrl.text.trim().isEmpty ? 'Unknown' : _locationCtrl.text.trim();

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid quantity')));
      return;
    }
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid price')));
      return;
    }

    setState(() {
      _submitting = true;
      _uploadProgress = 0.0;
    });

    try {
      // Determine user id (demo fallback)
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'demo_farmer';

      // Create a Listing object with placeholder imageUrl (empty) so we can get a doc id first.
      final listing = Listing(
        id: '', // firestore will set id
        userId: userId,
        crop: crop,
        quantity: qty,
        unit: 'kg',
        pricePerUnit: price,
        imageUrl: '',
        location: location,
        status: Listing.STATUS_OPEN,
        createdAt: DateTime.now(),
      );

      // 1) create doc to get id
      final createdId = await FirebaseService.instance.addListing(listing);

      String imageUrl = '';
      if (_imageFile != null) {
        // 2) upload image with listing id
        imageUrl = await FirebaseService.instance.uploadListingImage(
          _imageFile!,
          createdId,
          onProgress: (progress) {
            if (mounted) setState(() => _uploadProgress = progress);
          },
        );
      }

      // 3) update listing doc with imageUrl (if any)
      final updates = <String, dynamic>{
        if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      };

      if (updates.isNotEmpty) {
        await FirebaseService.instance.updateListing(createdId, updates);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing created')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create listing: $e')));
      }
    } finally {
      if (mounted) setState(() {
        _submitting = false;
        _uploadProgress = 0.0;
      });
    }
  }

  Widget _buildImagePreview() {
    if (_imageFile != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_imageFile!, height: 140, width: double.infinity, fit: BoxFit.cover));
    } else {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.green[50],
          border: Border.all(color: Colors.green.shade100),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.photo, size: 36, color: Colors.green),
            const SizedBox(height: 8),
            Text('Add a photo of the produce', style: TextStyle(color: Colors.green.shade800)),
          ]),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Listing')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(children: [
              GestureDetector(
                onTap: _showImageOptions,
                child: _buildImagePreview(),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _cropCtrl,
                    decoration: const InputDecoration(labelText: 'Crop (e.g., Tomato)', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter crop name' : null,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Qty (kg)', border: OutlineInputBorder()),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price per kg (₹)', border: OutlineInputBorder()),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              if (_uploadProgress > 0.0 && _uploadProgress < 1.0)
                Column(children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('Uploading image ${(100 * _uploadProgress).toStringAsFixed(0)}%'),
                  const SizedBox(height: 12),
                ]),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isBusy ? null : _submit,
                  child: isBusy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Listing'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: isBusy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
