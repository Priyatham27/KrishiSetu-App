// lib/services/firebase_service.dart
//
// Fully functional FirebaseService for KrishiSetu.
// - Firestore collections: users, listings, offers, transactions
// - Firebase Storage: uploads listing images to 'listings/' folder
// - Auth helpers (anonymous sign-in) and common CRUD wrappers
//
// Notes:
//  - Firebase must be initialized (Firebase.initializeApp) before using this service.
//  - This is written for null-safety and typical firebase_* plugin versions.
//  - Adjust field names/types in models if you change them elsewhere.

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/listing.dart';
import '../models/offer.dart';
import '../models/transaction.dart';
import '../models/user.dart';

class FirebaseService {
  FirebaseService._privateConstructor();
  static final FirebaseService instance = FirebaseService._privateConstructor();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection names
  static const String COLLECTION_USERS = 'users';
  static const String COLLECTION_LISTINGS = 'listings';
  static const String COLLECTION_OFFERS = 'offers';
  static const String COLLECTION_TRANSACTIONS = 'transactions';

  // ---------------------------
  // Auth helpers
  // ---------------------------

  /// Sign in anonymously (useful for demo mode)
  Future<UserCredential> signInAnonymously() async {
    return _auth.signInAnonymously();
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Current Firebase user (nullable)
  User? get currentFirebaseUser => _auth.currentUser;

  // ---------------------------
  // Users
  // ---------------------------

  /// Create or update user profile in `users/{uid}`.
  Future<void> createOrUpdateUserProfile(AppUser user) async {
    final docRef = _db.collection(COLLECTION_USERS).doc(user.id);
    await docRef.set(user.toMap(), SetOptions(merge: true));
  }

  /// Get AppUser by uid (returns null if not exists)
  Future<AppUser?> getUserById(String uid) async {
    final doc = await _db.collection(COLLECTION_USERS).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.id, doc.data()! as Map<String, dynamic>);
  }

  /// Stream of AppUser changes
  Stream<AppUser?> streamUserById(String uid) {
    return _db.collection(COLLECTION_USERS).doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AppUser.fromMap(snap.id, snap.data()! as Map<String, dynamic>);
    });
  }

  // ---------------------------
  // Storage: Upload image for listing
  // ---------------------------

  /// Upload a listing image to Storage under 'listings/{listingId}.{ext}'
  /// Calls onProgress with 0.0 - 1.0 while uploading.
  /// Returns the download URL string on success.
  Future<String> uploadListingImage(
      File file,
      String listingId, {
        required void Function(double progress) onProgress,
      }) async {
    final ext = file.path.split('.').last;
    final ref = _storage.ref().child('listings/$listingId.$ext');

    final uploadTask = ref.putFile(file);

    final completer = Completer<String>();

    uploadTask.snapshotEvents.listen((snapshot) {
      final bytesTransferred = snapshot.bytesTransferred;
      final totalBytes = snapshot.totalBytes == 0 ? 1 : snapshot.totalBytes;
      final progress = bytesTransferred / totalBytes;
      try {
        onProgress(progress.clamp(0.0, 1.0));
      } catch (_) {}
    }, onError: (err) {
      if (!completer.isCompleted) completer.completeError(err);
    });

    try {
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (!completer.isCompleted) completer.complete(downloadUrl);
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }

    return completer.future;
  }

  // ---------------------------
  // Listings CRUD & queries
  // ---------------------------

  /// Add a listing document. Returns created doc id.
  Future<String> addListing(Listing listing) async {
    final data = listing.toMap();
    final docRef = await _db.collection(COLLECTION_LISTINGS).add(data);
    return docRef.id;
  }

  /// Update a listing by id
  Future<void> updateListing(String listingId, Map<String, dynamic> updates) async {
    await _db.collection(COLLECTION_LISTINGS).doc(listingId).update(updates);
  }

  /// Delete listing (and its image in Storage if present)
  Future<void> deleteListing(String listingId) async {
    final listingRef = _db.collection(COLLECTION_LISTINGS).doc(listingId);
    final snap = await listingRef.get();
    if (!snap.exists || snap.data() == null) return;

    final listing = Listing.fromMap(snap.id, snap.data()! as Map<String, dynamic>);
    if (listing.imageUrl.isNotEmpty) {
      try {
        final ref = _storage.refFromURL(listing.imageUrl);
        await ref.delete();
      } catch (e) {
        // ignore storage deletion errors for now
      }
    }
    await listingRef.delete();
  }

  /// Get single listing by id (nullable)
  Future<Listing?> getListingById(String listingId) async {
    final doc = await _db.collection(COLLECTION_LISTINGS).doc(listingId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Listing.fromMap(doc.id, doc.data()! as Map<String, dynamic>);
  }

  /// Stream of open listings (status == open), ordered desc by createdAt
  Stream<List<Listing>> streamOpenListings() {
    return _db
        .collection(COLLECTION_LISTINGS)
        .where('status', isEqualTo: Listing.STATUS_OPEN)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => Listing.fromMap(d.id, d.data()! as Map<String, dynamic>))
        .toList());
  }

  /// Query listings with optional filters (crop, price range). One-time fetch.
  Future<List<Listing>> getListings({
    String? crop,
    double? minPrice,
    double? maxPrice,
    int limit = 50,
  }) async {
    Query query = _db.collection(COLLECTION_LISTINGS).where('status', isEqualTo: Listing.STATUS_OPEN);

    if (crop != null && crop.trim().isNotEmpty) {
      // For simple exact-match. For case-insensitive search use additional fields or client-side filter.
      query = query.where('crop', isEqualTo: crop.trim());
    }

    if (minPrice != null) {
      query = query.where('pricePerUnit', isGreaterThanOrEqualTo: minPrice);
    }
    if (maxPrice != null) {
      query = query.where('pricePerUnit', isLessThanOrEqualTo: maxPrice);
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);
    final snap = await query.get();
    return snap.docs.map((d) => Listing.fromMap(d.id, d.data()! as Map<String, dynamic>)).toList();
  }

  /// Stream listings for a specific farmer (by userId)
  Stream<List<Listing>> streamListingsForUser(String userId) {
    return _db
        .collection(COLLECTION_LISTINGS)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => Listing.fromMap(d.id, d.data()! as Map<String, dynamic>))
        .toList());
  }

  // ---------------------------
  // Offers
  // ---------------------------

  /// Make an offer (create offers doc). Returns doc id.
  Future<String> makeOffer(Offer offer) async {
    final data = offer.toMap();
    final docRef = await _db.collection(COLLECTION_OFFERS).add(data);
    return docRef.id;
  }

  /// Update offer by id
  Future<void> updateOffer(String offerId, Map<String, dynamic> updates) async {
    await _db.collection(COLLECTION_OFFERS).doc(offerId).update(updates);
  }

  /// Stream of offers for a listing
  Stream<List<Offer>> streamOffersForListing(String listingId) {
    return _db
        .collection(COLLECTION_OFFERS)
        .where('listingId', isEqualTo: listingId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Offer.fromMap(d.id, d.data()! as Map<String, dynamic>)).toList());
  }

  /// Stream of offers for a buyer
  Stream<List<Offer>> streamOffersForBuyer(String buyerId) {
    return _db
        .collection(COLLECTION_OFFERS)
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Offer.fromMap(d.id, d.data()! as Map<String, dynamic>)).toList());
  }

  /// Stream of pending offers that belong to listings owned by a farmer (farmerId)
  /// This implementation listens to farmer's listings and queries offers for those listing ids.
  Stream<List<Offer>> streamPendingOffersForFarmer(String farmerId) {
    final listingsStream = _db
        .collection(COLLECTION_LISTINGS)
        .where('userId', isEqualTo: farmerId)
        .snapshots();

    final controller = StreamController<List<Offer>>.broadcast();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? listingsSub;

    listingsSub = listingsStream.listen((listingSnap) async {
      final listingIds = listingSnap.docs.map((d) => d.id).toList();
      if (listingIds.isEmpty) {
        controller.add([]);
        return;
      }

      // Firestore whereIn supports up to 10 items per query – chunk if needed.
      const int chunkSize = 10;
      final chunks = <List<String>>[];
      for (var i = 0; i < listingIds.length; i += chunkSize) {
        chunks.add(listingIds.sublist(i, i + chunkSize > listingIds.length ? listingIds.length : i + chunkSize));
      }

      final allOffers = <Offer>[];
      for (final chunk in chunks) {
        final snap = await _db
            .collection(COLLECTION_OFFERS)
            .where('listingId', whereIn: chunk)
            .where('status', isEqualTo: Offer.STATUS_PENDING)
            .orderBy('createdAt', descending: true)
            .get();

        allOffers.addAll(snap.docs.map((d) => Offer.fromMap(d.id, d.data()! as Map<String, dynamic>)));
      }

      controller.add(allOffers);
    }, onError: (err) {
      controller.addError(err);
    });

    controller.onCancel = () {
      listingsSub?.cancel();
    };

    return controller.stream;
  }

  /// Respond to an offer: accept / counter / reject
  /// If action == Offer.STATUS_ACCEPTED, creates a Transaction doc and optionally marks listing sold.
  Future<void> respondOffer({
    required String offerId,
    required String action, // Offer.STATUS_*
    double? counterPrice,
  }) async {
    final offerRef = _db.collection(COLLECTION_OFFERS).doc(offerId);
    final offerSnap = await offerRef.get();
    if (!offerSnap.exists || offerSnap.data() == null) {
      throw Exception('Offer not found');
    }

    final offer = Offer.fromMap(offerSnap.id, offerSnap.data()! as Map<String, dynamic>);

    final updates = <String, dynamic>{
      'status': action,
    };
    if (counterPrice != null) updates['counterPrice'] = counterPrice;

    await offerRef.update(updates);

    if (action == Offer.STATUS_ACCEPTED) {
      // Create transaction
      final listingSnap = await _db.collection(COLLECTION_LISTINGS).doc(offer.listingId).get();
      if (!listingSnap.exists || listingSnap.data() == null) {
        throw Exception('Listing not found for transaction creation');
      }
      final listing = Listing.fromMap(listingSnap.id, listingSnap.data()! as Map<String, dynamic>);
      final finalPrice = counterPrice ?? offer.offerPrice;

      await createTransactionFromOffer(offer: offer, listing: listing, finalPrice: finalPrice);

      // Mark listing as sold (simple approach)
      await _db.collection(COLLECTION_LISTINGS).doc(listing.id).update({'status': Listing.STATUS_SOLD});
    }
  }

  // ---------------------------
  // Transactions
  // ---------------------------

  /// Create a transaction doc from an accepted offer.
  Future<String> createTransactionFromOffer({
    required Offer offer,
    required Listing listing,
    required double finalPrice,
  }) async {
    final totalAmount = finalPrice * offer.quantity;
    final tx = TransactionModel(
      id: '',
      offerId: offer.id,
      listingId: listing.id,
      buyerId: offer.buyerId,
      farmerId: listing.userId,
      finalPrice: finalPrice,
      quantity: offer.quantity,
      totalAmount: totalAmount,
      status: TransactionModel.STATUS_SUCCESS,
      createdAt: DateTime.now(),
    );

    final docRef = await _db.collection(COLLECTION_TRANSACTIONS).add(tx.toMap());
    return docRef.id;
  }

  /// Stream transactions for a buyer
  Stream<List<TransactionModel>> streamTransactionsForBuyer(String buyerId) {
    return _db
        .collection(COLLECTION_TRANSACTIONS)
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromMap(d.id, d.data()! as Map<String, dynamic>)).toList());
  }

  /// Stream transactions for a seller (farmer)
  Stream<List<TransactionModel>> streamTransactionsForSeller(String sellerId) {
    return _db
        .collection(COLLECTION_TRANSACTIONS)
        .where('farmerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromMap(d.id, d.data()! as Map<String, dynamic>)).toList());
  }

  // ---------------------------
  // Utility helpers
  // ---------------------------

  /// Seed demo user (create user doc). Does not create Firebase Auth user.
  Future<void> seedDemoUser(AppUser user) async {
    final ref = _db.collection(COLLECTION_USERS).doc(user.id);
    await ref.set(user.toMap());
  }

  /// Seed sample listings (helpful in demo mode)
  Future<void> seedDemoListings(List<Listing> listings) async {
    final batch = _db.batch();
    for (final l in listings) {
      final doc = _db.collection(COLLECTION_LISTINGS).doc();
      batch.set(doc, l.toMap());
    }
    await batch.commit();
  }

  /// Helper: fetch phone (if stored) for a user id (returns null if not found)
  Future<String?> getPhoneForUser(String uid) async {
    final u = await getUserById(uid);
    return u?.phone;
  }
}
