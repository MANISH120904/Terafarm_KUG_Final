import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'Community_page.dart';
import 'dashboard_page.dart';
import 'cart_page.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  _ShopPageState createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  final int _selectedIndex = 3;
  List<Map<String, dynamic>> farmingTools = [];
  List<Map<String, dynamic>> seeds = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadInventory();
  }

  Future<void> loadInventory() async {
    final toolsSnapshot =
        await FirebaseFirestore.instance.collection('farming_tools').get();
    final seedsSnapshot =
        await FirebaseFirestore.instance.collection('seeds').get();

    setState(() {
      farmingTools =
          toolsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              "id": doc.id,
              "name": data["name"],
              "image": data["image"],
              "price": data["price"],
              "unit": data["unit"],
              "stock": data["stock"],
              "sellerId": data["sellerId"],
              "quantity": 0,
            };
          }).toList();

      seeds =
          seedsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              "id": doc.id,
              "name": data["name"],
              "image": data["image"],
              "price": data["price"],
              "unit": data["unit"],
              "stock": data["stock"],
              "sellerId": data["sellerId"],
              "quantity": 0,
            };
          }).toList();

      isLoading = false;
    });
  }

  Future<void> uploadInventoryData() async {
    final firestore = FirebaseFirestore.instance;

    final List<Map<String, dynamic>> tools = [
      {
        "name": "Pots",
        "image": "assets/pot.png",
        "price": 25,
        "unit": "1 piece",
        "stock": 100,
        "sellerId": "seller_tools_001",
      },
      {
        "name": "Grow Bags",
        "image": "assets/growing_bags.png",
        "price": 30,
        "unit": "1 piece",
        "stock": 80,
        "sellerId": "seller_tools_002",
      },
    ];

    final List<Map<String, dynamic>> seeds = [
      {
        "name": "Tomato Seeds",
        "image": "assets/tomato_seed.png",
        "price": 20,
        "unit": "50 gms",
        "stock": 150,
        "sellerId": "seller_seeds_001",
      },
      {
        "name": "Beans Seeds",
        "image": "assets/beans.png",
        "price": 18,
        "unit": "50 gms",
        "stock": 120,
        "sellerId": "seller_seeds_001",
      },
      {
        "name": "Apple Seeds",
        "image": "assets/Apple.png",
        "price": 40,
        "unit": "100 gms",
        "stock": 60,
        "sellerId": "seller_seeds_002",
      },
      {
        "name": "Grape Seeds",
        "image": "assets/grape.png",
        "price": 35,
        "unit": "50 gms",
        "stock": 70,
        "sellerId": "seller_seeds_002",
      },
    ];

    for (var tool in tools) {
      await firestore.collection('farming_tools').add(tool);
    }

    for (var seed in seeds) {
      await firestore.collection('seeds').add(seed);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Inventory uploaded to Firestore!")),
      );
      loadInventory(); // refresh UI
    }
  }

  void updateQuantity(
    List<Map<String, dynamic>> category,
    int index,
    int change,
  ) {
    setState(() {
      final current = category[index]["quantity"];
      final stock = category[index]["stock"];
      final newQuantity = (current + change).clamp(0, stock);
      category[index]["quantity"] = newQuantity;
    });
  }

  bool hasItemsInCart() {
    return farmingTools.any((item) => item["quantity"] > 0) ||
        seeds.any((item) => item["quantity"] > 0);
  }

  Widget buildInventoryItem(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> category,
    int index,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: Row(
          children: [
            Image.asset(
              item["image"],
              width: 50,
              height: 50,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.image_not_supported,
                  size: 50,
                  color: Colors.grey,
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item["name"],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text("₹${item["price"]} / ${item["unit"]}"),
                  Text("In stock: ${item["stock"]}"),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[200],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.red),
                    onPressed: () => updateQuantity(category, index, -1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      "${item["quantity"]}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.green),
                    onPressed: () => updateQuantity(category, index, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNavItemTapped(int index) {
    if (index == _selectedIndex) return;

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CommunityPage()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Shop"),
        backgroundColor: Colors.green.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: "Upload Demo Inventory",
            onPressed: uploadInventoryData,
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(10),
                child: ListView(
                  children: [
                    const Text(
                      "Inventory",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Farming tools",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...farmingTools
                        .asMap()
                        .entries
                        .map(
                          (entry) => buildInventoryItem(
                            entry.value,
                            farmingTools,
                            entry.key,
                          ),
                        )
                        .toList(),
                    const SizedBox(height: 10),
                    const Text(
                      "Seeds",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...seeds
                        .asMap()
                        .entries
                        .map(
                          (entry) =>
                              buildInventoryItem(entry.value, seeds, entry.key),
                        )
                        .toList(),
                  ],
                ),
              ),
      floatingActionButton:
          hasItemsInCart()
              ? FloatingActionButton.extended(
                  backgroundColor: Colors.green,
                  onPressed: () {
                    List<Map<String, dynamic>> selectedItems =
                        [
                          ...farmingTools,
                          ...seeds,
                        ].where((item) => item["quantity"] > 0).toList();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CartPage(cartItems: selectedItems),
                      ),
                    );
                  },
                  label: const Text(
                    "Buy Now",
                    style: TextStyle(color: Colors.white),
                  ),
                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                )
              : null,
    );
  }
}