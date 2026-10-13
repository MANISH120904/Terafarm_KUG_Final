import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'l10n/app_localizations.dart';

/// Unity AR Launcher - Seamless integration with Unity AR app
/// Launches Unity app with deep links to view specific models
/// Supports Cloud Anchors for persistent multi-user AR experiences
class UnityARLauncherPage extends StatefulWidget {
  final String? modelId;
  final Map<String, dynamic>? modelData;

  const UnityARLauncherPage({
    Key? key,
    this.modelId,
    this.modelData,
  }) : super(key: key);

  @override
  State<UnityARLauncherPage> createState() => _UnityARLauncherPageState();
}

class _UnityARLauncherPageState extends State<UnityARLauncherPage> {
  Map<String, dynamic>? _modelData;
  bool _isLoading = true;
  List<Map<String, dynamic>> _cloudAnchors = [];
  bool _isLoadingAnchors = false;

  // Unity deep link scheme
  static const String UNITY_SCHEME = 'agriar';
  static const String UNITY_PACKAGE_ANDROID = 'com.agriglu.agriar';
  static const String UNITY_BUNDLE_IOS = 'com.agriglu.agriar';

  @override
  void initState() {
    super.initState();
    if (widget.modelData != null) {
      _modelData = widget.modelData;
      _isLoading = false;
    } else if (widget.modelId != null) {
      _fetchModelData();
    }
    _loadCloudAnchors();
  }

  Future<void> _fetchModelData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ar_models')
          .doc(widget.modelId)
          .get();

      if (doc.exists) {
        setState(() {
          _modelData = {...doc.data()!, 'id': doc.id};
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load model: $e');
    }
  }

  Future<void> _loadCloudAnchors() async {
    setState(() {
      _isLoadingAnchors = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('cloud_anchors')
          .where('isActive', isEqualTo: true)
          .where('modelId', isEqualTo: widget.modelId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      setState(() {
        _cloudAnchors = snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        _isLoadingAnchors = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAnchors = false;
      });
      debugPrint('Failed to load cloud anchors: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('AR Viewer'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_modelData?['name'] ?? 'AR Viewer'),
        backgroundColor: const Color(0xFF4CAF50),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareModel,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildModelPreview(),
            _buildAROptions(),
            _buildCloudAnchorsSection(),
            _buildInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildModelPreview() {
    final thumbnailUrl = _modelData?['thumbnailUrl'] as String?;
    final name = _modelData?['name'] ?? 'Unknown Model';
    final category = _modelData?['category'] ?? 'other';
    final description = _modelData?['description'] ?? '';

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                image: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(thumbnailUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: thumbnailUrl == null || thumbnailUrl.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.view_in_ar,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                    )
                  : null,
            ),

            // Info
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAROptions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'View in AR',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // New Placement
          _buildAROptionCard(
            title: 'Place New Model',
            subtitle: 'Create a new AR placement in your location',
            icon: Icons.add_location,
            color: const Color(0xFF4CAF50),
            onTap: () => _launchUnityAR(mode: 'host'),
          ),

          const SizedBox(height: 12),

          // View Existing Cloud Anchors
          _buildAROptionCard(
            title: 'View Shared Models',
            subtitle: 'See models placed by others nearby',
            icon: Icons.cloud,
            color: const Color(0xFF2196F3),
            onTap: () => _launchUnityAR(mode: 'resolve'),
          ),

          const SizedBox(height: 12),

          // Quick View (no cloud anchor)
          _buildAROptionCard(
            title: 'Quick Preview',
            subtitle: 'View model in AR (temporary, not saved)',
            icon: Icons.visibility,
            color: const Color(0xFFFF9800),
            onTap: () => _launchUnityAR(mode: 'preview'),
          ),
        ],
      ),
    );
  }

  Widget _buildAROptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloudAnchorsSection() {
    if (_cloudAnchors.isEmpty && !_isLoadingAnchors) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saved Locations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _loadCloudAnchors,
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingAnchors)
            const Center(child: CircularProgressIndicator())
          else
            ..._cloudAnchors.map((anchor) => _buildCloudAnchorCard(anchor)),
        ],
      ),
    );
  }

  Widget _buildCloudAnchorCard(Map<String, dynamic> anchor) {
    final createdAt = (anchor['createdAt'] as Timestamp?)?.toDate();
    final locationName = anchor['locationName'] ?? 'Unknown Location';
    final createdBy = anchor['createdBy'] ?? 'Anonymous';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.location_on, color: Color(0xFF4CAF50)),
        ),
        title: Text(locationName),
        subtitle: Text(
          createdAt != null
              ? 'Created ${_formatTimeAgo(createdAt)}'
              : 'Unknown time',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.launch),
          onPressed: () => _launchUnityAR(
            mode: 'resolve',
            anchorId: anchor['anchorId'],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'How it works',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(
            '1',
            'Install Unity AR App',
            'Download the AgriAR Unity app from Play Store/App Store',
          ),
          _buildInstructionStep(
            '2',
            'Choose AR Mode',
            'Place new model or view existing shared models',
          ),
          _buildInstructionStep(
            '3',
            'Point at Surface',
            'Point your camera at a flat surface (floor, table)',
          ),
          _buildInstructionStep(
            '4',
            'Place & Share',
            'Tap to place. Others can see your placement using Cloud Anchors!',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUnityAR({
    required String mode,
    String? anchorId,
  }) async {
    if (_modelData == null) {
      _showError('Model data not available');
      return;
    }

    final modelId = _modelData!['id'] ?? widget.modelId;
    
    // Build deep link URL
    // Format: agriar://view?modelId=xxx&mode=host|resolve|preview&anchorId=xxx
    String deepLink = '$UNITY_SCHEME://view?modelId=$modelId&mode=$mode';
    
    if (anchorId != null) {
      deepLink += '&anchorId=$anchorId';
    }

    try {
      final Uri uri = Uri.parse(deepLink);
      
      // Try to launch Unity app
      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Unity app not installed, show install dialog
        _showInstallDialog();
      }
    } catch (e) {
      debugPrint('Failed to launch Unity AR: $e');
      _showInstallDialog();
    }
  }

  void _showInstallDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Install AgriAR App'),
        content: const Text(
          'The AgriAR Unity app is required to view models in AR.\n\n'
          'Would you like to download it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Open app store
              String storeUrl = Platform.isAndroid
                  ? 'https://play.google.com/store/apps/details?id=$UNITY_PACKAGE_ANDROID'
                  : 'https://apps.apple.com/app/id$UNITY_BUNDLE_IOS';
              
              final uri = Uri.parse(storeUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _shareModel() {
    final modelName = _modelData?['name'] ?? 'AR Model';
    final modelId = _modelData?['id'] ?? widget.modelId;
    
    final shareText = '🌾 Check out this $modelName in AR!\n\n'
        'View it in augmented reality using AgriAR app:\n'
        'agriar://view?modelId=$modelId&mode=preview\n\n'
        'Download AgriAR: [App Store Link]';
    
    Share.share(shareText);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year(s) ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month(s) ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else {
      return 'Just now';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
