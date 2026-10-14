import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'address_map_picker.dart';
import 'theme/tera_farm_theme.dart';
import 'widgets/tera_farm_scaffold.dart';

class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;

  const CartPage({Key? key, required this.cartItems}) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  String _deliveryMethod = 'delivery';
  final int _deliveryFee = 30;
  String _deliveryAddress = 'Select delivery address';
  double? _deliveryLat;
  double? _deliveryLng;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    if (!userDoc.exists) return;
    final data = userDoc.data() ?? {};
    final location = data['location'];
    if (location is Map) {
      setState(() {
        _deliveryAddress =
            (location['address'] as String?)?.trim().isNotEmpty == true
                ? location['address'] as String
                : _deliveryAddress;
        _deliveryLat = (location['latitude'] as num?)?.toDouble();
        _deliveryLng = (location['longitude'] as num?)?.toDouble();
      });
    }
  }

  Future<void> _openMapPicker() async {
    final initialLocation = (_deliveryLat != null && _deliveryLng != null)
        ? LatLng(_deliveryLat!, _deliveryLng!)
        : const LatLng(13.0827, 80.2707);

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressMapPicker(initialLocation: initialLocation),
      ),
    );

    if (result == null) return;
    setState(() {
      _deliveryAddress = result['address'] as String;
      _deliveryLat = result['lat'] as double;
      _deliveryLng = result['lng'] as double;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
      'u_id': currentUser.uid,
      'location': {
        'address': _deliveryAddress,
        'latitude': _deliveryLat,
        'longitude': _deliveryLng,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _emptyCart() {
    setState(() => widget.cartItems.clear());
  }

  void _incrementQuantity(int index) {
    setState(() {
      widget.cartItems[index]['quantity'] =
          (_asInt(widget.cartItems[index]['quantity']) + 1);
    });
  }

  void _decrementQuantity(int index) {
    setState(() {
      final currentQty = _asInt(widget.cartItems[index]['quantity']);
      if (currentQty > 1) {
        widget.cartItems[index]['quantity'] = currentQty - 1;
      } else {
        widget.cartItems.removeAt(index);
      }
    });
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int get _itemTotal {
    var total = 0;
    for (final item in widget.cartItems) {
      total += _asInt(item['price']) * _asInt(item['quantity']);
    }
    return total;
  }

  int get _totalPayable =>
      _deliveryMethod == 'delivery' ? _itemTotal + _deliveryFee : _itemTotal;

  /// Farms save `upiId`; older docs may use `upi_id` / `upi`.
  String? _readUpiFromMap(Map<String, dynamic> data) {
    for (final key in ['upiId', 'upi_id', 'upi', 'UPI', 'upiID']) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  Future<Map<String, String>?> _resolveSellerPayment(String sellerId) async {
    final farms = await FirebaseFirestore.instance
        .collection('farms')
        .where('sellerId', isEqualTo: sellerId)
        .limit(10)
        .get();

    for (final doc in farms.docs) {
      final data = doc.data();
      final upi = _readUpiFromMap(data);
      if (upi != null) {
        final farmName = (data['farmName'] ?? 'TeraFarm Seller').toString();
        return {'upiId': upi, 'payeeName': farmName};
      }
    }
    return null;
  }

  Future<void> _launchUpiPayment({
    required String upiId,
    required String payeeName,
    required String amount,
    required String txnRef,
    required String note,
  }) async {
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId,
        'pn': payeeName,
        'am': amount,
        'cu': 'INR',
        'tn': note,
        'tr': txnRef,
      },
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No UPI app found. Install GPay / PhonePe / Paytm.'),
        ),
      );
    }
  }

  Future<void> _confirmOrder() async {
    if (widget.cartItems.isEmpty || _paying) return;

    if (_deliveryMethod == 'delivery' &&
        (_deliveryAddress.trim().isEmpty ||
            _deliveryAddress == 'Select delivery address')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a delivery address')),
      );
      return;
    }

    setState(() => _paying = true);
    try {
      final sellerId = (widget.cartItems.first['sellerId'] ?? '').toString();
      if (sellerId.isEmpty || sellerId == 'unknown') {
        throw Exception('Seller information missing on cart items');
      }

      // 1) Resolve farmer UPI before creating the order.
      final payment = await _resolveSellerPayment(sellerId);
      if (payment == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This farm has not added a UPI ID yet. Ask the farmer to update it.',
            ),
          ),
        );
        return;
      }

      final upiId = payment['upiId']!;
      final payeeName = payment['payeeName']!;
      final txnRef = 'TF${DateTime.now().millisecondsSinceEpoch}';
      final buyerId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

      // 2) Create order as awaiting payment (standard checkout pattern).
      final orderRef = await FirebaseFirestore.instance.collection('orders').add({
        'cartItems': List<Map<String, dynamic>>.from(widget.cartItems),
        'deliveryMethod': _deliveryMethod,
        'itemTotal': _itemTotal,
        'deliveryFee': _deliveryMethod == 'delivery' ? _deliveryFee : 0,
        'totalPayable': _totalPayable,
        'status': 'pending',
        'paymentStatus': 'awaiting_payment',
        'paymentMethod': 'upi',
        'sellerUpiId': upiId,
        'transactionRef': txnRef,
        'orderDate': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
        'buyerId': buyerId,
        'sellerId': sellerId,
        'deliveryAddress':
            _deliveryMethod == 'delivery' ? _deliveryAddress : null,
        'deliveryLat': _deliveryMethod == 'delivery' ? _deliveryLat : null,
        'deliveryLng': _deliveryMethod == 'delivery' ? _deliveryLng : null,
      });

      final amount = _totalPayable.toStringAsFixed(2);
      setState(() => widget.cartItems.clear());

      // 3) Open any installed UPI app with farmer's VPA.
      await _launchUpiPayment(
        upiId: upiId,
        payeeName: payeeName,
        amount: amount,
        txnRef: txnRef,
        note: 'TeraFarm order $txnRef',
      );

      if (!mounted) return;

      // 4) Confirm payment result (UPI intent does not return a reliable callback).
      final paid = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Payment status'),
          content: Text(
            'Complete ₹$amount to $payeeName ($upiId) in your UPI app, then confirm below.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not paid yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('I paid'),
            ),
          ],
        ),
      );

      await orderRef.update({
        'paymentStatus': paid == true ? 'paid' : 'awaiting_payment',
        'paidAt': paid == true ? FieldValue.serverTimestamp() : null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paid == true
                ? 'Order placed. Payment marked as paid.'
                : 'Order placed. Pay later via UPI if needed — seller can confirm.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete checkout: $e')),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Widget _productImage(String? path) {
    final src = (path ?? '').trim();
    if (src.startsWith('http')) {
      return Image.network(
        src,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageFallback(),
      );
    }
    if (src.isNotEmpty) {
      return Image.asset(
        src,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageFallback(),
      );
    }
    return _imageFallback();
  }

  Widget _imageFallback() {
    return Container(
      width: 72,
      height: 72,
      color: TeraFarmColors.sage,
      child: const Icon(Icons.eco, color: TeraFarmColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = widget.cartItems.length;
    return TeraFarmScaffold(
      mode: TeraFarmScaffoldMode.inner,
      title: 'Cart ($cartCount)',
      backgroundColor: TeraFarmColors.surface,
      actions: [
        if (cartCount > 0)
          IconButton(
            onPressed: _paying ? null : _emptyCart,
            tooltip: 'Empty cart',
            icon: const Icon(Icons.delete_outline, color: Colors.white),
          ),
      ],
      body: cartCount == 0
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [
                      ...List.generate(cartCount, (index) {
                        final item = widget.cartItems[index];
                        final name = (item['name'] ?? 'Unnamed').toString();
                        final price = _asInt(item['price']);
                        final quantity = _asInt(item['quantity']);
                        final unit = (item['unit'] ?? '1 kg').toString();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
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
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _productImage(item['image']?.toString()),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: TeraFarmColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      unit,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '₹$price each',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: TeraFarmColors.farmerGreenDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: TeraFarmColors.sageLight,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _decrementQuantity(index),
                                      icon: const Icon(Icons.remove_circle_outline),
                                    ),
                                    Text(
                                      '$quantity',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _incrementQuantity(index),
                                      icon: const Icon(Icons.add_circle_outline),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      _sectionCard(
                        title: 'Delivery',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _methodChip(
                                    label: 'Home delivery',
                                    selected: _deliveryMethod == 'delivery',
                                    onTap: () => setState(
                                      () => _deliveryMethod = 'delivery',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _methodChip(
                                    label: 'Pickup',
                                    selected: _deliveryMethod == 'pickup',
                                    onTap: () => setState(
                                      () => _deliveryMethod = 'pickup',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_deliveryMethod == 'delivery') ...[
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: TeraFarmColors.farmerGreen,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _deliveryAddress,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _openMapPicker,
                                    child: const Text('Change'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        title: 'Bill summary',
                        child: Column(
                          children: [
                            _billRow('Item total', '₹$_itemTotal'),
                            const SizedBox(height: 6),
                            _billRow(
                              'Delivery fee',
                              _deliveryMethod == 'delivery'
                                  ? '₹$_deliveryFee'
                                  : '₹0',
                            ),
                            const Divider(height: 20),
                            _billRow(
                              'Total payable',
                              '₹$_totalPayable',
                              bold: true,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Pay securely to the farmer\'s UPI ID',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: _paying ? null : _confirmOrder,
                      icon: _paying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.currency_rupee),
                      label: Text(
                        _paying
                            ? 'Opening UPI…'
                            : 'Pay ₹$_totalPayable with UPI',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: TeraFarmColors.primary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: TeraFarmColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _methodChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? TeraFarmColors.sage : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected
                    ? TeraFarmColors.primaryDark
                    : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _billRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: bold ? TeraFarmColors.farmerGreenDark : Colors.black87,
          ),
        ),
      ],
    );
  }
}
