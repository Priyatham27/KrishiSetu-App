// lib/widgets/offer_modal.dart
//
// A reusable modal bottom sheet for creating an offer on a listing.
// Returns an Offer object to the caller when the user submits.
//
// Usage:
//   final offer = await showOfferModal(context, listing: listing);
//   if (offer != null) { /* send to Firestore */ }

import 'package:flutter/material.dart';
import '../models/listing.dart';
import '../models/offer.dart';

Future<Offer?> showOfferModal(BuildContext context, {required Listing listing}) {
  return showModalBottomSheet<Offer>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return _OfferModalContent(listing: listing);
    },
  );
}

class _OfferModalContent extends StatefulWidget {
  final Listing listing;
  const _OfferModalContent({required this.listing});

  @override
  State<_OfferModalContent> createState() => _OfferModalContentState();
}

class _OfferModalContentState extends State<_OfferModalContent> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();

  bool submitting = false;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "Make an Offer",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.listing.crop,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 25),

              // PRICE INPUT
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Price you want to offer (per ${widget.listing.unit})",
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Enter price";
                  final num? parsed = num.tryParse(v);
                  if (parsed == null || parsed <= 0) return "Enter valid price";
                  return null;
                },
              ),

              const SizedBox(height: 15),

              // QTY INPUT
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Quantity you want (${widget.listing.unit})",
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Enter quantity";
                  final num? parsed = num.tryParse(v);
                  if (parsed == null || parsed <= 0) return "Enter valid quantity";
                  if (parsed > widget.listing.quantity) {
                    return "Only ${widget.listing.quantity} available";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 30),

              // BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.green,
                  ),
                  child: submitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    "Submit Offer",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => submitting = true);

    final offer = Offer(
      id: '', // Firestore will generate later
      listingId: widget.listing.id,
      buyerId: "TEMP_BUYER", // Replace with actual authenticated user ID
      offeredPrice: double.parse(_priceCtrl.text.trim()),
      quantity: double.parse(_qtyCtrl.text.trim()),
      timestamp: DateTime.now(), createdAt: null, 
    );

    Navigator.pop(context, offer);
  }
}
