import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Order / payment notifications: Firestore inbox + local alerts + optional FCM push.
class OrderNotificationService {
  OrderNotificationService._();
  static final instance = OrderNotificationService._();

  final _db = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inboxSub;
  StreamSubscription<User?>? _authSub;
  final Set<String> _seenIds = {};
  bool _started = false;
  bool _inboxPrimed = false;

  /// Call once at app start — listens for the signed-in user's inbox.
  void start() {
    if (_started) return;
    _started = true;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _inboxSub?.cancel();
      _inboxSub = null;
      _seenIds.clear();
      _inboxPrimed = false;
      if (user != null) {
        _listenInbox(user.uid);
      }
    });
  }

  void dispose() {
    _inboxSub?.cancel();
    _authSub?.cancel();
    _started = false;
  }

  void _listenInbox(String uid) {
    _inboxSub = _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .listen((snap) async {
      // First load after opening app: surface unread order alerts even if
      // they arrived while the farmer/buyer was outside the app.
      if (!_inboxPrimed) {
        _inboxPrimed = true;
        var shown = 0;
        for (final doc in snap.docs) {
          _seenIds.add(doc.id);
          final data = doc.data();
          if (data['read'] == true) continue;
          if (shown >= 5) continue; // avoid flooding on login
          await _showAndMarkRead(uid, doc.id, data);
          shown++;
        }
        return;
      }

      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final id = change.doc.id;
        if (_seenIds.contains(id)) continue;
        final data = change.doc.data();
        if (data == null) continue;
        _seenIds.add(id);
        if (data['read'] == true) continue;
        await _showAndMarkRead(uid, id, data);
      }
    }, onError: (e) => debugPrint('Order inbox listen error: $e'));
  }

  Future<void> _showAndMarkRead(
    String uid,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final title = (data['title'] ?? 'TeraFarm').toString();
    final body = (data['body'] ?? '').toString();
    final orderId = (data['orderId'] ?? '').toString();
    try {
      await NotificationService().showOrderNotification(
        title: title,
        body: body,
        payload: orderId.isEmpty ? 'order' : 'order:$orderId',
      );
      await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(docId)
          .set({'read': true, 'readAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
    } catch (e) {
      debugPrint('Local order notification failed: $e');
    }
  }

  Future<void> notifyUser({
    required String targetUid,
    required String title,
    required String body,
    String? orderId,
    String type = 'order',
  }) async {
    if (targetUid.isEmpty) return;
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me != null && me == targetUid) {
      // Still show local for own device edge cases (e.g. multi-account rare).
    }

    try {
      await _db
          .collection('users')
          .doc(targetUid)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'orderId': orderId,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'fromUid': me,
      });
    } catch (e) {
      debugPrint('Failed to write order notification inbox: $e');
    }

    // Best-effort FCM via Cloud Function (deploy sendOrderPush).
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('sendOrderPush');
      await callable.call({
        'targetUid': targetUid,
        'title': title,
        'body': body,
        'orderId': orderId,
        'type': type,
      });
    } catch (e) {
      debugPrint('sendOrderPush skipped/unavailable: $e');
    }
  }

  Future<void> notifyNewOrder({
    required String sellerId,
    required String orderId,
    required int total,
    required String paymentMethod,
  }) {
    return notifyUser(
      targetUid: sellerId,
      title: 'New pickup order',
      body: paymentMethod == 'cod'
          ? 'COD order · ₹$total — accept when ready'
          : 'UPI order · ₹$total — confirm payment when received',
      orderId: orderId,
      type: 'new_order',
    );
  }

  Future<void> notifyBuyerPaidClaim({
    required String sellerId,
    required String orderId,
    required int total,
  }) {
    return notifyUser(
      targetUid: sellerId,
      title: 'Buyer says they paid',
      body: 'Verify ₹$total in your UPI app, then confirm in Orders',
      orderId: orderId,
      type: 'payment_claim',
    );
  }

  Future<void> notifyPaymentConfirmed({
    required String buyerId,
    required String orderId,
  }) {
    return notifyUser(
      targetUid: buyerId,
      title: 'Payment confirmed',
      body: 'The farmer confirmed your UPI payment. Waiting for accept.',
      orderId: orderId,
      type: 'payment_confirmed',
    );
  }

  Future<void> notifyOrderAccepted({
    required String buyerId,
    required String orderId,
  }) {
    return notifyUser(
      targetUid: buyerId,
      title: 'Order accepted',
      body: 'Your order was accepted. We will notify you when ready for pickup.',
      orderId: orderId,
      type: 'order_accepted',
    );
  }

  Future<void> notifyOrderRejected({
    required String buyerId,
    required String orderId,
  }) {
    return notifyUser(
      targetUid: buyerId,
      title: 'Order rejected',
      body: 'The farmer could not fulfill this order.',
      orderId: orderId,
      type: 'order_rejected',
    );
  }

  Future<void> notifyReadyForPickup({
    required String buyerId,
    required String orderId,
  }) {
    return notifyUser(
      targetUid: buyerId,
      title: 'Ready for pickup',
      body: 'Your order is ready. Confirm after you collect the produce.',
      orderId: orderId,
      type: 'ready_for_pickup',
    );
  }

  Future<void> notifyOrderCancelled({
    required String targetUid,
    required String orderId,
  }) {
    return notifyUser(
      targetUid: targetUid,
      title: 'Order cancelled',
      body: 'An order was cancelled.',
      orderId: orderId,
      type: 'order_cancelled',
    );
  }

  Future<void> notifyOrderCompleted({
    required String buyerId,
    required String sellerId,
    required String orderId,
  }) async {
    await notifyUser(
      targetUid: buyerId,
      title: 'Order completed',
      body: 'Pickup confirmed. Thanks for buying local!',
      orderId: orderId,
      type: 'order_completed',
    );
    await notifyUser(
      targetUid: sellerId,
      title: 'Order completed',
      body: 'Handover confirmed. Payment settled.',
      orderId: orderId,
      type: 'order_completed',
    );
  }

  Future<void> notifyNewMessage({
    required String targetUid,
    required String orderId,
    required String preview,
  }) {
    return notifyUser(
      targetUid: targetUid,
      title: 'New order message',
      body: preview.length > 80 ? '${preview.substring(0, 80)}…' : preview,
      orderId: orderId,
      type: 'order_message',
    );
  }
}
