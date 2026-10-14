import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/order_service.dart';
import '../theme/tera_farm_theme.dart';
import '../widgets/order_chat_sheet.dart';
import '../widgets/tera_farm_scaffold.dart';

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return TeraFarmScaffold(
        mode: TeraFarmScaffoldMode.inner,
        title: 'My Orders',
        body: const Center(child: Text('Please sign in')),
      );
    }

    // Avoid composite index requirement: filter client-side after buyerId query.
    final orderStream = FirebaseFirestore.instance
        .collection('orders')
        .where('buyerId', isEqualTo: user.uid)
        .snapshots();

    return TeraFarmScaffold(
      mode: TeraFarmScaffoldMode.inner,
      title: 'My Orders',
      backgroundColor: TeraFarmColors.surface,
      body: StreamBuilder<QuerySnapshot>(
        stream: orderStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _empty('No orders yet');
          }

          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final ad = _date(a.data() as Map<String, dynamic>);
              final bd = _date(b.data() as Map<String, dynamic>);
              return bd.compareTo(ad);
            });

          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            if (data['status'] == OrderStatuses.awaitingPayment) {
              OrderService.instance.cancelIfUpiExpired(d.id);
            }
          }

          final active = docs.where((d) {
            final s = ((d.data() as Map)['status'] ?? '').toString();
            return OrderStatuses.activeBuyer.contains(s);
          }).toList();
          final history = docs.where((d) {
            final s = ((d.data() as Map)['status'] ?? '').toString();
            return OrderStatuses.history.contains(s);
          }).toList();

          if (active.isEmpty && history.isEmpty) {
            return _empty('No orders yet');
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Active',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: TeraFarmColors.primaryDark)),
              const SizedBox(height: 8),
              if (active.isEmpty)
                Text('No active orders',
                    style: TextStyle(color: Colors.grey.shade600))
              else
                for (final doc in active) _BuyerOrderCard(doc: doc),
              const SizedBox(height: 20),
              const Text('History',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: TeraFarmColors.primaryDark)),
              const SizedBox(height: 8),
              if (history.isEmpty)
                Text('No past orders',
                    style: TextStyle(color: Colors.grey.shade600))
              else
                for (final doc in history) _BuyerOrderCard(doc: doc),
            ],
          );
        },
      ),
    );
  }

  static DateTime _date(Map<String, dynamic> data) {
    final raw = data['orderDate'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime(2000);
    final c = data['createdAt'];
    if (c is Timestamp) return c.toDate();
    return DateTime(2000);
  }

  Widget _empty(String text) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(text,
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

class _BuyerOrderCard extends StatelessWidget {
  const _BuyerOrderCard({required this.doc});
  final DocumentSnapshot doc;

  Future<void> _payAgain(BuildContext context, Map<String, dynamic> data) async {
    final upi = (data['sellerUpiId'] ?? '').toString();
    final amount = (data['totalPayable'] ?? data['itemTotal'] ?? 0).toString();
    final txn = (data['transactionRef'] ?? doc.id).toString();
    if (upi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seller UPI missing')),
      );
      return;
    }
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upi,
        'pn': 'TeraFarm Seller',
        'am': amount,
        'cu': 'INR',
        'tn': 'TeraFarm order $txn',
        'tr': txn,
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    final claimed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('UPI payment'),
        content: const Text(
          'After paying, tap I paid. The farmer must still confirm before the order proceeds.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Close')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('I paid')),
        ],
      ),
    );
    if (claimed == true) {
      await OrderService.instance.buyerClaimUpiPaid(doc.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waiting for farmer to confirm payment'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final status = (data['status'] ?? '').toString();
    final paymentStatus = (data['paymentStatus'] ?? '').toString();
    final paymentMethod = (data['paymentMethod'] ?? '').toString();
    final total = data['totalPayable'] ?? data['itemTotal'] ?? 0;
    final cart = (data['cartItems'] as List?) ?? const [];
    final sellerId = (data['sellerId'] ?? '').toString();
    final buyerHandover = data['buyerHandoverConfirmed'] == true;
    final sellerHandover = data['sellerHandoverConfirmed'] == true;

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('farms')
          .where('sellerId', isEqualTo: sellerId)
          .limit(1)
          .get(),
      builder: (context, farmSnap) {
        final farmName = farmSnap.hasData && farmSnap.data!.docs.isNotEmpty
            ? (farmSnap.data!.docs.first.data()
                    as Map<String, dynamic>)['farmName']
                    ?.toString() ??
                'Farm'
            : 'Farm';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(farmName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('Order #${doc.id.substring(0, 8)}…',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  _chip(OrderService.statusLabel(status)),
                ],
              ),
              const SizedBox(height: 8),
              Text('₹$total · Pickup',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: TeraFarmColors.farmerGreenDark)),
              Text(
                paymentMethod == PaymentMethods.cod
                    ? (paymentStatus == PaymentStatuses.paid
                        ? 'COD paid at pickup'
                        : 'Cash on Pickup')
                    : (paymentStatus == PaymentStatuses.paid
                        ? 'UPI paid'
                        : 'UPI awaiting farmer confirm'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              ...cart.take(3).map((item) {
                if (item is! Map) return const SizedBox.shrink();
                return Text(
                  '• ${item['name'] ?? ''} × ${item['quantity'] ?? 1}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                );
              }),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => showOrderChatSheet(
                      context,
                      orderId: doc.id,
                      title: 'Chat · $farmName',
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Message'),
                  ),
                  if (status == OrderStatuses.awaitingPayment ||
                      (paymentMethod == PaymentMethods.upi &&
                          paymentStatus == PaymentStatuses.awaitingPayment))
                    FilledButton.icon(
                      onPressed: () => _payAgain(context, data),
                      icon: const Icon(Icons.currency_rupee, size: 18),
                      label: const Text('Pay UPI'),
                      style: FilledButton.styleFrom(
                          backgroundColor: TeraFarmColors.primary),
                    ),
                  if (status == OrderStatuses.readyForPickup)
                    FilledButton(
                      onPressed: buyerHandover
                          ? null
                          : () async {
                              try {
                                await OrderService.instance.confirmHandover(
                                  orderId: doc.id,
                                  asBuyer: true,
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                }
                              }
                            },
                      style: FilledButton.styleFrom(
                          backgroundColor: TeraFarmColors.farmerGreen),
                      child: Text(buyerHandover
                          ? (sellerHandover
                              ? 'Completed'
                              : 'Waiting for farmer')
                          : 'Confirm I received produce'),
                    ),
                  if (status == OrderStatuses.readyForPickup ||
                      status == OrderStatuses.accepted)
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Pickup code'),
                            content: SizedBox(
                              width: 200,
                              height: 220,
                              child: QrImageView(
                                data: doc.id,
                                size: 180,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: const Text('Show QR'),
                    ),
                  if (status == OrderStatuses.awaitingPayment ||
                      status == OrderStatuses.pending)
                    TextButton(
                      onPressed: () async {
                        try {
                          await OrderService.instance
                              .cancel(doc.id, asSeller: false);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                      child: Text('Cancel',
                          style: TextStyle(color: Colors.red.shade700)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TeraFarmColors.sage,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: TeraFarmColors.primaryDark)),
    );
  }
}
