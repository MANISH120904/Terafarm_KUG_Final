import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/tera_farm_theme.dart';
import 'widgets/tera_farm_scaffold.dart';

class OrderListPage extends StatefulWidget {
  const OrderListPage({Key? key}) : super(key: key);

  @override
  _OrderListPageState createState() => _OrderListPageState();
}

class _OrderListPageState extends State<OrderListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markPaymentReceived(String orderId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'paymentStatus': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final String sellerId = _auth.currentUser!.uid;

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

          final pendingOrders = allOrders
              .where((doc) => (doc['status'] ?? 'pending') == 'pending')
              .toList();
          final acceptedOrders = allOrders
              .where((doc) => (doc['status'] ?? '') == 'accepted')
              .toList();
          final completedOrders = allOrders.where((doc) {
            final s = (doc['status'] ?? '').toString().toLowerCase();
            return s == 'rejected' || s == 'delivered' || s == 'cancelled';
          }).toList();

          if (allOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No orders yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _sectionHeader('Active', pendingOrders.length + acceptedOrders.length),
              const SizedBox(height: 10),
              if (pendingOrders.isEmpty && acceptedOrders.isEmpty)
                _emptyHint('No active orders')
              else ...[
                for (final doc in pendingOrders)
                  _buildOrderCard(doc, status: 'pending'),
                for (final doc in acceptedOrders)
                  _buildOrderCard(doc, status: 'accepted'),
              ],
              const SizedBox(height: 22),
              _sectionHeader('History', completedOrders.length),
              const SizedBox(height: 10),
              if (completedOrders.isEmpty)
                _emptyHint('No completed orders')
              else
                for (final doc in completedOrders)
                  _buildOrderCard(doc, status: (doc['status'] ?? '').toString()),
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
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: TeraFarmColors.primaryDark,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: TeraFarmColors.sage,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: TeraFarmColors.primaryDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(color: Colors.grey.shade600)),
    );
  }

  Widget _buildOrderCard(DocumentSnapshot orderDoc, {required String status}) {
    final data = orderDoc.data() as Map<String, dynamic>;
    final orderId = orderDoc.id;
    final buyerId = (data['buyerId'] ?? 'unknown').toString();
    final deliveryMethod =
        (data['deliveryMethod'] ?? data['delivery'] ?? 'pickup').toString();
    final address = (data['deliveryAddress'] ?? data['location'] ?? '—').toString();
    final total = data['totalPayable'] ?? data['itemTotal'] ?? 0;
    final paymentStatus =
        (data['paymentStatus'] ?? 'awaiting_payment').toString().toLowerCase();
    final sellerUpi = (data['sellerUpiId'] ?? '').toString();
    final items = (data['cartItems'] as List?) ?? const [];
    final firstItem = items.isNotEmpty && items.first is Map
        ? Map<String, dynamic>.from(items.first as Map)
        : <String, dynamic>{};
    final productImage = (firstItem['image'] ?? '').toString();
    final itemCount = items.length;

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
                        Text(
                          buyerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: TeraFarmColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$itemCount item${itemCount == 1 ? '' : 's'} · ₹$total',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: TeraFarmColors.farmerGreenDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          deliveryMethod == 'delivery'
                              ? 'Delivery · $address'
                              : 'Pickup',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    label: _statusLabel(status),
                    color: _statusColor(status),
                  ),
                  _chip(
                    label: paymentStatus == 'paid' ? 'Paid' : 'UPI pending',
                    color: paymentStatus == 'paid'
                        ? TeraFarmColors.farmerGreen
                        : Colors.orange.shade700,
                  ),
                  if (sellerUpi.isNotEmpty)
                    _chip(
                      label: sellerUpi,
                      color: TeraFarmColors.primary,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildActionButtons(
                status: status,
                orderId: orderId,
                paymentStatus: paymentStatus,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _productImage(String src) {
    if (src.startsWith('http')) {
      return Image.network(
        src,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageFallback(),
      );
    }
    if (src.isNotEmpty) {
      return Image.asset(
        src,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageFallback(),
      );
    }
    return _imageFallback();
  }

  Widget _imageFallback() {
    return Container(
      width: 64,
      height: 64,
      color: TeraFarmColors.sage,
      child: const Icon(Icons.eco, color: TeraFarmColors.primary),
    );
  }

  Widget _chip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'delivered':
        return 'Delivered';
      case 'rejected':
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.blueGrey;
      case 'accepted':
        return Colors.blue.shade700;
      case 'delivered':
        return TeraFarmColors.farmerGreen;
      case 'rejected':
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActionButtons({
    required String status,
    required String orderId,
    required String paymentStatus,
  }) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateOrderStatus(orderId, 'rejected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _updateOrderStatus(orderId, 'accepted'),
                    style: FilledButton.styleFrom(
                      backgroundColor: TeraFarmColors.primary,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
            if (paymentStatus != 'paid') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _markPaymentReceived(orderId),
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Mark UPI payment received'),
                ),
              ),
            ],
          ],
        );

      case 'accepted':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateOrderStatus(orderId, 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _updateOrderStatus(orderId, 'delivered'),
                    style: FilledButton.styleFrom(
                      backgroundColor: TeraFarmColors.farmerGreen,
                    ),
                    child: const Text('Delivered'),
                  ),
                ),
              ],
            ),
            if (paymentStatus != 'paid') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _markPaymentReceived(orderId),
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: const Text('Mark UPI payment received'),
                ),
              ),
            ],
          ],
        );

      default:
        return Align(
          alignment: Alignment.centerLeft,
          child: _chip(
            label: _statusLabel(status),
            color: _statusColor(status),
          ),
        );
    }
  }
}
