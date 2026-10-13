import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewPage extends StatefulWidget {
  final String farmId;
  const ReviewPage({Key? key, required this.farmId}) : super(key: key);

  @override
  _ReviewPageState createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  int _filterStar = 0; // 0 = all, 1..5 = specific star
  final TextEditingController _commentController = TextEditingController();
  int _userRating = 0;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final ratingsRef = FirebaseFirestore.instance
        .collection('farms')
        .doc(widget.farmId)
        .collection('ratings');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reviews"),
        backgroundColor: Colors.green.shade900,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Review Submission ─────────────────────
            const Text("Rate this farm:", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _userRating ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                  ),
                  onPressed: () => setState(() => _userRating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Leave a comment (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitRating,
              icon: const Icon(Icons.send),
              label:
                  _isSubmitting
                      ? const Text("Submitting...")
                      : const Text("Submit Review"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade900,
              ),
            ),
            const SizedBox(height: 24),

            // ── Reviews Stream ─────────────────────
            StreamBuilder<QuerySnapshot>(
              stream:
                  ratingsRef.orderBy('timestamp', descending: true).snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());

                final docs = snap.data!.docs;
                if (docs.isEmpty)
                  return const Center(child: Text("No reviews yet."));

                // compute summary
                final counts = List<int>.filled(6, 0);
                double total = 0;
                for (var d in docs) {
                  final r = (d['rating'] as num).toInt();
                  counts[r] += 1;
                  total += r;
                }
                final avg = (total / docs.length);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Summary Header ─────────────────────
                    Text(
                      avg.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => const Icon(
                          Icons.star,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${docs.length} ratings",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // ── Histogram ─────────────────────
                    ...List.generate(5, (i) {
                      final star = 5 - i;
                      final count = counts[star];
                      final pct = count / docs.length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text("$star", style: const TextStyle(fontSize: 12)),
                            const Icon(
                              Icons.star,
                              color: Colors.orange,
                              size: 12,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    height: 8,
                                    color: Colors.grey.shade300,
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: pct,
                                    child: Container(
                                      height: 8,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              count.toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),

                    // ── Filter Chips ─────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip("All", 0),
                          for (int s = 5; s >= 1; s--)
                            _buildFilterChip("$s★", s),
                        ],
                      ),
                    ),
                    const Divider(height: 32),

                    // ── Review List ─────────────────────
                    ...docs
                        .where((d) {
                          if (_filterStar == 0) return true;
                          return (d['rating'] as num).toInt() == _filterStar;
                        })
                        .map((d) {
                          final data = d.data()! as Map<String, dynamic>;
                          final stars = (data['rating'] as num).toInt();
                          final comment = data['comment'] as String? ?? '';
                          final ts =
                              (data['timestamp'] as Timestamp?)?.toDate();
                          final dateTxt =
                              ts == null
                                  ? ""
                                  : "${ts.day}/${ts.month}/${ts.year}";
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: List.generate(
                                    5,
                                    (j) => Icon(
                                      j < stars
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(comment),
                                ],
                                if (dateTxt.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    dateTxt,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const Divider(),
                              ],
                            ),
                          );
                        })
                        .toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int starValue) {
    final isSelected = _filterStar == starValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _filterStar = starValue),
      ),
    );
  }

  Future<void> _submitRating() async {
    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a star rating.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final userId =
        "demo_user"; // Replace with FirebaseAuth.instance.currentUser!.uid
    final farmRef = FirebaseFirestore.instance
        .collection('farms')
        .doc(widget.farmId);
    final ratingRef = farmRef.collection('ratings').doc(userId);

    await ratingRef.set({
      'rating': _userRating,
      'comment': _commentController.text.trim(),
      'userId': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final ratingsSnap = await farmRef.collection('ratings').get();
    final allRatings =
        ratingsSnap.docs.map((d) => (d['rating'] as num).toDouble()).toList();
    final avg = allRatings.reduce((a, b) => a + b) / allRatings.length;

    await farmRef.update({'rating': avg});

    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Thank you for your feedback!")),
    );

    Navigator.of(context).pop(true);
  }
}
