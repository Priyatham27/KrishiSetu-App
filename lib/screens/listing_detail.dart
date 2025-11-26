// lib/screens/listing_detail.dart
//
// Detailed listing screen / modal for KrishiSetu.
// - Shows listing image, crop, qty, price, location, seller info
// - Buyer: can make an offer (inline form)
// - Farmer: can view offers for this listing and accept / counter / reject
// - Contact actions: Call & WhatsApp (using seller phone stored in AppUser record)
// - Uses FirebaseService for DB operations and AuthService for current user id
//
// Usage:
//   Navigator.pushNamed(context, Routes.listingDetail, arguments: listing);
// or
//   Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: listing)));
//
// Note: This file expects these project files to exist and match names used here:
// - models/listing.dart -> class Listing { id, crop, quantity, unit, pricePerUnit, imageUrl, location, userId, status, createdAt }
// - models/offer.dart -> class Offer with static STATUS_* fields and fromMap/toMap
// - models/user.dart -> class AppUser with fields id,name,phone,role
// - services/firebase_service.dart -> FirebaseService.instance methods used below
// - services/auth_service.dart -> AuthService.instance.currentUid() (or fallback to FirebaseAuth.currentUser.uid)
//
// If any helper method names differ in your project, adapt accordingly.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/listing.dart';
import '../models/offer.dart';
import '../models/user.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';

class ListingDetailScreen extends StatefulWidget {
  final Listing listing;
  const ListingDetailScreen({Key? key, required this.listing}) : super(key: key);

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  bool _makingOffer = false;
  final _offerPriceCtrl = TextEditingController();
  final _offerQtyCtrl = TextEditingController();
  final _offerMsgCtrl = TextEditingController();

  // For farmer view
  Stream<List<Offer>>? _offersStream;
  AppUser? _sellerProfile;
  String? _currentUid;
  bool _loadingSeller = false;

  @override
  void initState() {
    super.initState();
    _currentUid = AuthService.instance.currentUid(); // implement accordingly in your auth service
    // If current user is farmer and owns this listing -> stream offers for the listing
    _offersStream = FirebaseService.instance.streamOffersForListing(widget.listing.id);
    _fetchSeller();
  }

  Future<void> _fetchSeller() async {
    setState(() => _loadingSeller = true);
    try {
      _sellerProfile = await FirebaseService.instance.getUserById(widget.listing.userId);
    } catch (_) {
      _sellerProfile = null;
    } finally {
      if (mounted) setState(() => _loadingSeller = false);
    }
  }

  @override
  void dispose() {
    _offerPriceCtrl.dispose();
    _offerQtyCtrl.dispose();
    _offerMsgCtrl.dispose();
    super.dispose();
  }

  bool get isOwner => _currentUid != null && _currentUid == widget.listing.userId;

  Future<void> _makeOffer() async {
    final price = double.tryParse(_offerPriceCtrl.text.trim());
    final qty = double.tryParse(_offerQtyCtrl.text.trim());

    if (price == null || price <= 0) {
      _showSnack('Enter a valid offer price');
      return;
    }
    if (qty == null || qty <= 0) {
      _showSnack('Enter a valid quantity');
      return;
    }

    setState(() => _makingOffer = true);

    try {
      final buyerId = _currentUid ?? 'demo_buyer';
      final offer = Offer(
        id: '',
        listingId: widget.listing.id,
        buyerId: buyerId,
        offerPrice: price,
        quantity: qty,
        status: Offer.STATUS_PENDING,
        createdAt: DateTime.now(),
        counterPrice: null,
        message: _offerMsgCtrl.text.trim().isEmpty ? null : _offerMsgCtrl.text.trim(), 
      );

      await FirebaseService.instance.makeOffer(offer);
      _showSnack('Offer submitted');
      _offerPriceCtrl.clear();
      _offerQtyCtrl.clear();
      _offerMsgCtrl.clear();
    } catch (e) {
      _showSnack('Failed to submit offer: $e');
    } finally {
      if (mounted) setState(() => _makingOffer = false);
    }
  }

  Future<void> _respondOffer(Offer offer, String action, {double? counterPrice}) async {
    // Confirm with farmer before performing destructive actions
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == Offer.STATUS_ACCEPTED ? 'Accept offer' : action == Offer.STATUS_REJECTED ? 'Reject offer' : 'Counter offer'),
        content: Text(action == Offer.STATUS_ACCEPTED
            ? 'Accept this offer from buyer for ₹${offer.offerPrice.toStringAsFixed(0)}?'
            : action == Offer.STATUS_REJECTED
            ? 'Reject this offer?'
            : 'Counter with price ₹${counterPrice?.toStringAsFixed(0) ?? ''}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseService.instance.respondOffer(offerId: offer.id, action: action, counterPrice: counterPrice);
      _showSnack('Offer ${action.toLowerCase()}');
    } catch (e) {
      _showSnack('Failed to respond to offer: $e');
    }
  }

  Future<void> _callSeller() async {
    final phone = _sellerProfile?.phone;
    if (phone == null || phone.isEmpty) {
      _showSnack('Seller phone not available');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnack('Cannot launch dialer');
    }
  }

  Future<void> _whatsappSeller() async {
    final phone = _sellerProfile?.phone;
    if (phone == null || phone.isEmpty) {
      _showSnack('Seller phone not available');
      return;
    }
    // Use wa.me link (phone without +)
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$normalized?text=${Uri.encodeComponent('Hi, I saw your listing on KrishiSetu for ${widget.listing.crop}.')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Cannot open WhatsApp');
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _buildHeader() {
    final l = widget.listing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: l.imageUrl.isNotEmpty
              ? Image.network(l.imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderImage())
              : _placeholderImage(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text(l.crop, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            Chip(
              label: Text('₹${l.pricePerUnit.toStringAsFixed(0)}/${l.unit}', style: const TextStyle(fontWeight: FontWeight.w700)),
              backgroundColor: Colors.green.shade50,
            )
          ],
        ),
        const SizedBox(height: 6),
        Text('${l.quantity.toStringAsFixed(0)} ${l.unit} • ${l.location}', style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 6),
        Text('Posted: ${l.createdAt.toLocal().toString().split('.').first}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _placeholderImage() {
    return Container(
      height: 200,
      color: Colors.green.shade50,
      child: const Center(child: Icon(Icons.image, size: 64, color: Colors.green)),
    );
  }

  Widget _buyerActions() {
    final l = widget.listing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Make an Offer', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _offerPriceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Offer price (₹/${l.unit})', hintText: l.pricePerUnit.toStringAsFixed(0)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _offerQtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Quantity (${l.unit})', hintText: l.quantity.toStringAsFixed(0)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _offerMsgCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Message (optional)'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _makingOffer ? null : _makeOffer,
            child: _makingOffer ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit Offer'),
          ),
        ]),
      ),
    );
  }

  Widget _sellerInfo() {
    if (_loadingSeller) {
      return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()));
    }
    if (_sellerProfile == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          CircleAvatar(child: Text(_sellerProfile!.name.isNotEmpty ? _sellerProfile!.name[0].toUpperCase() : '?')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_sellerProfile!.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(_sellerProfile?.location ?? '', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
          IconButton(onPressed: _callSeller, icon: const Icon(Icons.call)),
          IconButton(onPressed: _whatsappSeller, icon: const Icon(Icons.message)),
        ]),
      ),
    );
  }

  Widget _offersList() {
    return StreamBuilder<List<Offer>>(
      stream: _offersStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Offers error: ${snap.error}'));
        }
        final offers = snap.data ?? [];
        if (offers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No offers yet for this listing', style: TextStyle(color: Colors.black54)),
          );
        }
        return Column(
          children: offers.map((o) {
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                title: Text('₹${o.offerPrice.toStringAsFixed(0)} • ${o.quantity.toStringAsFixed(0)} ${widget.listing.unit}'),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (o.message != null) Text(o.message!),
                  const SizedBox(height: 4),
                  Text('Status: ${o.status}', style: const TextStyle(fontSize: 12)),
                ]),
                trailing: isOwner
                    ? PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'accept') {
                      await _respondOffer(o, Offer.STATUS_ACCEPTED);
                    } else if (action == 'reject') {
                      await _respondOffer(o, Offer.STATUS_REJECTED);
                    } else if (action == 'counter') {
                      // show counter input
                      final controller = TextEditingController(text: o.offerPrice.toStringAsFixed(0));
                      final result = await showDialog<double?>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Counter Offer'),
                          content: TextField(
                            controller: controller,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Counter price (₹)'),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.of(ctx).pop(double.tryParse(controller.text.trim())), child: const Text('Send')),
                          ],
                        ),
                      );
                      if (result != null) {
                        await _respondOffer(o, Offer.STATUS_COUNTERED, counterPrice: result);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'accept', child: Text('Accept')),
                    const PopupMenuItem(value: 'counter', child: Text('Counter')),
                    const PopupMenuItem(value: 'reject', child: Text('Reject')),
                  ],
                )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing'),
        actions: [
          if (!isOwner)
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                // future: quick actions
                _showSnack('Feature: view cart (not implemented)');
              },
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildHeader(),
            const SizedBox(height: 6),
            _sellerInfo(),
            const SizedBox(height: 6),
            if (!isOwner) _buyerActions(),
            if (isOwner) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Offers', style: TextStyle(fontWeight: FontWeight.w800))),
            if (isOwner) _offersList(),
            const SizedBox(height: 18),
            // Transaction note / status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Status', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Listing status: ${l.status}', style: const TextStyle()),
                  const SizedBox(height: 6),
                  // If sold show note (production apps would show transaction details)
                  if (l.status == Listing.STATUS_SOLD)
                    const Text('This listing is marked sold. Check Transactions screen for details.', style: TextStyle(color: Colors.black54)),
                ]),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}
