// lib/screens/transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/transaction.dart';
import '../models/user.dart';
import '../services/firebase_service.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({Key? key}) : super(key: key);

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final FirebaseService _fs = FirebaseService.instance;

  AppUser? _me;
  String? _uid;
  String? _role;

  @override
  void initState() {
    super.initState();
    _uid = _fs.currentFirebaseUser?.uid;
    if (_uid != null) {
      // load user profile once
      _fs.getUserById(_uid!).then((u) {
        if (mounted) {
          setState(() {
            _me = u;
            _role = u?.role;
          });
        }
      }).catchError((e) {
        // ignore for now; UI will handle nulls
      });
    }
  }

  Stream<List<TransactionModel>> _myTransactionsStream() {
    if (_uid == null) {
      // empty stream when not logged in
      return Stream.value(<TransactionModel>[]);
    }
    if (_role == AppUser.ROLE_FARMER) {
      // farmer is the seller
      return _fs.streamTransactionsForSeller(_uid!);
    } else {
      // buyer (default)
      return _fs.streamTransactionsForBuyer(_uid!);
    }
  }

  Future<void> _updateTransactionStatus(String txId, String status) async {
    try {
      // Prefer calling a dedicated service method (recommended).
      await _fs.updateTransactionStatus(txId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction updated: $status')),
      );
    } catch (e) {
      // If the service doesn't provide updateTransactionStatus, you can
      // implement a direct Firestore update inside FirebaseService (recommended).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update transaction: $e')),
        );
      }
    }
  }

  Future<AppUser?> _getUser(String uid) async {
    try {
      return await _fs.getUserById(uid);
    } catch (_) {
      return null;
    }
  }

  Widget _buildActionButtons(TransactionModel tx) {
    final isSeller = (_role == AppUser.ROLE_FARMER && _uid == tx.sellerId);
    final isBuyer = (_role == AppUser.ROLE_BUYER && _uid == tx.buyerId);

    // Seller can mark completed or cancel when confirmed
    if (isSeller && tx.status == TransactionModel.STATUS_CONFIRMED) {
      return Row(
        children: [
          ElevatedButton(
            onPressed: () async {
              final ok = await _confirmDialog('Mark transaction completed?');
              if (ok == true) {
                await _updateTransactionStatus(tx.id, TransactionModel.STATUS_COMPLETED);
              }
            },
            child: const Text('Mark Completed'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () async {
              final ok = await _confirmDialog('Cancel this transaction?');
              if (ok == true) {
                await _updateTransactionStatus(tx.id, TransactionModel.STATUS_CANCELLED);
              }
            },
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    // Buyer can show a simple status / request support
    if (isBuyer) {
      if (tx.status == TransactionModel.STATUS_CONFIRMED) {
        return ElevatedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.hourglass_top),
          label: const Text('Awaiting seller'),
        );
      } else if (tx.status == TransactionModel.STATUS_COMPLETED) {
        return const Text('Completed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
      } else if (tx.status == TransactionModel.STATUS_CANCELLED) {
        return const Text('Cancelled', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
      }
    }

    // default fallback
    return Text(tx.status);
  }

  Future<bool?> _confirmDialog(String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
        ],
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open phone app')));
    }
  }

  Future<void> _launchWhatsApp(String phone, {String? message}) async {
    // WhatsApp link: use international format if available; callers should pass proper phone numbers.
    final encodedMessage = Uri.encodeComponent(message ?? '');
    final uri = Uri.parse('https://wa.me/$phone?text=$encodedMessage');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open WhatsApp')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _uid == null
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Not signed in. Please login to see your transactions.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        )
            : StreamBuilder<List<TransactionModel>>(
          stream: _myTransactionsStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final txs = snap.data ?? [];
            if (txs.isEmpty) {
              return _emptyState();
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: txs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tx = txs[index];
                return _buildTransactionCard(tx);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/illustrations/empty_transactions.png', height: 140),
            const SizedBox(height: 12),
            const Text('No transactions yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Your completed or confirmed transactions will appear here.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(TransactionModel tx) {
    // show main tx info and fetch counterparty info
    final isSeller = (_role == AppUser.ROLE_FARMER && _uid == tx.sellerId);
    final otherUid = isSeller ? tx.buyerId : tx.sellerId;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // heading row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transaction: ${tx.id}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      const SizedBox(height: 6),
                      Text('${tx.quantity.toStringAsFixed(0)} kg • ₹${tx.finalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('Status: ${tx.status}', style: TextStyle(fontSize: 13, color: tx.status == TransactionModel.STATUS_COMPLETED ? Colors.green : Colors.orange)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatDate(tx.createdAt), style: const TextStyle(fontSize: 12, color: Colors.black45)),
                    const SizedBox(height: 8),
                    // contact icons will be displayed once counterparty loaded
                  ],
                )
              ],
            ),
            const Divider(height: 16),
            FutureBuilder<AppUser?>(
              future: _getUser(otherUid),
              builder: (context, snap) {
                final u = snap.data;
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                }
                if (u == null) {
                  return const Text('Participant info not found', style: TextStyle(color: Colors.black54));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${u.name}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Phone: ${u.phone}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _launchPhone(u.phone),
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _launchWhatsApp(u.phone, message: 'Hi, regarding transaction ${tx.id}'),
                          icon: const FaIcon(FontAwesomeIcons.whatsapp),
                          label: const Text('WhatsApp'),
                        ),
                        const Spacer(),
                        _buildActionButtons(tx),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
