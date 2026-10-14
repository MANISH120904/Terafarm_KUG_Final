import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'buyer/my_orders_page.dart';
import 'services/order_service.dart';
import 'theme/tera_farm_theme.dart';
import 'widgets/tera_farm_scaffold.dart';

class CartPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;

  const CartPage({Key? key, required this.cartItems}) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  String _paymentMethod = PaymentMethods.cod;
  bool _paying = false;
  String? _resolvedUpi;
  String? _payeeName;
  bool _loadingUpi = false;

  @override
  void initState() {
    super.initState();
    _prefetchSellerUpi();
  }

  Future<void> _prefetchSellerUpi() async {
    if (widget.cartItems.isEmpty) return;
    setState(() => _loadingUpi = true);
    try {
      final sellerId = (widget.cartItems.first['sellerId'] ?? '').toString();
      final payment = await _resolveSellerPayment(sellerId);
      if (!mounted) return;
      setState(() {
        _resolvedUpi = payment?['upiId'];
        _payeeName = payment?['payeeName'];
      });
    } finally {
      if (mounted) setState(() => _loadingUpi = false);
    }
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
        if (widget.cartItems.isEmpty) {
          _resolvedUpi = null;
        }
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

  int get _totalPayable => _itemTotal;

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
    if (sellerId.isEmpty || sellerId == 'unknown') return null;
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

  Future<void> _placeOrder() async {
    if (widget.cartItems.isEmpty || _paying) return;

    if (_paymentMethod == PaymentMethods.upi &&
        (_resolvedUpi == null || _resolvedUpi!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This farm has no UPI ID. Choose Cash on Pickup or ask the farmer to add UPI.',
          ),
        ),
      );
      return;
    }

    setState(() => _paying = true);
    try {
      final sellerId = (widget.cartItems.first['sellerId'] ?? '').toString();
      if (sellerId.isEmpty || sellerId == 'unknown') {
        throw Exception('Seller information missing on cart items');
      }

      final txnRef = 'TF${DateTime.now().millisecondsSinceEpoch}';
      final cartCopy =
          List<Map<String, dynamic>>.from(widget.cartItems.map((e) => Map<String, dynamic>.from(e)));

      final orderRef = await OrderService.instance.createPickupOrder(
        cartItems: cartCopy,
        sellerId: sellerId,
        paymentMethod: _paymentMethod,
        itemTotal: _itemTotal,
        totalPayable: _totalPayable,
        sellerUpiId: _resolvedUpi,
        transactionRef: txnRef,
      );

      setState(() => widget.cartItems.clear());

      if (_paymentMethod == PaymentMethods.upi) {
        final amount = _totalPayable.toStringAsFixed(2);
        final payee = _payeeName ?? 'TeraFarm Seller';
        await _launchUpiPayment(
          upiId: _resolvedUpi!,
          payeeName: payee,
          amount: amount,
          txnRef: txnRef,
          note: 'TeraFarm order $txnRef',
        );

        if (!mounted) return;
        final claimed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('UPI payment'),
            content: Text(
              'Complete ₹$amount to $payee (${_resolvedUpi!}) in your UPI app.\n\n'
              'Your order stays unpaid until the farmer confirms the payment.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('I will pay later'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('I paid'),
              ),
            ],
          ),
        );

        if (claimed == true) {
          await OrderService.instance.buyerClaimUpiPaid(orderRef.id);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Order saved. Waiting for farmer to confirm UPI payment.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed — Cash on Pickup. Pay when you collect.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MyOrdersPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: $e')),
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
                                    Text(unit,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600)),
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
                                      onPressed: () =>
                                          _decrementQuantity(index),
                                      icon: const Icon(
                                          Icons.remove_circle_outline),
                                    ),
                                    Text('$quantity',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          _incrementQuantity(index),
                                      icon: const Icon(
                                          Icons.add_circle_outline),
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
                        title: 'Fulfillment',
                        child: Row(
                          children: [
                            Expanded(
                              child: _methodChip(
                                label: 'Pickup',
                                selected: true,
                                onTap: () {},
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Opacity(
                                    opacity: 0.45,
                                    child: _methodChip(
                                      label: 'Delivery',
                                      selected: false,
                                      onTap: null,
                                    ),
                                  ),
                                  Positioned(
                                    top: -6,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade700,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Not available yet',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionCard(
                        title: 'Payment',
                        child: Column(
                          children: [
                            _paymentTile(
                              value: PaymentMethods.cod,
                              title: 'Cash on Pickup (COD)',
                              subtitle: 'Pay the farmer when you collect',
                              icon: Icons.payments_outlined,
                            ),
                            const SizedBox(height: 8),
                            _paymentTile(
                              value: PaymentMethods.upi,
                              title: 'Pay via UPI',
                              subtitle: _loadingUpi
                                  ? 'Checking farmer UPI…'
                                  : (_resolvedUpi != null
                                      ? 'Pay to $_resolvedUpi'
                                      : 'Farmer UPI not set'),
                              icon: Icons.account_balance_wallet_outlined,
                              enabled: _resolvedUpi != null,
                            ),
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
                            _billRow('Delivery fee', '₹0 (pickup)'),
                            const Divider(height: 20),
                            _billRow('Total payable', '₹$_totalPayable',
                                bold: true),
                            const SizedBox(height: 8),
                            Text(
                              _paymentMethod == PaymentMethods.upi
                                  ? 'UPI orders stay unpaid until the farmer confirms payment.'
                                  : 'COD: pay in cash when you pick up the produce.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
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
                      onPressed: _paying ? null : _placeOrder,
                      icon: _paying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_paymentMethod == PaymentMethods.upi
                              ? Icons.currency_rupee
                              : Icons.storefront_outlined),
                      label: Text(
                        _paying
                            ? 'Placing order…'
                            : (_paymentMethod == PaymentMethods.upi
                                ? 'Pay ₹$_totalPayable with UPI'
                                : 'Place COD order · ₹$_totalPayable'),
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

  Widget _paymentTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    bool enabled = true,
  }) {
    final selected = _paymentMethod == value;
    return Material(
      color: selected ? TeraFarmColors.sage : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: !enabled
            ? null
            : () => setState(() => _paymentMethod = value),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon,
                  color: enabled
                      ? TeraFarmColors.primary
                      : Colors.grey.shade400),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: enabled ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: value,
                groupValue: _paymentMethod,
                onChanged: !enabled
                    ? null
                    : (v) => setState(() => _paymentMethod = v!),
              ),
            ],
          ),
        ),
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
    required VoidCallback? onTap,
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
