// lib/screens/edit_listing.dart
//
// Edit Listing screen for KrishiSetu prototype.
// - Loads an existing Listing object (passed via constructor).
// - Allows farmer to update: crop, quantity, pricePerUnit, location, and optionally replace the photo.
// - If a new photo is picked, it uploads the photo to Storage (using FirebaseService.uploadListingImage)
//   and then updates the listing document with the new imageUrl.
// - Uses FirebaseService.updateListing(listingId, updates) to persist changes.
// - UI mirrors AddListingScreen for parity and ease-of-use.
//
// EXPECTATIONS:
// - A Listing model exists at lib/models/listing.dart with fields used below.
// - FirebaseService provides: uploadListingImage(File, listingId, onProgress) and updateListing(listingId, Map).
// - Firebase initialized before using this screen.
// - image_picker dependency configured in native platform files.
//
// Usage:
//   Navigator.push(context, MaterialPageRoute(builder: (_) => EditListingScreen(listing: listing)));
//
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/listing.dart';
import '../services/firebase_service.dart';

class EditListingScreen extends StatefulWidget {
  final Listing listing;
  const EditListingScreen({Key? key, required this.listing}) : super(key: key);

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _cropCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _locationCtrl;

  File? _newImageFile;
  double _uploadProgress = 0.0;
  bool _submitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final l = widget.listing;
    _cropCtrl = TextEditingController(text: l.crop);
    _qtyCtrl = TextEditingController(text: l.quantity.toStringAsFixed(0));
    _priceCtrl = TextEditingController(text: l.pricePerUnit.toStringAsFixed(0));
    _locationCtrl = TextEditingController(text: l.location);
  }

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
        _newImageFile = File(picked.path);
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
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
            if (widget.listing.imageUrl.isNotEmpty || _newImageFile != null)
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _newImageFile = null;
                    // Mark that user removed the image: we will set imageUrl to empty on update.
                    // If you prefer keeping old and not removing, comment out the next line.
                    // We'll handle deletion by updating the doc with empty imageUrl.
                  });
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

  Widget _buildImagePreview() {
    final existingUrl = widget.listing.imageUrl;
    if (_newImageFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(_newImageFile!, height: 160, width: double.infinity, fit: BoxFit.cover),
      );
    } else if (existingUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(existingUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
      );
    } else {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.green[50],
          border: Border.all(color: Colors.green.shade100),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.photo, size: 36, color: Colors.green),
            const SizedBox(height: 8),
            Text('No photo — tap to add', style: TextStyle(color: Colors.green.shade800)),
          ]),
        ),
      );
    }
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
      final listingId = widget.listing.id;

      // Prepare updates
      final updates = <String, dynamic>{
        'crop': crop,
        'quantity': qty,
        'pricePerUnit': price,
        'location': location,
      };

      // If user removed image explicitly and no new image selected, clear imageUrl
      final removedImage = _newImageFile == null && widget.listing.imageUrl.isNotEmpty && _shouldClearImage();
      if (removedImage) {
        updates['imageUrl'] = '';
      }

      // If new image selected, upload it with listingId
      if (_newImageFile != null) {
        final imageUrl = await FirebaseService.instance.uploadListingImage(
          _newImageFile!,
          listingId,
          onProgress: (progress) {
            if (mounted) setState(() => _uploadProgress = progress);
          },
        );
        updates['imageUrl'] = imageUrl;
      }

      if (updates.isNotEmpty) {
        await FirebaseService.instance.updateListing(listingId, updates);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing updated')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() {
        _submitting = false;
        _uploadProgress = 0.0;
      });
    }
  }

  // Helper to determine whether the user intended to clear the existing image.
  // We clear image only if original had image and user tapped "Remove photo".
  bool _shouldClearImage() {
    // If original had image and _newImageFile is null and UI shows no image, user likely removed it.
    // We rely on the Remove photo action setting _newImageFile to null (it already is) but no other flag.
    // For more explicit behavior, maintain a separate bool like _removedImageFlag.
    // Here we use a simple heuristic: if original had image and currently neither _newImageFile nor widget.listing.imageUrl is shown,
    // but because widget.listing.imageUrl remains the original, we need an explicit flag. Let's implement that flag.
    return _removedImageFlag;
  }

  // Use an explicit flag for remove action to avoid accidental clearing.
  bool _removedImageFlag = false;

  @override
  Widget build(BuildContext context) {
    final isBusy = _submitting;
    final createdAt = widget.listing.createdAt;
    final createdAtStr = createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt) : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Listing')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () async {
                  // Show options. If user chooses remove, set flag.
                  await showModalBottomSheet(
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
                              _removedImageFlag = false;
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: const Text('Choose from gallery'),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _pickImage(ImageSource.gallery);
                              _removedImageFlag = false;
                            },
                          ),
                          if (widget.listing.imageUrl.isNotEmpty || _newImageFile != null)
                            ListTile(
                              leading: const Icon(Icons.delete_forever),
                              title: const Text('Remove photo'),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                setState(() {
                                  _newImageFile = null;
                                  _removedImageFlag = true; // explicit removal
                                });
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
                },
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(label: Text('Status: ${widget.listing.status}')),
                  const SizedBox(width: 12),
                  if (createdAtStr.isNotEmpty) Text('Posted: $createdAtStr', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 12),
              if (_uploadProgress > 0.0 && _uploadProgress < 1.0)
                Column(children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('Uploading image ${(100 * _uploadProgress).toStringAsFixed(0)}%'),
                  const SizedBox(height: 12),
                ]),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isBusy ? null : _submit,
                      child: isBusy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save changes'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: isBusy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  )
                ],
              ),
              const SizedBox(height: 8),
              if (widget.listing.status == Listing.STATUS_SOLD)
                Text('Note: This listing is marked sold. Editing will not change transaction history.', style: TextStyle(color: Colors.red.shade700)),
            ]),
          ),
        ),
      ),
    );
  }
}
