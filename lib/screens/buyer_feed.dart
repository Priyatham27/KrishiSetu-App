// lib/screens/buyer_feed.dart
//
// Buyer feed screen for KrishiSetu.
// - Realtime feed of open listings from Firestore (FirebaseService.streamOpenListings)
// - Search by crop, filter by price range
// - Tap a listing to open a bottom-sheet detail + make offer form
// - Uses FirebaseAuth to identify buyer (falls back to 'demo_buyer' if not signed in)
// - Minimal, mobile-first UI with large buttons and simple controls
//
// Note: This file expects these project files to exist:
//  - models/listing.dart
//  - models/offer.dart
//  - services/firebase_service.dart
//  - screens/listing_detail.dart (not required because ListingDetailModal is implemented here as a self-contained modal)
//
// If you already have a separate ListingDetailScreen, you can navigate to it instead.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/listing.dart';
import '../models/offer.dart';
import '../services/firebase_service.dart';

class BuyerFeedScreen extends StatefulWidget {
  const BuyerFeedScreen({Key? key}) : super(key: key);

  @override
  State<BuyerFeedScreen> createState() => _BuyerFeedScreenState();
}

class _BuyerFeedScreenState extends State<BuyerFeedScreen> {
  String _searchCrop = '';
  final _searchCtrl = TextEditingController();
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  void _openListingDetail(BuildContext context, Listing listing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 12,
        ),
        child: ListingDetailModal(listing: listing),
      ),
    );
  }

  List<Listing> _applyFilters(List<Listing> items) {
    final crop = _searchCrop.trim().toLowerCase();
    double? minPrice;
    double? maxPrice;

    if (_minPriceCtrl.text.trim().isNotEmpty) {
      minPrice = double.tryParse(_minPriceCtrl.text.trim());
    }
    if (_maxPriceCtrl.text.trim().isNotEmpty) {
      maxPrice = double.tryParse(_maxPriceCtrl.text.trim());
    }

    return items.where((l) {
      if (crop.isNotEmpty && !l.crop.toLowerCase().contains(crop)) return false;
      if (minPrice != null && l.pricePerUnit < minPrice) return false;
      if (maxPrice != null && l.pricePerUnit > maxPrice) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buyer Feed'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search & filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search crop (e.g., Tomato)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.all(12),
                          ),
                          onChanged: (v) => setState(() => _searchCrop = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchCrop = '');
                        },
                        tooltip: 'Clear',
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Min Price (₹)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Max Price (₹)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Filter'),
                      )
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Feed
            Expanded(
              child: StreamBuilder<List<Listing>>(
                stream: FirebaseService.instance.streamOpenListings(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final listings = snapshot.data ?? [];
                  final filtered = _applyFilters(listings);

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No listings found'));
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      // stream is realtime; just brief delay for UI feedback
                      await Future.delayed(const Duration(milliseconds: 400));
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final listing = filtered[index];
                        return GestureDetector(
                          onTap: () => _openListingDetail(context, listing),
                          child: ListingCard(
                            listing: listing,
                            onMakeOffer: () => _openListingDetail(context, listing),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple card to display listing basics. If you already have a ListingCard widget
/// elsewhere in your project, you may replace this with that file.
class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback? onMakeOffer;

  const ListingCard({Key? key, required this.listing, this.onMakeOffer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final priceText = '₹${listing.pricePerUnit.toStringAsFixed(0)} / ${listing.unit}';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // thumbnail
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.green[50],
                image: listing.imageUrl.isNotEmpty
                    ? DecorationImage(image: NetworkImage(listing.imageUrl), fit: BoxFit.cover)
                    : null,
                border: Border.all(color: Colors.green.shade100),
              ),
              child: listing.imageUrl.isEmpty
                  ? const Center(child: Icon(Icons.grass, size: 34, color: Colors.green))
                  : null,
            ),
            const SizedBox(width: 12),
            // details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.crop, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('${listing.quantity.toStringAsFixed(0)} ${listing.unit} • ${listing.location}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(priceText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Column(
              children: [
                ElevatedButton(
                  onPressed: onMakeOffer,
                  child: const Text('Make Offer'),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: () {
                    // quick contact via phone: use listing.userId to fetch phone from users collection if desired
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open listing to contact')));
                  },
                  child: const Icon(Icons.call),
                  style: OutlinedButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(8)),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet showing listing details and allowing buyer to make an offer.
/// This keeps the buyer flow self-contained and demo-friendly.
class ListingDetailModal extends StatefulWidget {
  final Listing listing;
  const ListingDetailModal({Key? key, required this.listing}) : super(key: key);

  @override
  State<ListingDetailModal> createState() => _ListingDetailModalState();
}

class _ListingDetailModalState extends State<ListingDetailModal> {
  final _offerPriceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _offerPriceCtrl.dispose();
    _quantityCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitOffer() async {
    if (_submitting) return;

    final price = double.tryParse(_offerPriceCtrl.text.trim());
    final qty = double.tryParse(_quantityCtrl.text.trim());

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid offer price')));
      return;
    }
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid quantity')));
      return;
    }

    setState(() => _submitting = true);

    try {
      final buyerId = FirebaseAuth.instance.currentUser?.uid ?? 'demo_buyer';
      final offer = Offer(
        id: '',
        listingId: widget.listing.id,
        buyerId: buyerId,
        offerPrice: price,
        quantity: qty,
        status: Offer.STATUS_PENDING,
        createdAt: DateTime.now(),
        counterPrice: null,
        message: _messageCtrl.text.trim().isNotEmpty ? _messageCtrl.text.trim() : null,
      );

      await FirebaseService.instance.makeOffer(offer);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer submitted')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit offer: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // drag handle
            Container(width: 50, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            Text(l.crop, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (l.imageUrl.isNotEmpty)
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(l.imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Qty: ${l.quantity.toStringAsFixed(0)} ${l.unit}'),
                Text('Price: ₹${l.pricePerUnit.toStringAsFixed(0)}/${l.unit}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: Text('Location: ${l.location}')),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // Make offer form
            Align(alignment: Alignment.centerLeft, child: Text('Make an offer', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade800))),
            const SizedBox(height: 8),
            TextField(
              controller: _offerPriceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Offer price (₹/${l.unit})', border: const OutlineInputBorder(), hintText: l.pricePerUnit.toStringAsFixed(0)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Quantity (${l.unit})', border: const OutlineInputBorder(), hintText: l.quantity.toStringAsFixed(0)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Message (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitOffer,
                child: _submitting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit Offer'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
