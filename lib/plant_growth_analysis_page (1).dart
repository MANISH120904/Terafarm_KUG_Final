import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'menu_page.dart';

class PlantGrowthAnalysisPage extends StatefulWidget {
  const PlantGrowthAnalysisPage({Key? key}) : super(key: key);

  @override
  State<PlantGrowthAnalysisPage> createState() =>
      _PlantGrowthAnalysisPageState();
}

class _PlantGrowthAnalysisPageState extends State<PlantGrowthAnalysisPage> {
  final String backendUrl =
      "https://tera-242561185203.asia-south1.run.app/";
  String? _expandedPlantId;
  final Map<String, bool> _loadingAdvice = {};
  final Map<String, String> _adviceCache = {};

  // Your full plantTasks map goes here…
  final Map<String, Map<String, List<String>>> plantTasks = {
    'beans': {
      'daily': ['Water soil (keep moist)', 'Ensure 6+ hrs of sunlight', 'Check soil temp'],
      'weekly': ['Add compost or mulch', 'Inspect for aphids', 'Weed around base'],
    },
    // …etc…
    'other': {
      'daily': ['Water as needed', 'Monitor health & color', 'Check for pests'],
      'weekly': ['Fertilize lightly', 'Remove weeds', 'Inspect growth issues'],
    },
  };

  String _getImageAsset(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('tomato')) return 'assets/tomato1.png';
    if (lower.contains('beans')) return 'assets/beans1.png';
    // …other mappings…
    return 'assets/default.png';
  }

  int _calculateDaysSincePlanted(int millis) {
    final planted = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateTime.now().difference(planted).inDays;
  }

  Future<String> _fetchPlantAdvice({
    required String plantName,
    required String city,
    required String growthStage,
    required int daysSincePlanted,
  }) async {
    final uri = Uri.parse(
      "$backendUrl?plant_name=${Uri.encodeComponent(plantName)}"
      "&location=${Uri.encodeComponent(city)}"
      "&growth_stage=${Uri.encodeComponent(growthStage)}"
      "&days_since_planted=$daysSincePlanted",
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['plant_care_advice'] ?? "No advice received.";
      }
      return "Error: Unable to fetch advice.";
    } catch (e) {
      return "Error: $e";
    }
  }

  bool _isTaskChecked(
    Map<String, dynamic> completed,
    String task, {
    required bool isWeekly,
  }) {
    if (!completed.containsKey(task)) return false;
    final parts = (completed[task] as String).split('-');
    if (parts.length != 3) return false;
    final date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final now = DateTime.now();
    if (isWeekly) return now.difference(date).inDays < 7;
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  int _getLevelUpThreshold(int lvl) => 20 + (lvl - 1) * 5;

  Future<void> _toggleTask(
    String plantId,
    String task,
    bool checked, {
    required bool isWeekly,
  }) async {
    final plantDoc =
        FirebaseFirestore.instance.collection('plants').doc(plantId);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    if (checked) {
      await plantDoc.set(
        {'completedTasks': {task: todayStr}},
        SetOptions(merge: true),
      );
      final xpGain = isWeekly ? 10 : 5;
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(userDoc);
        int xp = (snap.data()?['xp'] ?? 0) as int;
        int lvl = (snap.data()?['level'] ?? 1) as int;
        xp += xpGain;
        while (xp >= _getLevelUpThreshold(lvl)) {
          xp -= _getLevelUpThreshold(lvl);
          lvl++;
          Future.delayed(
              const Duration(milliseconds: 300), () => _showLevelUpPopup(lvl));
        }
        tx.update(userDoc, {'xp': xp, 'level': lvl});
      });
    } else {
      await plantDoc.update({'completedTasks.$task': FieldValue.delete()});
    }
  }

  void _showLevelUpPopup(int lvl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 60),
              const SizedBox(height: 16),
              Text('Level Up!',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700)),
              const SizedBox(height: 8),
              Text('You’ve reached level $lvl 🎉',
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700),
                child: const Text('Awesome!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSuggestion({
    required String plantId,
    required String plantName,
    required String city,
    required String growthStage,
    required int daysSincePlanted,
  }) {
    setState(() => _loadingAdvice[plantId] = true);
    _fetchPlantAdvice(
      plantName: plantName,
      city: city,
      growthStage: growthStage,
      daysSincePlanted: daysSincePlanted,
    ).then((advice) {
      setState(() {
        _adviceCache[plantId] = advice;
        _loadingAdvice[plantId] = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: Text('Please sign in to view your plants.')),
      );
    }
    final userId = user.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const MenuPage(),
      bottomNavigationBar: Container(
        width: double.infinity,
        height: 70,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bottom_bar.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top banner
            Container(
              width: double.infinity,
              height: 112,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/top_bar.png'),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 2),
                child: Stack(
                  children: [
                    Positioned(
                      left: -8,
                      top: 18,
                      child: Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: Column(
                        children: [
                          SizedBox(height: 15),
                          Center(
                            child: Text('Plant Growth',
                                style:
                                    TextStyle(color: Colors.white, fontSize: 17)),
                          ),
                          SizedBox(height: 0),
                          Text('Analysis',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Plants list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('plants')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No plants found.'));
                  }
                  final plants = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: plants.length,
                    itemBuilder: (context, index) {
                      final plantData =
                          plants[index].data() as Map<String, dynamic>;
                      final plantId = plants[index].id;
                      final plantNameRaw = (plantData['plantName'] ?? '') as String;
                      final plantName = plantNameRaw.toLowerCase();
                      final growthStage = plantData['growthStage'] ?? 'N/A';
                      final city = plantData['city'] ?? 'Unknown City';
                      final createdAt = plantData['createdAtLocal'] ?? 0;
                      final daysSincePlanted =
                          _calculateDaysSincePlanted(createdAt);
                      final isExpanded = _expandedPlantId == plantId;
                      final imageAsset = _getImageAsset(plantName);
                      final completedTasksMap =
                          (plantData['completedTasks'] is Map<String, dynamic>)
                              ? plantData['completedTasks']
                                  as Map<String, dynamic>
                              : {};
                      final tasks =
                          plantTasks[plantName] ?? plantTasks['other']!;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          color: const Color(0xFFEAF5EA),
                          elevation: 2,
                          child: Column(
                            children: [
                              ListTile(
                                leading:
                                    Image.asset(imageAsset, width: 50, height: 50),
                                title: Text(
                                  plantNameRaw.toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Stage: $growthStage\nCity: $city\nPlanted: $daysSincePlanted day(s) ago',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.lightbulb,
                                          color: Colors.orange),
                                      onPressed: () {
                                        setState(() {
                                          _expandedPlantId = plantId;
                                          _loadingAdvice[plantId] = true;
                                        });
                                        _handleSuggestion(
                                          plantId: plantId,
                                          plantName: plantNameRaw,
                                          city: city,
                                          growthStage: growthStage,
                                          daysSincePlanted:
                                              daysSincePlanted,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more),
                                      color: Colors.green,
                                      onPressed: () {
                                        setState(() {
                                          _expandedPlantId =
                                              isExpanded ? null : plantId;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              if (isExpanded)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('🌿 Daily Tasks:',
                                          style: TextStyle(
                                              fontWeight:
                                                  FontWeight.bold)),
                                      ...tasks['daily']!.map((task) {
                                        final isChecked = _isTaskChecked(
                                            completedTasksMap.cast<String, dynamic>(), task,
                                            isWeekly: false);
                                        return CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text("• $task"),
                                          value: isChecked,
                                          onChanged: (val) {
                                            _toggleTask(
                                                plantId, task, val ?? false,
                                                isWeekly: false);
                                          },
                                        );
                                      }),
                                      const SizedBox(height: 8),
                                      const Text('🌱 Weekly Tasks:',
                                          style: TextStyle(
                                              fontWeight:
                                                  FontWeight.bold)),
                                      ...tasks['weekly']!.map((task) {
                                        final isChecked = _isTaskChecked(
                                            completedTasksMap.cast<String, dynamic>(), task,
                                            isWeekly: true);
                                        return CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text("• $task"),
                                          value: isChecked,
                                          onChanged: (val) {
                                            _toggleTask(
                                                plantId, task, val ?? false,
                                                isWeekly: true);
                                          },
                                        );
                                      }),
                                      if (_adviceCache.containsKey(plantId))
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 16.0),
                                          child: Text(
                                            "💡 Advice:\n${_adviceCache[plantId]}",
                                            style: const TextStyle(
                                                fontStyle:
                                                    FontStyle.italic),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
