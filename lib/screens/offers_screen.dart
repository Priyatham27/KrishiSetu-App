// lib/screens/offers_screen.dart
//
// Offers screen for KrishiSetu prototype.
// - Shows either:
//    * For Farmers: pending offers for listings they own (streamPendingOffersForFarmer)
//    * For Buyers: offers they created (streamOffersForBuyer)
// - Farmer can Accept / Counter / Reject offers.
// - Buyer can Cancel (reject) their own pending offers.
// - Uses FirebaseService wrapper for DB operations and FirebaseAuth for identity.
// - Assumes Offer model has static STATUS_* fields and toMap/fromMap constructors.
//
// Note: adapt AuthService usage if your project uses a custom auth wrapper.
// This file is intentionally self-contained and uses FirebaseAuth as fallback.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/offer.dart';
import '../models/listing.dart';
import '../services/firebase_service.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({Key? key, required Listing listing}) : super(key: key);

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  String? _currentUid;
  String? _currentRole; // 'farmer' | 'buyer' or null while loading
  late Stream<List<Offer>> _offersStream;
  final Map<String, Listing?> _listingCache = {};

  bool _loadingRole = true;

  get child => null;

  @override
  void initState() {
    super.initState();
    _initUserAndStream();
  }

  Future<void> _initUserAndStream() async {
    setState(() => _loadingRole = true);
    final user = FirebaseAuth.instance.currentUser;
    _currentUid = user?.uid;

    try {
      if (_currentUid == null) {
        // If not signed in, treat as buyer demo (show buyer's offers using demo id)
        _currentRole = 'buyer';
        _currentUid = 'demo_buyer';
        _offersStream = FirebaseService.instance.streamOffersForBuyer(_currentUid!);
      } else {
        // Try fetching profile to know role
        final profile = await FirebaseService.instance.getUserById(_currentUid!);
        if (profile != null) {
          _currentRole = profile.role;
        } else {
          // default to buyer if no profile
          _currentRole = 'buyer';
        }

        if (_currentRole == 'farmer') {
          _offersStream = FirebaseService.instance.streamPendingOffersForFarmer(_currentUid!);
        } else {
          _offersStream = FirebaseService.instance.streamOffersForBuyer(_currentUid!);
        }
      }
    } catch (e) {
      // fallback to buyer stream for currentUid or demo
      _currentRole = 'buyer';
      final id = _currentUid ?? 'demo_buyer';
      _offersStream = FirebaseService.instance.streamOffersForBuyer(id);
    } finally {
      if (mounted) setState(() => _loadingRole = false);
    }
  }

  Future<Listing?> _getListing(String listingId) async {
    if (_listingCache.containsKey(listingId)) return _listingCache[listingId];
    try {
      final l = await FirebaseService.instance.getListingById(listingId);
      _listingCache[listingId] = l;
      return l;
    } catch (_) {
      return null;
    }
  }

  Future<void> _acceptOffer(Offer offer) async {
    try {
      await FirebaseService.instance.respondOffer(offerId: offer.id, action: Offer.STATUS_ACCEPTED);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer accepted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Accept failed: $e')));
    }
  }

  Future<void> _rejectOffer(Offer offer) async {
    try {
      await FirebaseService.instance.respondOffer(offerId: offer.id, action: Offer.STATUS_REJECTED);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer rejected')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reject failed: $e')));
    }
  }

  Future<void> _counterOffer(Offer offer) async {
    final controller = TextEditingController(text: offer.offerPrice.toStringAsFixed(0));
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

    if (result == null) return;
    try {
      await FirebaseService.instance.respondOffer(offerId: offer.id, action: Offer.STATUS_COUNTERED, counterPrice: result);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Counter sent')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Counter failed: $e')));
    }
  }

  Future<void> _cancelOfferAsBuyer(Offer offer) async {
    // Buyer cancels by marking rejected (or add a separate CANCELLED status if defined)
    try {
      await FirebaseService.instance.respondOffer(offerId: offer.id, action: Offer.STATUS_REJECTED);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer cancelled')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
    }
  }

  Widget _buildOfferTile(Offer offer) {
    return FutureBuilder<Listing?>(
      future: _getListing(offer.listingId),
      builder: (context, snap) {
        final listing = snap.data;
        final crop = listing?.crop ?? offer.listingId;
        final subtitle = listing != null ? '${listing.quantity.toStringAsFixed(0)} ${listing.unit} • ₹${listing.pricePerUnit.toStringAsFixed(0)}/${listing.unit}' : 'Listing: ${offer.listingId}';
        return Card(
          child: ListTile(
            title: Text('₹${offer.offerPrice.toStringAsFixed(0)} • ${offer.quantity.toStringAsFixed(0)} ${listing?.unit ?? 'unit'}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                if (offer.message != null && offer.message!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(offer.message!, style: const TextStyle(fontSize: 13)),
                ],
                const SizedBox(height: 6),
                Text('Status: ${offer.status}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            isThreeLine: true,
            trailing: _buildTileActions(offer),
          ),
        );
      },
    );
  }

  Widget _buildTileActions(Offer offer) {
    if (_currentRole == 'farmer') {
      // Farmer actions for pending offers only
      if (offer.status == Offer.STATUS_PENDING || offer.status == Offer.STATUS_COUNTERED) {
        return PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'accept') {
              await _acceptOffer(offer);
            } else if (action == 'reject') {
              await _rejectOffer(offer);
            } else if (action == 'counter') {
              await _counterOffer(offer);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'accept', child: Text('Accept')),
            const PopupMenuItem(value: 'counter', child: Text('Counter')),
            const PopupMenuItem(value: 'reject', child: Text('Reject')),
          ],
          icon: const Icon(Icons.more_vert),
        );
      } else {
        return const Icon(Icons.info_outline);
      }
    } else {
      // Buyer: allow cancel if pending
      if (offer.status == Offer.STATUS_PENDING || offer.status == Offer.STATUS_COUNTERED) {
        return IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel offer',
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Cancel offer'),
                content: const Text('Do you want to cancel this offer?'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
                  TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
                ],
              ),
            );
            if (ok == true) await _cancelOfferAsBuyer(offer);
          },
        );
      } else {
        return const Icon(Icons.check_circle_outline);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRole) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Offers'),
          centerTitle: true,
        ),
        body: SafeArea(child: child
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offers'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Offer>>(
        stream: _offersStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error loading offers: ${snap.error}'));
          }
          final offers = snap.data ?? [];
          if (offers.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.black26),
                const SizedBox(height: 12),
                Text(_currentRole == 'farmer' ? 'No pending offers for your listings' : 'You have not made any offers yet', style: const TextStyle(color: Colors.black54)),
              ]),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // stream is realtime; just wait briefly to simulate refresh
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final o = offers[index];
                return _buildOfferTile(o);
              },
            ),
          );
        },
      ),
    );
  }
}
