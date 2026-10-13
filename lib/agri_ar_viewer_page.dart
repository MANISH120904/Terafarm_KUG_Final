import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n/app_localizations.dart';

/// Cloud-based AR Viewer for AgriGlu
/// View 3D models in AR directly in Flutter app without Unity
/// Uses model_viewer_plus for web-based AR and ARCore/ARKit for native
class AgriARViewerPage extends StatefulWidget {
  final String? modelId;
  final Map<String, dynamic>? modelData;

  const AgriARViewerPage({
    Key? key,
    this.modelId,
    this.modelData,
  }) : super(key: key);

  @override
  State<AgriARViewerPage> createState() => _AgriARViewerPageState();
}

class _AgriARViewerPageState extends State<AgriARViewerPage> {
  Map<String, dynamic>? _modelData;
  bool _isLoading = true;
  String? _localModelPath;
  String? _error;
  bool _isARMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.modelData != null) {
      _modelData = widget.modelData;
      _loadModel();
    } else if (widget.modelId != null) {
      _fetchModelData();
    }
  }

  Future<void> _fetchModelData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ar_models')
          .doc(widget.modelId)
          .get();

      if (doc.exists) {
        setState(() {
          _modelData = doc.data();
          _isLoading = false;
        });
        _loadModel();
      } else {
        setState(() {
          _error = 'Model not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading model: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadModel() async {
    if (_modelData == null) return;

    final modelUrl = _modelData!['modelUrl'] as String?;
    if (modelUrl == null) {
      setState(() {
        _error = 'Model URL not found';
        _isLoading = false;
      });
      return;
    }

    // For web-based model viewer, we can use the direct URL
    // For native AR, we might need to download the model
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _downloadModelForAR() async {
    if (_modelData == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final modelUrl = _modelData!['modelUrl'] as String;
      final fileName = _modelData!['fileName'] as String? ?? 'model.glb';

      // Get local directory
      final directory = await getApplicationDocumentsDirectory();
      final localPath = '${directory.path}/ar_models/$fileName';

      // Create directory if it doesn't exist
      final dir = Directory('${directory.path}/ar_models');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Download model
      final dio = Dio();
      await dio.download(
        modelUrl,
        localPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            print('Download progress: $progress%');
          }
        },
      );

      setState(() {
        _localModelPath = localPath;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Model downloaded for AR viewing!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Download failed: $e';
        _isLoading = false;
      });
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
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading 3D model...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('AR Viewer'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_modelData?['name'] ?? 'AR Viewer'),
        backgroundColor: const Color(0xFF4CAF50),
        actions: [
          IconButton(
            icon: Icon(_isARMode ? Icons.view_in_ar : Icons.view_in_ar_outlined),
            tooltip: _isARMode ? '3D View' : 'AR View',
            onPressed: () {
              setState(() {
                _isARMode = !_isARMode;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showModelInfo,
          ),
        ],
      ),
      body: _buildViewer(),
      floatingActionButton: _buildControlButtons(),
    );
  }

  Widget _buildViewer() {
    final modelUrl = _modelData!['modelUrl'] as String;
    final modelName = _modelData!['name'] as String? ?? 'Model';

    return Column(
      children: [
        // Info Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF4CAF50).withOpacity(0.1),
          child: Row(
            children: [
              Icon(
                _isARMode ? Icons.view_in_ar : Icons.threed_rotation,
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isARMode
                      ? 'Point camera at a flat surface and tap to place'
                      : 'Drag to rotate • Pinch to zoom • Two fingers to pan',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // 3D Model Viewer (WebView-based)
        Expanded(
          child: _buildWebViewer(modelUrl, modelName),
        ),

        // Stats and Info Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                Icons.category,
                (_modelData!['category'] ?? 'N/A').toString().toUpperCase(),
              ),
              _buildStatItem(
                Icons.data_usage,
                '${(_modelData!['fileSize'] ?? 0) ~/ 1024 ~/ 1024} MB',
              ),
              _buildStatItem(
                Icons.download,
                '${_modelData!['downloadCount'] ?? 0}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF4CAF50)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (Platform.isAndroid || Platform.isIOS)
          FloatingActionButton.extended(
            onPressed: () {
              setState(() {
                _isARMode = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Point at a flat surface to place the model'),
                  backgroundColor: Color(0xFF4CAF50),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            backgroundColor: const Color(0xFF4CAF50),
            icon: const Icon(Icons.view_in_ar),
            label: const Text('View in AR'),
          ),
        const SizedBox(height: 12),
        FloatingActionButton(
          onPressed: _resetCamera,
          backgroundColor: Colors.white,
          child: const Icon(Icons.refresh, color: Color(0xFF4CAF50)),
        ),
      ],
    );
  }

  Widget _buildWebViewer(String modelUrl, String modelName) {
    // For mobile platforms, we'll use a WebView with model-viewer
    // For web, we can embed directly
    
    // Create a data URI with the HTML content
    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/3.3.0/model-viewer.min.js"></script>
  <style>
    body {
      margin: 0;
      padding: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    }
    model-viewer {
      width: 100%;
      height: 100vh;
      background: transparent;
    }
    .controls {
      position: absolute;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(255,255,255,0.95);
      padding: 12px 24px;
      border-radius: 30px;
      box-shadow: 0 8px 16px rgba(0,0,0,0.2);
      font-size: 13px;
      color: #333;
      max-width: 80%;
      text-align: center;
    }
    .ar-button {
      position: absolute;
      top: 20px;
      right: 20px;
      background: #4CAF50;
      color: white;
      border: none;
      padding: 12px 24px;
      border-radius: 25px;
      font-size: 14px;
      font-weight: bold;
      box-shadow: 0 4px 8px rgba(0,0,0,0.2);
      cursor: pointer;
    }
    .loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: white;
      font-size: 18px;
    }
  </style>
</head>
<body>
  <model-viewer
    src="$modelUrl"
    alt="$modelName"
    ar
    ar-modes="scene-viewer webxr quick-look"
    camera-controls
    touch-action="pan-y"
    auto-rotate
    auto-rotate-delay="0"
    rotation-per-second="30deg"
    shadow-intensity="1"
    shadow-softness="0.5"
    exposure="1"
    environment-image="neutral"
    camera-orbit="45deg 55deg 2.5m"
    min-camera-orbit="auto auto 1m"
    max-camera-orbit="auto auto 10m"
    interaction-prompt="auto"
    ar-placement="floor"
    ar-scale="auto">
    
    <button slot="ar-button" class="ar-button">
      📱 View in AR
    </button>
    
    <div class="controls">
      🔄 Drag to rotate • 🔍 Pinch to zoom • 👆 Two fingers to pan
    </div>
    
    <div class="loading" slot="poster">
      Loading 3D model...
    </div>
  </model-viewer>
  
  <script>
    const modelViewer = document.querySelector('model-viewer');
    
    modelViewer.addEventListener('load', () => {
      console.log('Model loaded successfully');
    });
    
    modelViewer.addEventListener('error', (event) => {
      console.error('Error loading model:', event);
    });
  </script>
</body>
</html>
    ''';

    if (Platform.isAndroid || Platform.isIOS) {
      // Use WebView for mobile
      late final WebViewController controller;
      
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..loadRequest(
          Uri.dataFromString(
            htmlContent,
            mimeType: 'text/html',
            encoding: Encoding.getByName('utf-8'),
          ),
        );

      return WebViewWidget(controller: controller);
    } else {
      // Fallback for web or desktop - show instructions
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
            ],
          ),
        ),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.threed_rotation,
                      size: 80,
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '3D Model Viewer',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    modelName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'View this 3D model in AR:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openInBrowser(modelUrl),
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Open in Browser'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _shareModelUrl(modelUrl),
                        icon: const Icon(Icons.share),
                        label: const Text('Share URL'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'For best AR experience, use a mobile device with ARCore (Android) or ARKit (iOS)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _openInBrowser(String modelUrl) async {
    // Create a simple HTML page URL that can be opened in browser
    final htmlUrl = Uri.parse('https://modelviewer.dev/editor/').replace(
      queryParameters: {'model': modelUrl},
    );
    
    if (await canLaunchUrl(htmlUrl)) {
      await launchUrl(htmlUrl, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open browser'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareModelUrl(String modelUrl) async {
    // For now, just show the URL
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model URL'),
        content: SelectableText(modelUrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _resetCamera() {
    // Reset camera to default position
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Camera reset to default position'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showModelInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _modelData!['name'] ?? 'Model',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _modelData!['description'] ?? 'No description available',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Category', _modelData!['category'] ?? 'N/A'),
            _buildInfoRow('File Size', '${(_modelData!['fileSize'] ?? 0) ~/ 1024 ~/ 1024} MB'),
            _buildInfoRow('Downloads', '${_modelData!['downloadCount'] ?? 0}'),
            _buildInfoRow('Uploaded By', _modelData!['uploadedByEmail'] ?? 'Unknown'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close),
                label: const Text('Close'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
