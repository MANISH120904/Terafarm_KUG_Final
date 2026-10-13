import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_page.dart';

class ProductPage extends StatefulWidget {
  final String farmId; // Document ID from Firestore

  const ProductPage({
    Key? key,
    required this.farmId,
  }) : super(key: key);

  @override
  _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final Map<int, int> _quantities = {}; // Stores quantity for each product
  final Map<String, int> _unitPrices = {
    "onion": 9,
    "tomato": 10,
  };

  int _getUnitPrice(String productName, dynamic firestorePrice) {
    return _unitPrices[productName.toLowerCase()] ??
        int.tryParse(firestorePrice.toString()) ??
        0;
  }

  bool get _hasAnyQuantity => _quantities.values.any((qty) => qty > 0);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('farms')
          .doc(widget.farmId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.data!.exists) {
          return const Center(child: Text("Farm not found."));
        }

        final farmData = snapshot.data!.data() as Map<String, dynamic>;
        final farmName = farmData["farmName"] ?? "Unnamed Farm";
        final farmDesc = farmData["farmDescription"] ?? "No description available.";
        final scale = farmData["scale"] ?? "N/A";
        final rating = farmData["rating"] ?? 4.0;
        final imageUrl = farmData["imageUrl"] ?? "assets/sample_farm.png";
        final distanceCharge = farmData["distanceCharge"] ?? 10;
        final String sellerId = farmData["sellerId"] ?? "unknown";
        final List products = farmData["products"] as List? ?? [];

        for (int i = 0; i < products.length; i++) {
          _quantities.putIfAbsent(i, () => 0);
        }

        Widget? bottomBar;
        if (_hasAnyQuantity) {
          bottomBar = Container(
            height: 60,
            color: Colors.red,
            child: InkWell(
              onTap: () {
                final List<Map<String, dynamic>> cartItems = [];
                for (int i = 0; i < products.length; i++) {
                  final product = products[i] as Map<String, dynamic>;
                  final quantity = _quantities[i] ?? 0;
                  if (quantity > 0) {
                    cartItems.add({
                      "name": product["cropName"],
                      "price": _getUnitPrice(product["cropName"], product["pricePerKg"]),
                      "quantity": quantity,
                      "image": "assets/${product["cropName"].toString().toLowerCase()}.png",
                      "unit": "500 gms",
                      "sellerId": sellerId,
                    });
                  }
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CartPage(cartItems: cartItems),
                  ),
                );
              },
              child: const Center(
                child: Text(
                  "Buy Now",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.green.shade900,
            title: Row(
              children: [
                Transform.translate(
                  offset: const Offset(-40, 5),
                  child: Image.asset("assets/terafarm_logo.png", height: 40),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          bottomNavigationBar: bottomBar,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Farm Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl.startsWith("assets/")
                      ? Image.asset(
                          imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(height: 10),
                Text(
                  farmName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  farmDesc,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Scale: $scale"),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 16),
                        Text(rating.toString()),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_bike, color: Colors.black54),
                      const SizedBox(width: 5),
                      Text("₹$distanceCharge distance charge"),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Available products",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index] as Map<String, dynamic>;
                    final productName = product["cropName"] ?? "Unnamed";
                    final firestorePrice = product["pricePerKg"] ?? 0;
                    final unitPrice = _getUnitPrice(productName, firestorePrice);
                    final productStock = product["stock in kgs"] ?? "0";
                    final quantity = _quantities[index]!;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                "assets/${productName.toLowerCase()}.png",
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "$productStock kg Each unit",
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline),
                                            onPressed: () {
                                              setState(() {
                                                if (_quantities[index]! > 0) {
                                                  _quantities[index] = _quantities[index]! - 1;
                                                }
                                              });
                                            },
                                          ),
                                          Text(quantity.toString()),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline),
                                            onPressed: () {
                                              setState(() {
                                                _quantities[index] = _quantities[index]! + 1;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "₹${unitPrice * quantity}",
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
