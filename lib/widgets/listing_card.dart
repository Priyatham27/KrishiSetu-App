// lib/widgets/listing_card.dart
//
// Reusable ListingCard widget for KrishiSetu.
// Shows thumbnail, crop, qty, price and action buttons (Make Offer, Call, WhatsApp).
// Designed mobile-first with large touch targets and simple styling.
//
// Usage:
//   ListingCard(
//     listing: listing,
//     onTap: () => ...,           // optional card tap
//     onMakeOffer: () => ...,     // optional make offer action
//     onCall: (phone) => ...,     // optional call action (phone string)
//     onWhatsapp: (phone) => ..., // optional whatsapp action (phone string)
//   );
//
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/listing.dart';

typedef PhoneCallback = void Function(String phone);

class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback? onTap;
  final VoidCallback? onMakeOffer;
  final PhoneCallback? onCall;
  final PhoneCallback? onWhatsapp;

  const ListingCard({
    Key? key,
    required this.listing,
    this.onTap,
    this.onMakeOffer,
    this.onCall,
    this.onWhatsapp,
  }) : super(key: key);

  String _priceText() => '₹${listing.pricePerUnit.toStringAsFixed(listing.pricePerUnit % 1 == 0 ? 0 : 2)} / ${listing.unit}';

  // Fallback phone action that attempts to read the listing.userId as a phone when provided by developer.
  // In most apps, you should fetch the phone from users collection before calling the action.
  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    // Normalize phone: remove spaces
    final normalized = phone.replaceAll(' ', '');
    final uri = Uri.parse('https://wa.me/$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = listing.imageUrl.isNotEmpty
        ? ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        listing.imageUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 100,
            height: 100,
            alignment: Alignment.center,
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                  : null,
              strokeWidth: 2,
            ),
          );
        },
      ),
    )
        : _placeholder();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Row(
            children: [
              // thumbnail
              thumbnail,
              const SizedBox(width: 12),
              // details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Crop + badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            listing.crop,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade100),
                          ),
                          child: Text(
                            listing.status.toUpperCase(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: listing.status == Listing.STATUS_OPEN ? Colors.green.shade800 : Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // qty & location
                    Text(
                      '${listing.quantity.toStringAsFixed(listing.quantity % 1 == 0 ? 0 : 2)} ${listing.unit} • ${listing.location.isNotEmpty ? listing.location : 'Location not set'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    // price
                    Text(
                      _priceText(),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    // actions row
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: onMakeOffer,
                          icon: const Icon(Icons.gavel, size: 18),
                          label: const Text('Make Offer'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(110, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            // if caller provided onCall, use it; else try to launch directly using listing.userId (not ideal)
                            if (onCall != null) {
                              onCall!(listing.userId);
                            } else {
                              // fallback attempt - expect listing.userId to be phone
                              _launchPhone(listing.userId);
                            }
                          },
                          tooltip: 'Call',
                          icon: const Icon(Icons.call),
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () {
                            if (onWhatsapp != null) {
                              onWhatsapp!(listing.userId);
                            } else {
                              _launchWhatsApp(listing.userId);
                            }
                          },
                          tooltip: 'WhatsApp',
                          icon: const Icon(Icons.message),
                          color: Colors.green.shade700,
                        ),
                        const Spacer(),
                        // small chevron
                        Icon(Icons.chevron_right, color: Colors.grey.shade400),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // simple placeholder widget for missing images
  Widget _placeholder() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Center(
        child: Icon(
          Icons.grass,
          size: 36,
          color: Colors.green.shade700,
        ),
      ),
    );
  }
}
