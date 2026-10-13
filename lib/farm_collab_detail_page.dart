import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FarmCollabDetailPage extends StatelessWidget {
  final String farmId;
  final String farmName;
  final String imageUrl;
  final String owner;

  const FarmCollabDetailPage({
    super.key,
    required this.farmId,
    required this.farmName,
    required this.imageUrl,
    required this.owner,
  });

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text(farmName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          imageUrl.isNotEmpty
              ? Image.network(imageUrl, height: 180, fit: BoxFit.cover)
              : const Placeholder(fallbackHeight: 180),
          const SizedBox(height: 16),
          Text("Owner: $owner", style: const TextStyle(fontSize: 18)),
          Text("Farm ID: $farmId", style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 24),
          const Text(
            "Order Requests",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildOrderRequests(context, currentUserId),
        ],
      ),
    );
  }

  Widget _buildOrderRequests(BuildContext context, String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('orderCollabRequests')
              .where(
                'farmId',
                isEqualTo: farmId,
              ) // 🔑 Ensures only relevant farm requests
              .where('status', isEqualTo: 'pending')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text('No order collaboration requests.'),
          );
        }

        return Column(
          children:
              requests.map((req) {
                final data = req.data() as Map<String, dynamic>;
                final orderId = data['orderId'];

                return FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('orders')
                          .doc(orderId)
                          .get(),
                  builder: (context, orderSnap) {
                    if (!orderSnap.hasData || !orderSnap.data!.exists) {
                      return const SizedBox.shrink();
                    }

                    final order =
                        orderSnap.data!.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(
                          "Order from ${order['buyerId'] ?? 'Unknown'}",
                        ),
                        subtitle: Text(
                          "Location: ${order['location'] ?? 'N/A'}\nDelivery: ${order['delivery'] ?? 'pickup'}",
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              onPressed:
                                  () => _approveOrderCollab(
                                    context,
                                    req.id,
                                    orderId,
                                    currentUserId,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed:
                                  () => _rejectOrderCollab(context, req.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
        );
      },
    );
  }

  Future<void> _approveOrderCollab(
    BuildContext context,
    String docId,
    String orderId,
    String currentUserId,
  ) async {
    final batch = FirebaseFirestore.instance.batch();

    final reqRef = FirebaseFirestore.instance
        .collection('orderCollabRequests')
        .doc(docId);
    batch.update(reqRef, {'status': 'approved'});

    final others =
        await FirebaseFirestore.instance
            .collection('orderCollabRequests')
            .where('orderId', isEqualTo: orderId)
            .where('status', isEqualTo: 'pending')
            .get();

    for (var d in others.docs) {
      if (d.id != docId) {
        batch.update(d.reference, {'status': 'expired'});
      }
    }

    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId);
    batch.update(orderRef, {
      'status': 'collaborating',
      'collaboratorId': currentUserId,
    });

    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order collaboration accepted!')),
    );
  }

  Future<void> _rejectOrderCollab(BuildContext context, String docId) async {
    await FirebaseFirestore.instance
        .collection('orderCollabRequests')
        .doc(docId)
        .update({'status': 'rejected'});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order collaboration rejected.')),
    );
  }
}