import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'order_notification_service.dart';

/// Unified marketplace order lifecycle (pickup-only).
class OrderStatuses {
  static const awaitingPayment = 'awaiting_payment';
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const readyForPickup = 'ready_for_pickup';
  static const completed = 'completed';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';

  static const activeBuyer = [
    awaitingPayment,
    pending,
    accepted,
    readyForPickup,
  ];

  static const history = [completed, rejected, cancelled];
}

class PaymentMethods {
  static const upi = 'upi';
  static const cod = 'cod';
}

class PaymentStatuses {
  static const awaitingPayment = 'awaiting_payment';
  static const paid = 'paid';
  static const codPending = 'cod_pending';
  static const refunded = 'refunded';
}

class OrderService {
  OrderService._();
  static final instance = OrderService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');

  static const upiExpiry = Duration(minutes: 30);

  /// Create pickup order. UPI starts as awaiting_payment; COD as pending.
  Future<DocumentReference<Map<String, dynamic>>> createPickupOrder({
    required List<Map<String, dynamic>> cartItems,
    required String sellerId,
    required String paymentMethod,
    required int itemTotal,
    required int totalPayable,
    required String? sellerUpiId,
    required String transactionRef,
  }) async {
    final buyerId = FirebaseAuth.instance.currentUser?.uid;
    if (buyerId == null) {
      throw StateError('Must be signed in to place an order');
    }
    if (paymentMethod != PaymentMethods.upi &&
        paymentMethod != PaymentMethods.cod) {
      throw ArgumentError('Invalid payment method');
    }
    if (paymentMethod == PaymentMethods.upi &&
        (sellerUpiId == null || sellerUpiId.trim().isEmpty)) {
      throw StateError('Seller UPI ID is required for UPI payment');
    }

    final now = DateTime.now();
    final isUpi = paymentMethod == PaymentMethods.upi;

    final data = <String, dynamic>{
      'cartItems': cartItems,
      'fulfillmentType': 'pickup',
      'deliveryMethod': 'pickup',
      'deliveryFee': 0,
      'itemTotal': itemTotal,
      'totalPayable': totalPayable,
      'status': isUpi ? OrderStatuses.awaitingPayment : OrderStatuses.pending,
      'paymentMethod': paymentMethod,
      'paymentStatus': isUpi
          ? PaymentStatuses.awaitingPayment
          : PaymentStatuses.codPending,
      'sellerUpiId': sellerUpiId,
      'transactionRef': transactionRef,
      'orderDate': now.toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
      'buyerId': buyerId,
      'sellerId': sellerId,
      'buyerPaidClaimedAt': null,
      'sellerPaymentConfirmedAt': null,
      'buyerHandoverConfirmed': false,
      'sellerHandoverConfirmed': false,
      'completedAt': null,
      'expiresAt': isUpi
          ? Timestamp.fromDate(now.add(upiExpiry))
          : null,
      'lastMessageAt': null,
    };

    final ref = await _orders.add(data);
    await OrderNotificationService.instance.notifyNewOrder(
      sellerId: sellerId,
      orderId: ref.id,
      total: totalPayable,
      paymentMethod: paymentMethod,
    );
    return ref;
  }

  /// Buyer claims they completed UPI (does NOT mark paid).
  Future<void> buyerClaimUpiPaid(String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ref = _orders.doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Order not found');
    final data = snap.data()!;
    _assertParty(data, uid);
    if (data['paymentMethod'] != PaymentMethods.upi) {
      throw StateError('Not a UPI order');
    }
    if (data['status'] != OrderStatuses.awaitingPayment &&
        data['paymentStatus'] != PaymentStatuses.awaitingPayment) {
      return;
    }
    await ref.update({
      'buyerPaidClaimedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final total = _asInt(data['totalPayable'] ?? data['itemTotal']);
    await OrderNotificationService.instance.notifyBuyerPaidClaim(
      sellerId: data['sellerId'].toString(),
      orderId: orderId,
      total: total,
    );
  }

  /// Seller confirms UPI received → pending + paid (Accept unlocked).
  Future<void> sellerConfirmUpiReceived(String orderId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ref = _orders.doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Order not found');
    final data = snap.data()!;
    if (data['sellerId'] != uid) throw StateError('Only seller can confirm');
    if (data['paymentMethod'] != PaymentMethods.upi) {
      throw StateError('Not a UPI order');
    }
    await ref.update({
      'paymentStatus': PaymentStatuses.paid,
      'status': OrderStatuses.pending,
      'sellerPaymentConfirmedAt': FieldValue.serverTimestamp(),
      'paidAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': null,
    });
    await OrderNotificationService.instance.notifyPaymentConfirmed(
      buyerId: data['buyerId'].toString(),
      orderId: orderId,
    );
  }

  Future<void> accept(String orderId) async {
    final buyerId = await _sellerTransition(
      orderId: orderId,
      from: OrderStatuses.pending,
      to: OrderStatuses.accepted,
      requirePaidOrCod: true,
    );
    await OrderNotificationService.instance.notifyOrderAccepted(
      buyerId: buyerId,
      orderId: orderId,
    );
  }

  Future<void> reject(String orderId) async {
    final buyerId = await _sellerTransition(
      orderId: orderId,
      from: OrderStatuses.pending,
      to: OrderStatuses.rejected,
    );
    await OrderNotificationService.instance.notifyOrderRejected(
      buyerId: buyerId,
      orderId: orderId,
    );
  }

  Future<void> markReadyForPickup(String orderId) async {
    final buyerId = await _sellerTransition(
      orderId: orderId,
      from: OrderStatuses.accepted,
      to: OrderStatuses.readyForPickup,
    );
    await OrderNotificationService.instance.notifyReadyForPickup(
      buyerId: buyerId,
      orderId: orderId,
    );
  }

  Future<void> cancel(String orderId, {required bool asSeller}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ref = _orders.doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Order not found');
    final data = snap.data()!;
    if (asSeller && data['sellerId'] != uid) {
      throw StateError('Only seller can cancel');
    }
    if (!asSeller && data['buyerId'] != uid) {
      throw StateError('Only buyer can cancel');
    }
    final status = (data['status'] ?? '').toString();
    if (status == OrderStatuses.completed ||
        status == OrderStatuses.rejected ||
        status == OrderStatuses.cancelled) {
      return;
    }
    await ref.update({
      'status': OrderStatuses.cancelled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final other = asSeller
        ? data['buyerId'].toString()
        : data['sellerId'].toString();
    await OrderNotificationService.instance.notifyOrderCancelled(
      targetUid: other,
      orderId: orderId,
    );
  }

  /// Cancel unpaid UPI if past expiresAt (client-side helper).
  Future<bool> cancelIfUpiExpired(String orderId) async {
    final ref = _orders.doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) return false;
    final data = snap.data()!;
    if (data['status'] != OrderStatuses.awaitingPayment) return false;
    final expires = data['expiresAt'];
    DateTime? exp;
    if (expires is Timestamp) exp = expires.toDate();
    if (exp == null || DateTime.now().isBefore(exp)) return false;
    await ref.update({
      'status': OrderStatuses.cancelled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  Future<void> confirmHandover({
    required String orderId,
    required bool asBuyer,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ref = _orders.doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Order not found');
      final data = snap.data()!;
      if (asBuyer) {
        if (data['buyerId'] != uid) throw StateError('Not the buyer');
      } else {
        if (data['sellerId'] != uid) throw StateError('Not the seller');
      }
      if (data['status'] != OrderStatuses.readyForPickup) {
        throw StateError('Order is not ready for pickup');
      }

      final buyerDone =
          asBuyer ? true : (data['buyerHandoverConfirmed'] == true);
      final sellerDone =
          asBuyer ? (data['sellerHandoverConfirmed'] == true) : true;

      final updates = <String, dynamic>{
        if (asBuyer) 'buyerHandoverConfirmed': true,
        if (!asBuyer) 'sellerHandoverConfirmed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (buyerDone && sellerDone) {
        updates['status'] = OrderStatuses.completed;
        updates['completedAt'] = FieldValue.serverTimestamp();
        if (data['paymentMethod'] == PaymentMethods.cod) {
          updates['paymentStatus'] = PaymentStatuses.paid;
          updates['paidAt'] = FieldValue.serverTimestamp();
        }
      }

      tx.update(ref, updates);
    });

    // Best-effort stock decrement after both confirmed.
    final after = await ref.get();
    final data = after.data();
    if (data != null && data['status'] == OrderStatuses.completed) {
      await _decrementStockBestEffort(data);
      await OrderNotificationService.instance.notifyOrderCompleted(
        buyerId: data['buyerId'].toString(),
        sellerId: data['sellerId'].toString(),
        orderId: orderId,
      );
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> sendMessage({
    required String orderId,
    required String text,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError('Empty message');

    final orderSnap = await _orders.doc(orderId).get();
    if (!orderSnap.exists) throw StateError('Order not found');
    final data = orderSnap.data()!;
    final role = data['buyerId'] == uid
        ? 'buyer'
        : data['sellerId'] == uid
            ? 'seller'
            : null;
    if (role == null) throw StateError('Not a party to this order');

    final msgRef = await _orders.doc(orderId).collection('messages').add({
      'senderId': uid,
      'senderRole': role,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _orders.doc(orderId).update({
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': trimmed,
      'lastMessageSenderId': uid,
    });
    final other = role == 'buyer'
        ? data['sellerId'].toString()
        : data['buyerId'].toString();
    await OrderNotificationService.instance.notifyNewMessage(
      targetUid: other,
      orderId: orderId,
      preview: trimmed,
    );
    return msgRef;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String orderId) {
    return _orders
        .doc(orderId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  void _assertParty(Map<String, dynamic> data, String? uid) {
    if (uid == null ||
        (data['buyerId'] != uid && data['sellerId'] != uid)) {
      throw StateError('Not a party to this order');
    }
  }

  /// Returns buyerId for follow-up notifications.
  Future<String> _sellerTransition({
    required String orderId,
    required String from,
    required String to,
    bool requirePaidOrCod = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final ref = _orders.doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Order not found');
    final data = snap.data()!;
    if (data['sellerId'] != uid) throw StateError('Only seller');
    if ((data['status'] ?? '') != from) {
      throw StateError('Invalid status transition');
    }
    if (requirePaidOrCod) {
      final ps = (data['paymentStatus'] ?? '').toString();
      final pm = (data['paymentMethod'] ?? '').toString();
      if (pm == PaymentMethods.upi && ps != PaymentStatuses.paid) {
        throw StateError('Confirm UPI payment before accepting');
      }
    }
    await ref.update({
      'status': to,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return data['buyerId'].toString();
  }

  Future<void> _decrementStockBestEffort(Map<String, dynamic> order) async {
    try {
      final sellerId = order['sellerId']?.toString();
      final items = order['cartItems'];
      if (sellerId == null || items is! List) return;

      final farms = await _db
          .collection('farms')
          .where('sellerId', isEqualTo: sellerId)
          .limit(5)
          .get();
      if (farms.docs.isEmpty) return;

      for (final farmDoc in farms.docs) {
        final products = List<Map<String, dynamic>>.from(
          (farmDoc.data()['products'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
        var changed = false;
        for (final raw in items) {
          if (raw is! Map) continue;
          final name = (raw['name'] ?? raw['cropName'] ?? '').toString();
          final qty = _asInt(raw['quantity']);
          if (name.isEmpty || qty <= 0) continue;
          for (final p in products) {
            final crop = (p['cropName'] ?? '').toString();
            if (crop.toLowerCase() != name.toLowerCase()) continue;
            final stock = _asInt(p['stock in kgs'] ?? p['stock']);
            final next = (stock - qty).clamp(0, 1 << 30);
            p['stock in kgs'] = next.toString();
            changed = true;
          }
        }
        if (changed) {
          await farmDoc.reference.update({'products': products});
          break;
        }
      }
    } catch (_) {
      // Best-effort only.
    }
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static bool countsAsEarning(Map<String, dynamic> data) {
    final ps = (data['paymentStatus'] ?? '').toString();
    final status = (data['status'] ?? '').toString();
    if (status == OrderStatuses.rejected || status == OrderStatuses.cancelled) {
      return false;
    }
    return ps == PaymentStatuses.paid;
  }

  static String statusLabel(String status) {
    switch (status) {
      case OrderStatuses.awaitingPayment:
        return 'Awaiting payment';
      case OrderStatuses.pending:
        return 'Pending';
      case OrderStatuses.accepted:
        return 'Accepted';
      case OrderStatuses.readyForPickup:
        return 'Ready for pickup';
      case OrderStatuses.completed:
        return 'Completed';
      case OrderStatuses.rejected:
        return 'Rejected';
      case OrderStatuses.cancelled:
        return 'Cancelled';
      default:
        return status;
    }
  }
}
