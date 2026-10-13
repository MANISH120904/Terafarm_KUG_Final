import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
class PlantGrowthAnalysisPage extends StatefulWidget {
  const PlantGrowthAnalysisPage({Key? key}) : super(key: key);

  @override
  State<PlantGrowthAnalysisPage> createState() =>
      _PlantGrowthAnalysisPageState();
}

class _PlantGrowthAnalysisPageState extends State<PlantGrowthAnalysisPage> {
  String? _expandedPlantId;
  final Map<String, bool> _loadingAdvice = {};
  final Map<String, String> _adviceCache = {};

  // Updated plant tasks map (removed apple, added new plants)
  Map<String, Map<String, List<String>>> plantTasks = {
    'beans': {
      'daily': [
        'Water soil (keep moist)',
        'Ensure 6+ hrs of sunlight',
        'Check soil temperature',
      ],
      'weekly': [
        'Add compost or mulch',
        'Inspect for aphids',
        'Weed around base',
      ],
    },
    'tomato': {
      'daily': [
        'Water at base (avoid leaves)',
        'Check for curling leaves',
        'Ensure full sunlight exposure',
      ],
      'weekly': [
        'Apply balanced fertilizer',
        'Prune lower stems',
        'Inspect for pests',
      ],
    },
    'onion': {
      'daily': [
        'Water lightly',
        'Monitor bulb exposure',
        'Clear surrounding weeds',
      ],
      'weekly': [
        'Fertilize with nitrogen source',
        'Loosen surrounding soil',
        'Check for rot signs',
      ],
    },
    'strawberry': {
      'daily': [
        'Water in morning',
        'Check for slugs or snails',
        'Remove damaged leaves',
      ],
      'weekly': [
        'Fertilize with potassium-rich feed',
        'Mulch with straw or plastic',
        'Trim runners',
      ],
    },
    'lemon': {
      'daily': [
        'Check moisture level',
        'Inspect for pests (like aphids)',
        'Ensure 6-8 hrs sunlight',
      ],
      'weekly': [
        'Fertilize with citrus blend',
        'Prune dead branches',
        'Clean leaves (if dusty)',
      ],
    },
    'mulberry': {
      'daily': [
        'Water deeply (if soil is dry)',
        'Look for insect damage',
        'Observe leaf condition',
      ],
      'weekly': [
        'Apply compost or manure',
        'Thin overcrowded branches',
        'Check for scale insects',
      ],
    },
    'papaya': {
      'daily': [
        'Water base (avoid trunk)',
        'Inspect for whiteflies or mites',
        'Monitor leaf color',
      ],
      'weekly': [
        'Add compost or mulch',
        'Fertilize with NPK',
        'Remove yellowing leaves',
      ],
    },
    'pineapple': {
      'daily': [
        'Water soil (keep evenly moist)',
        'Check for rot at base',
        'Inspect leaves for pests',
      ],
      'weekly': [
        'Fertilize with fruit fertilizer',
        'Loosen surrounding soil',
        'Remove weeds nearby',
      ],
    },
    'egg plant': {
      'daily': [
        'Water deeply in morning',
        'Support heavy branches',
        'Check leaves for pests',
      ],
      'weekly': [
        'Apply nitrogen-rich fertilizer',
        'Prune lower leaves',
        'Inspect fruit for damage',
      ],
    },
    'mint': {
      'daily': [
        'Water regularly (keep moist)',
        'Pinch tips to encourage bushiness',
        'Check for mildew',
      ],
      'weekly': [
        'Harvest to promote growth',
        'Fertilize lightly',
        'Thin overcrowded shoots',
      ],
    },
    'spinach': {
      'daily': [
        'Water in early morning',
        'Check for bolting signs',
        'Protect from strong sun',
      ],
      'weekly': [
        'Harvest mature leaves',
        'Fertilize with compost tea',
        'Weed regularly',
      ],
    },
    'ginger': {
      'daily': [
        'Keep soil moist (not soggy)',
        'Check for fungal growth',
        'Remove yellowing leaves',
      ],
      'weekly': [
        'Add compost or mulch',
        'Fertilize with organic mix',
        'Ensure good drainage',
      ],
    },
    'alovera': {
      'daily': [
        'Check soil dryness',
        'Wipe dust off leaves',
        'Inspect for mealybugs',
      ],
      'weekly': [
        'Rotate for even sun exposure',
        'Trim dead leaves',
        'Avoid overwatering',
      ],
    },
    'garlic': {
      'daily': [
        'Water lightly (avoid soggy soil)',
        'Inspect leaves for yellowing',
        'Ensure full sun exposure',
      ],
      'weekly': [
        'Fertilize with nitrogen',
        'Remove competing weeds',
        'Loosen soil gently',
      ],
    },
    'other': {
      'daily': [
        'Water as needed',
        'Monitor health & color',
        'Check for visible pests',
      ],
      'weekly': [
        'Fertilize lightly',
        'Remove weeds',
        'Inspect for growth issues',
      ],
    },
  };

  /// Returns an asset image based on the crop name.
  String _getImageAsset(String cropName) {
    String lowerName = cropName.toLowerCase();
    if (lowerName.contains('tomato')) return 'assets/tomato1.png';
    if (lowerName.contains('beans')) return 'assets/beans1.png';
    if (lowerName.contains('onion')) return 'assets/onion.png';
    if (lowerName.contains('mint')) return 'assets/mint.png';
    if (lowerName.contains('spinach')) return 'assets/spinach.png';
    if (lowerName.contains('ginger')) return 'assets/ginger.png';
    if (lowerName.contains('garlic')) return 'assets/garlic.png';
    if (lowerName.contains('strawberry')) return 'assets/strawberry.png';
    if (lowerName.contains('papaya')) return 'assets/papaya.png';
    if (lowerName.contains('lemon')) return 'assets/lemon.png';
    if (lowerName.contains('pineapple')) return 'assets/pineapple.png';
    if (lowerName.contains('egg plant')) return 'assets/eggplant.png';
    if (lowerName.contains('alovera')) return 'assets/alovera.png';
    if (lowerName.contains('mulberry')) return 'assets/mulberry.png';
    return 'assets/default.png';
  }

  /// Returns the number of days since the plant was added.
  int _calculateDaysSincePlanted(int createdAtMillis) {
    DateTime planted = DateTime.fromMillisecondsSinceEpoch(createdAtMillis);
    return DateTime.now().difference(planted).inDays;
  }

  /// Local plant care advice (Cloud Run backend removed for hackathon demo).
  Future<String> _fetchPlantAdvice({
    required String plantName,
    required String city,
    required String growthStage,
    required int daysSincePlanted,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return 'For $plantName in $city ($growthStage, day $daysSincePlanted): '
        'keep soil evenly moist, give 6+ hours of light, and check leaves daily '
        'for pests. Follow the daily/weekly task list below for XP.';
  }

  /// Determines whether a task is marked as complete.
  /// Daily tasks are complete only if marked today;
  /// Weekly tasks are complete if marked within the past 7 days.
  bool _isTaskChecked(
    Map<String, dynamic> completedTasksMap,
    String task, {
    required bool isWeekly,
  }) {
    if (!completedTasksMap.containsKey(task)) return false;
    final parts = completedTasksMap[task].split('-');
    if (parts.length != 3) return false;
    final taskDate = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final now = DateTime.now();
    if (isWeekly) {
      return now.difference(taskDate).inDays < 7;
    } else {
      return taskDate.year == now.year &&
          taskDate.month == now.month &&
          taskDate.day == now.day;
    }
  }

  /// Returns the XP threshold for leveling up.
  /// The threshold increases by 5 with each new level.
  int _getLevelUpThreshold(int level) {
    return 20 + (level - 1) * 5;
  }

  /// Updates the task completion state and handles XP/level logic.
  Future<void> _toggleTask(
    String plantId,
    String task,
    bool isChecked, {
    required bool isWeekly,
  }) async {
    final plantDoc = FirebaseFirestore.instance
        .collection('plants')
        .doc(plantId);
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    if (isChecked) {
      // Mark the task as completed.
      await plantDoc.set({
        'completedTasks': {task: todayStr},
      }, SetOptions(merge: true));

      final int xpGain = isWeekly ? 10 : 5;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);
        int currentXp = snapshot.data()?['xp'] ?? 0;
        int currentLevel = snapshot.data()?['level'] ?? 1;
        int newXp = currentXp + xpGain;
        bool leveledUp = false;

        while (newXp >= _getLevelUpThreshold(currentLevel)) {
          newXp -= _getLevelUpThreshold(currentLevel);
          currentLevel++;
          leveledUp = true;
        }

        transaction.update(userDoc, {'xp': newXp, 'level': currentLevel});
        if (leveledUp) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _showLevelUpPopup(currentLevel);
          });
        }
      });
    } else {
      await plantDoc.update({'completedTasks.$task': FieldValue.delete()});
    }
  }

  /// Shows a level-up popup when the user levels up.
  void _showLevelUpPopup(int newLevel) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Colors.amber.shade700,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Level Up!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You’ve reached level $newLevel 🎉',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    child: const Text('Awesome!'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// Handles the fetching and caching of plant care advice.
  void _handleSuggestion({
    required String plantId,
    required String plantName,
    required String city,
    required String growthStage,
    required int daysSincePlanted,
  }) {
    setState(() {
      _loadingAdvice[plantId] = true;
    });
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
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true, // Show the back arrow
        iconTheme: const IconThemeData(color: Colors.white), // Make arrow white
        title: const Text(
          'Plant Growth Analysis',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade900,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
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
              final plantData = plants[index].data() as Map<String, dynamic>;
              final plantId = plants[index].id;
              final String plantNameRaw = (plantData['plantName'] ?? '');
              final String plantName = plantNameRaw.toLowerCase();
              final growthStage = plantData['growthStage'] ?? 'N/A';
              final city = plantData['city'] ?? 'Unknown City';
              final createdAt = plantData['createdAtLocal'] ?? 0;
              final int daysSincePlanted = _calculateDaysSincePlanted(
                createdAt,
              );
              final bool isExpanded = _expandedPlantId == plantId;
              final String imageAsset = _getImageAsset(plantName);

              final Map<String, dynamic> completedTasksMap =
                  (plantData['completedTasks'] is Map<String, dynamic>)
                      ? plantData['completedTasks'] as Map<String, dynamic>
                      : {};

              // Use tasks from the map; if not found, use 'other'.
              final tasks = plantTasks[plantName] ?? plantTasks['other']!;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Column(
                  children: [
                    ListTile(
                      leading: Image.asset(imageAsset, width: 50, height: 50),
                      title: Text(
                        plantNameRaw.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Stage: $growthStage\nCity: $city\nPlanted: $daysSincePlanted day(s) ago',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.lightbulb,
                              color: Colors.orange,
                            ),
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
                                daysSincePlanted: daysSincePlanted,
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.green,
                            ),
                            onPressed: () {
                              setState(() {
                                _expandedPlantId = isExpanded ? null : plantId;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🌿 Daily Tasks:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ...tasks['daily']!.map((task) {
                              final bool isChecked = _isTaskChecked(
                                completedTasksMap,
                                task,
                                isWeekly: false,
                              );
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text("• $task"),
                                value: isChecked,
                                onChanged: (bool? val) {
                                  _toggleTask(
                                    plantId,
                                    task,
                                    val ?? false,
                                    isWeekly: false,
                                  );
                                },
                              );
                            }).toList(),
                            const SizedBox(height: 8),
                            Text(
                              '🌱 Weekly Tasks:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ...tasks['weekly']!.map((task) {
                              final bool isChecked = _isTaskChecked(
                                completedTasksMap,
                                task,
                                isWeekly: true,
                              );
                              return CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text("• $task"),
                                value: isChecked,
                                onChanged: (bool? val) {
                                  _toggleTask(
                                    plantId,
                                    task,
                                    val ?? false,
                                    isWeekly: true,
                                  );
                                },
                              );
                            }).toList(),
                            if (_adviceCache.containsKey(plantId))
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Text(
                                  "💡 Advice:\n${_adviceCache[plantId]}",
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            // Growth Log Section
                            GrowthLogSection(plantId: plantId),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// GrowthLogSection widget that allows users to add growth logs and view a growth graph.
class GrowthLogSection extends StatefulWidget {
  final String plantId;
  const GrowthLogSection({required this.plantId, Key? key}) : super(key: key);

  @override
  State<GrowthLogSection> createState() => _GrowthLogSectionState();
}

class _GrowthLogSectionState extends State<GrowthLogSection> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Ensure an initial growth log exists.
    _ensureGrowthLogsExist();
  }

  Future<void> _ensureGrowthLogsExist() async {
    final growthLogsRef = FirebaseFirestore.instance
        .collection('plants')
        .doc(widget.plantId)
        .collection('growthLogs');
    final snapshot = await growthLogsRef.limit(1).get();
    if (snapshot.docs.isEmpty) {
      await growthLogsRef.add({
        'date': Timestamp.now(),
        'height': 0.0,
        'note': 'Initial growth log',
      });
    }
  }

  Future<void> _addGrowthLog() async {
    if (!mounted) return;
    final height = double.tryParse(_heightController.text);
    if (height == null || height <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid height > 0')),
      );
      return;
    }
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note cannot be empty')));
      return;
    }
    final log = {'date': Timestamp.now(), 'height': height, 'note': note};
    try {
      await FirebaseFirestore.instance
          .collection('plants')
          .doc(widget.plantId)
          .collection('growthLogs')
          .add(log);
      if (!mounted) return;
      setState(() {
        _heightController.clear();
        _noteController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add log: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text(
          "📏 Growth Tracker",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: _addGrowthLog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('plants')
                  .doc(widget.plantId)
                  .collection('growthLogs')
                  .orderBy('date')
                  .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final logs = snapshot.data!.docs;
            if (logs.isEmpty) return const Text("No growth logs yet.");
            // Create sorted data points for the graph.
            final List<FlSpot> dataPoints =
                logs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final rawHeight = data['height'];
                    final rawDate = data['date'];
                    final height =
                        (rawHeight is num) ? rawHeight.toDouble() : 0.0;
                    final date = (rawDate as Timestamp).toDate();
                    return FlSpot(
                      date.millisecondsSinceEpoch.toDouble(),
                      height,
                    );
                  }).toList()
                  ..sort((a, b) => a.x.compareTo(b.x));
            // If less than 2 points, show message.
            if (dataPoints.length < 2) {
              return const Text("Add more data points to view graph.");
            }
            // Calculate a safe y-axis interval.
            final double maxY = dataPoints.map((e) => e.y).reduce(max);
            final double intervalY = (maxY / 5).clamp(1, double.infinity);

            // Create x-axis labels based on date.
            final List<String> labels =
                logs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final date = (data['date'] as Timestamp).toDate();
                  return "${date.month}/${date.day}";
                }).toList();

            return Column(
              children: [
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY + 5,
                      lineBarsData: [
                        LineChartBarData(
                          spots: dataPoints,
                          isCurved: true,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                          color: Colors.green,
                        ),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final int index = value.toInt();
                              // Safeguard against index overflow.
                              if (index < 0 || index >= labels.length)
                                return const Text('');
                              return Text(
                                labels[index],
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: intervalY,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                "${value.toInt()} cm",
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: true),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...logs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final height = (data['height'] as num?)?.toDouble() ?? 0.0;
                  final note = data['note'] ?? '';
                  final date = (data['date'] as Timestamp).toDate();
                  return ListTile(
                    dense: true,
                    title: Text(
                      "📅 ${date.month}/${date.day}/${date.year} — 🌱 ${height.toStringAsFixed(1)} cm",
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      "📝 $note",
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }).toList(),
              ],
            );
          },
        ),
      ],
    );
  }
}