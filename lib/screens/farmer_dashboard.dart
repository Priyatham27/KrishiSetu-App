// lib/screens/farmer_dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/listing.dart';
import '../services/firebase_service.dart';
import 'add_listing.dart';
import 'offers_screen.dart'; // create this file next (we referenced it earlier)
import 'buyer_feed.dart'; // for ListingDetailModal if you want to reuse it

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({Key? key}) : super(key: key);

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? 'demo_seller';

  Future<void> _confirmDeleteListing(BuildContext context, Listing listing) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete listing'),
        content: Text('Are you sure you want to delete "${listing.crop}" listing? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes == true) {
      try {
        await FirebaseService.instance.deleteListing(listing.id);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing deleted')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  void _openOffersScreen(Listing listing) {
    // Navigate to offers screen (farmer view). Create this screen file if not present.
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => OffersScreen(listing: listing)));
  }

  void _openEditListing(Listing listing) {
    // Reuse AddListingScreen for edit by passing listing (you'll need to adapt AddListingScreen to accept optional Listing)
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddListingScreen(/* you can pass listing for edit */)));
  }

  Future<void> _openAddListing() async {
    // Navigate to AddListingScreen and refresh after returning if needed
    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddListingScreen()));
    if (result == true) {
      // optional: show snackbar or handle UI refresh; the stream will update automatically
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing added')));
    }
  }

  Widget _buildListingTile(Listing listing) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        leading: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: Colors.green[50],
            image: listing.imageUrl.isNotEmpty ? DecorationImage(image: NetworkImage(listing.imageUrl), fit: BoxFit.cover) : null,
            border: Border.all(color: Colors.green.shade100),
          ),
          child: listing.imageUrl.isEmpty ? const Icon(Icons.agriculture, color: Colors.green, size: 36) : null,
        ),
        title: Text(listing.crop, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${listing.quantity.toStringAsFixed(0)} ${listing.unit} • ${listing.location}'),
            const SizedBox(height: 6),
            Text('₹${listing.pricePerUnit.toStringAsFixed(0)} / ${listing.unit}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'offers') {
              _openOffersScreen(listing);
            } else if (value == 'edit') {
              _openEditListing(listing);
            } else if (value == 'delete') {
              await _confirmDeleteListing(context, listing);
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'offers', child: Text('View Offers')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'View as buyer',
            icon: const Icon(Icons.storefront),
            onPressed: () {
              // quick switch to buyer feed for testing
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BuyerFeedScreen()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Listing>>(
          stream: FirebaseService.instance.streamListingsForUser(_currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final listings = snapshot.data ?? [];
            if (listings.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.green),
                      const SizedBox(height: 12),
                      const Text('No listings yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text('Tap the + button to add your first listing and start receiving offers.'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(onPressed: _openAddListing, icon: const Icon(Icons.add), label: const Text('Add Listing')),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                // stream is real-time; just wait a bit for UI feedback
                await Future.delayed(const Duration(milliseconds: 400));
              },
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                itemCount: listings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildListingTile(listings[index]),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddListing,
        label: const Text('Add Listing'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
