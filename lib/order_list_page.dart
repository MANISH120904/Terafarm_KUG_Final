import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/order_service.dart';
import 'theme/tera_farm_theme.dart';
import 'widgets/order_chat_sheet.dart';
import 'widgets/tera_farm_scaffold.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({Key? key}) : super(key: key);

  @override
  _OrderListPageState createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sellerId = _auth.currentUser!.uid;

    return TeraFarmScaffold(
      mode: TeraFarmScaffoldMode.inner,
      title: 'Orders',
      backgroundColor: TeraFarmColors.surface,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('orders')
            .where('sellerId', isEqualTo: sellerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No orders yet'));
          }

          final allOrders = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aDate = _orderDate(a.data() as Map<String, dynamic>);
              final bDate = _orderDate(b.data() as Map<String, dynamic>);
              return bDate.compareTo(aDate);
            });

          // Expire unpaid UPI in the background.
          for (final doc in allOrders) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['status'] == OrderStatuses.awaitingPayment) {
              OrderService.instance.cancelIfUpiExpired(doc.id);
            }
          }

          final awaitingUpi = allOrders.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] == OrderStatuses.awaitingPayment ||
                (data['paymentMethod'] == PaymentMethods.upi &&
                    data['paymentStatus'] == PaymentStatuses.awaitingPayment &&
                    data['status'] != OrderStatuses.cancelled);
          }).toList();

          final pending = allOrders.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['status'] == OrderStatuses.pending;
          }).toList();

          final inProgress = allOrders.where((d) {
            final s = (d.data() as Map<String, dynamic>)['status'];
            return s == OrderStatuses.accepted ||
                s == OrderStatuses.readyForPickup;
          }).toList();

          final history = allOrders.where((d) {
            final s = ((d.data() as Map<String, dynamic>)['status'] ?? '')
                .toString();
            return OrderStatuses.history.contains(s);
          }).toList();

          if (allOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No orders yet',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _sectionHeader('Awaiting UPI confirm', awaitingUpi.length),
              const SizedBox(height: 8),
              if (awaitingUpi.isEmpty)
                _emptyHint('No unpaid UPI orders')
              else
                for (final doc in awaitingUpi) _buildOrderCard(doc),
              const SizedBox(height: 18),
              _sectionHeader('New / pending', pending.length),
              const SizedBox(height: 8),
              if (pending.isEmpty)
                _emptyHint('No pending orders')
              else
                for (final doc in pending) _buildOrderCard(doc),
              const SizedBox(height: 18),
              _sectionHeader('In progress', inProgress.length),
              const SizedBox(height: 8),
              if (inProgress.isEmpty)
                _emptyHint('Nothing in progress')
              else
                for (final doc in inProgress) _buildOrderCard(doc),
              const SizedBox(height: 18),
              _sectionHeader('History', history.length),
              const SizedBox(height: 8),
              if (history.isEmpty)
                _emptyHint('No history yet')
              else
                for (final doc in history) _buildOrderCard(doc),
            ],
          );
        },
      ),
    );
  }

  DateTime _orderDate(Map<String, dynamic> data) {
    final raw = data['orderDate'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime(2000);
    final created = data['createdAt'];
    if (created is Timestamp) return created.toDate();
    return DateTime(2000);
  }

  Widget _sectionHeader(String title, int count) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: TeraFarmColors.primaryDark,
            )),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: TeraFarmColors.sage,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('$count',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: TeraFarmColors.primaryDark)),
        ),
      ],
    );
  }

  Widget _emptyHint(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(color: Colors.grey.shade600)),
      );

  Widget _buildOrderCard(DocumentSnapshot orderDoc) {
    final data = orderDoc.data() as Map<String, dynamic>;
    final orderId = orderDoc.id;
    final buyerId = (data['buyerId'] ?? 'unknown').toString();
    final status = (data['status'] ?? '').toString();
    final paymentStatus = (data['paymentStatus'] ?? '').toString();
    final paymentMethod = (data['paymentMethod'] ?? '').toString();
    final total = data['totalPayable'] ?? data['itemTotal'] ?? 0;
    final sellerUpi = (data['sellerUpiId'] ?? '').toString();
    final buyerClaimed = data['buyerPaidClaimedAt'] != null;
    final items = (data['cartItems'] as List?) ?? const [];
    final firstItem = items.isNotEmpty && items.first is Map
        ? Map<String, dynamic>.from(items.first as Map)
        : <String, dynamic>{};
    final productImage = (firstItem['image'] ?? '').toString();

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(buyerId).get(),
      builder: (context, snapshot) {
        String buyerName = 'Buyer';
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          buyerName = (userData?['username'] ??
                  userData?['displayName'] ??
                  userData?['email'] ??
                  'Buyer')
              .toString();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _productImage(productImage),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(buyerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: TeraFarmColors.primaryDark,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          '${items.length} item(s) · ₹$total · Pickup',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: TeraFarmColors.farmerGreenDark,
                          ),
                        ),
                        if (paymentMethod == PaymentMethods.upi &&
                            sellerUpi.isNotEmpty)
                          Text('UPI: $sellerUpi',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade700)),
                        if (buyerClaimed &&
                            paymentStatus == PaymentStatuses.awaitingPayment)
                          Text('Buyer claimed payment — verify in UPI app',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(OrderService.statusLabel(status),
                      _statusColor(status)),
                  _chip(
                    paymentMethod == PaymentMethods.cod
                        ? (paymentStatus == PaymentStatuses.paid
                            ? 'COD paid'
                            : 'COD')
                        : (paymentStatus == PaymentStatuses.paid
                            ? 'UPI paid'
                            : 'UPI unpaid'),
                    paymentStatus == PaymentStatuses.paid
                        ? TeraFarmColors.farmerGreen
                        : Colors.orange.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _actions(
                orderId: orderId,
                status: status,
                paymentStatus: paymentStatus,
                paymentMethod: paymentMethod,
                buyerHandover: data['buyerHandoverConfirmed'] == true,
                sellerHandover: data['sellerHandoverConfirmed'] == true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actions({
    required String orderId,
    required String status,
    required String paymentStatus,
    required String paymentMethod,
    required bool buyerHandover,
    required bool sellerHandover,
  }) {
    final messageBtn = OutlinedButton.icon(
      onPressed: () => showOrderChatSheet(context, orderId: orderId),
      icon: const Icon(Icons.chat_bubble_outline, size: 18),
      label: const Text('Message'),
    );

    if (status == OrderStatuses.awaitingPayment ||
        (paymentMethod == PaymentMethods.upi &&
            paymentStatus == PaymentStatuses.awaitingPayment &&
            status != OrderStatuses.cancelled &&
            status != OrderStatuses.rejected)) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _run(
                      () => OrderService.instance.cancel(orderId, asSeller: true)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700),
                  child: const Text('Cancel unpaid'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _run(() =>
                      OrderService.instance.sellerConfirmUpiReceived(orderId)),
                  style: FilledButton.styleFrom(
                      backgroundColor: TeraFarmColors.primary),
                  child: const Text('Confirm UPI'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: messageBtn),
        ],
      );
    }

    if (status == OrderStatuses.pending) {
      final canAccept = paymentMethod != PaymentMethods.upi ||
          paymentStatus == PaymentStatuses.paid;
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _run(() => OrderService.instance.reject(orderId)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: canAccept
                      ? () =>
                          _run(() => OrderService.instance.accept(orderId))
                      : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: TeraFarmColors.primary),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: messageBtn),
        ],
      );
    }

    if (status == OrderStatuses.accepted) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _run(
                  () => OrderService.instance.markReadyForPickup(orderId)),
              style: FilledButton.styleFrom(
                  backgroundColor: TeraFarmColors.farmerGreen),
              child: const Text('Mark ready for pickup'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _run(() =>
                      OrderService.instance.cancel(orderId, asSeller: true)),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: messageBtn),
            ],
          ),
        ],
      );
    }

    if (status == OrderStatuses.readyForPickup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (buyerHandover)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Buyer confirmed receipt',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600)),
            ),
          FilledButton(
            onPressed: sellerHandover
                ? null
                : () => _run(() => OrderService.instance
                    .confirmHandover(orderId: orderId, asBuyer: false)),
            style: FilledButton.styleFrom(
                backgroundColor: TeraFarmColors.primary),
            child: Text(sellerHandover
                ? 'Waiting for buyer confirm'
                : 'Confirm handover done'),
          ),
          const SizedBox(height: 8),
          messageBtn,
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: messageBtn,
    );
  }

  Widget _productImage(String src) {
    if (src.startsWith('http')) {
      return Image.network(src,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback());
    }
    if (src.isNotEmpty) {
      return Image.asset(src,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback());
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        width: 64,
        height: 64,
        color: TeraFarmColors.sage,
        child: const Icon(Icons.eco, color: TeraFarmColors.primary),
      );

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case OrderStatuses.awaitingPayment:
        return Colors.orange.shade800;
      case OrderStatuses.pending:
        return Colors.blueGrey;
      case OrderStatuses.accepted:
        return Colors.blue.shade700;
      case OrderStatuses.readyForPickup:
        return TeraFarmColors.farmerGreen;
      case OrderStatuses.completed:
        return TeraFarmColors.primary;
      default:
        return Colors.red.shade700;
    }
  }
}
