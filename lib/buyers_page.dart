import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'Product_page.dart';
import 'home_page.dart';
import 'menu_page.dart';
import 'cart_page.dart';
import 'Community_page.dart';
import 'shop_page.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_locales.dart';
import 'main.dart' show LocaleProvider;
class BuyersPage extends StatefulWidget {
  const BuyersPage({super.key});

  @override
  _BuyersPageState createState() => _BuyersPageState();
}

class _BuyersPageState extends State<BuyersPage> {
  int _selectedIndex = 2;

  void _onNavItemTapped(int index) {
    Widget? dest;
    switch (index) {
      case 0:
        dest = const HomePage();
        break;
      case 1:
        dest = const CommunityPage();
        break;
      case 3:
        dest = const ShopPage();
        break;
    }
    if (dest != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => dest!));
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProv = Provider.of<LocaleProvider>(context, listen: false);

    final categories = <Map<String, String>>[
      {'key': 'onion', 'name': loc.catOnion, 'image': 'assets/onion.png'},
      {'key': 'tomato', 'name': loc.catTomato, 'image': 'assets/tomato.png'},
      {'key': 'beans', 'name': loc.catBeans, 'image': 'assets/beans.png'},
      {'key': 'greens', 'name': loc.catGreens, 'image': 'assets/greens.png'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green.shade900,
        leading: Builder(builder: (ctx) {
          return IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          );
        }),
        title: Image.asset("assets/terafarm_logo.png", height: 40),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CartPage(cartItems: [])));
            },
          ),
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language, color: Colors.white),
            tooltip: 'Language',
            onSelected: (locale) => localeProv.setLocale(locale),
            itemBuilder: (context) => AppLocales.supported
                .map(
                  (l) => PopupMenuItem(
                    value: l,
                    child: Text(l.languageCode.toUpperCase()),
                  ),
                )
                .toList(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const MenuPage(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            decoration: InputDecoration(
              hintText: loc.searchHint,
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
          Text(loc.eatHealthy,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: categories.map((c) {
                return GestureDetector(
                  onTap: () {},
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Image.asset(c['image']!, width: 50, height: 50),
                        const SizedBox(height: 5),
                        Text(
                          c['name']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  loc.farmsAroundYou,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.filter_list, color: Colors.grey.shade700),
                onPressed: () {},
              ),
            ],
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('farms')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Center(child: Text(loc.loading)),
                );
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(loc.noFarmsFound),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final farm = docs[i].data()! as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ProductPage(farmId: docs[i].id))),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(10)),
                            child: (farm['imageUrl'] as String?)
                                        ?.startsWith('assets/') ??
                                    false
                                ? Image.asset(farm['imageUrl'], height: 150, width: double.infinity, fit: BoxFit.cover)
                                : Image.network(farm['imageUrl'], height: 150, width: double.infinity, fit: BoxFit.cover),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(farm['farmName'] ?? loc.unnamedFarm,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  Text(farm['farmDescription'] ?? loc.noDescription,
                                      style: TextStyle(
                                          color: Colors.grey.shade700)),
                                  const SizedBox(height: 5),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${loc.scaleLabel}: ${farm['scale'] ?? 'N/A'}'),
                                        Row(children: [
                                          const Icon(Icons.star,
                                              color: Colors.orange, size: 16),
                                          Text((farm['rating'] ?? 0).toString())
                                        ])
                                      ])
                                ]),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ]),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 9,
        selectedLabelStyle: const TextStyle(height: 1.1, fontSize: 10),
        unselectedLabelStyle: const TextStyle(height: 1.1, fontSize: 9),
        onTap: _onNavItemTapped,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: loc.navHome),
          BottomNavigationBarItem(
              icon: const Icon(Icons.apartment), label: loc.navCommunity),
          BottomNavigationBarItem(
              icon: const Icon(Icons.shopping_bag), label: loc.navBuy),
          BottomNavigationBarItem(
              icon: const Icon(Icons.store), label: loc.navShop),
        ],
      ),
    );
  }
}
