import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/gemma_ai_service.dart';
import 'services/model_download_manager.dart';
import 'theme/tera_farm_theme.dart';
import 'widgets/tera_farm_scaffold.dart';

class OfflineDiagnosisPage extends StatefulWidget {
  const OfflineDiagnosisPage({Key? key}) : super(key: key);

  @override
  _OfflineDiagnosisPageState createState() => _OfflineDiagnosisPageState();
}

class _OfflineDiagnosisPageState extends State<OfflineDiagnosisPage>
    with TickerProviderStateMixin {
  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  bool _isModelLoaded = false;
  String _modelStatus = 'Checking AI models...';
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  final ImagePicker _picker = ImagePicker();
  final GemmaAIService _aiService = GemmaAIService();
  final ModelDownloadManager _modelManager = ModelDownloadManager();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkAndInitializeModels();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _slideController.forward();
  }

  Future<void> _checkAndInitializeModels() async {
    setState(() {
      _modelStatus = 'Checking required permissions...';
    });

    // Request storage permission
    final storagePermission = await Permission.storage.request();
    if (!storagePermission.isGranted) {
      setState(() {
        _modelStatus = 'Storage permission required for model downloads';
      });
      return;
    }

    setState(() {
      _modelStatus = 'Checking AI models availability...';
    });

    // Check if Gemma model is available
    final isGemmaAvailable = await _modelManager.isModelAvailable('gemma_2b_it.bin');
    final isLabelsAvailable = await _modelManager.isModelAvailable('plant_disease_labels.txt');

    if (isGemmaAvailable && isLabelsAvailable) {
      await _initializeAI();
    } else {
      setState(() {
        _modelStatus = 'AI models need to be downloaded';
      });
      _showDownloadDialog();
    }
  }

  Future<void> _initializeAI() async {
    setState(() {
      _modelStatus = 'Initializing AI models...';
    });

    try {
      final success = await _aiService.initializeGemma();
      if (success) {
        setState(() {
          _isModelLoaded = true;
          _modelStatus = 'AI models ready';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Gemma AI initialized successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Failed to initialize Gemma AI');
      }
    } catch (e) {
      print('Error initializing AI: $e');
      setState(() {
        _isModelLoaded = false;
        _modelStatus = 'AI initialization failed: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to load AI model: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _initializeAI(),
            ),
          ),
        );
      }
    }
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.download, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Download AI Models'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('AI models need to be downloaded for offline analysis. This is a one-time setup.'),
                  SizedBox(height: 16),
                  if (_isDownloading) ...[
                    LinearProgressIndicator(value: _downloadProgress),
                    SizedBox(height: 8),
                    Text('${(_downloadProgress * 100).toInt()}% downloaded'),
                  ],
                ],
              ),
              actions: [
                if (!_isDownloading)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                ElevatedButton(
                  onPressed: _isDownloading ? null : () => _downloadModels(setDialogState),
                  child: Text(_isDownloading ? 'Downloading...' : 'Download'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _downloadModels(StateSetter setDialogState) async {
    setDialogState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      // For demonstration, we'll simulate the download
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(Duration(milliseconds: 200));
        setDialogState(() {
          _downloadProgress = i / 100.0;
        });
      }

      // Initialize AI
      await _initializeAI();

      Navigator.of(context).pop();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setDialogState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _analysisResult = null; // Clear previous results
        });
        
        // Auto-analyze the image
        await _analyzeWithGemma();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _analyzeWithGemma() async {
    if (_selectedImage == null || !_isModelLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI not ready or no image selected'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      // Read image bytes
      final imageBytes = await _selectedImage!.readAsBytes();
      
      // Analyze with Gemma AI
      final result = await _aiService.analyzePlantDisease(
        imageBytes: imageBytes,
        plantType: 'Unknown', // Could be enhanced with plant type detection
        symptoms: 'Visible symptoms in uploaded image',
        growthStage: 'Unknown',
        conditions: 'Standard growing conditions',
      );

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });
      
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      print('Inference error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeraFarmScaffold(
      mode: TeraFarmScaffoldMode.inner,
      title: 'Offline Plant Doctor',
      backgroundColor: TeraFarmColors.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isModelLoaded 
                    ? [Colors.green.shade50, Colors.green.shade100]
                    : [Colors.orange.shade50, Colors.orange.shade100],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isModelLoaded ? Colors.green.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isModelLoaded ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isModelLoaded ? Icons.smart_toy : Icons.download,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isModelLoaded ? 'Gemma AI Ready' : _modelStatus,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isModelLoaded ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _isModelLoaded 
                            ? 'Offline plant disease detection with AI-powered analysis'
                            : 'Downloading and initializing AI models for offline use',
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
            SizedBox(height: 20),
            
            // Image Section
            _buildImageSection(),
            SizedBox(height: 20),
            
            // Analysis Results
            if (_analysisResult != null) 
              _buildGemmaResultsSection(),
            
            // Action Buttons
            if (_selectedImage == null) 
              _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: _selectedImage == null
          ? _buildImagePlaceholder()
          : _buildSelectedImage(),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate,
          size: 80,
          color: Colors.grey.shade300,
        ),
        SizedBox(height: 16),
        Text(
          'Select an image to analyze',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Take a photo or choose from gallery',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            _selectedImage!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        if (_isAnalyzing)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(Colors.green),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing with Gemma AI...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () => setState(() {
                _selectedImage = null;
                _analysisResult = null;
              }),
              icon: Icon(Icons.close, color: Colors.grey.shade600),
              iconSize: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGemmaResultsSection() {
    if (_analysisResult == null) return SizedBox.shrink();
    
    return SlideTransition(
      position: _slideAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Analysis Result Card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor(_analysisResult!['confidence']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.medical_services,
                        color: _getConfidenceColor(_analysisResult!['confidence']),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Diagnosis',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Powered by Gemma AI',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor(_analysisResult!['confidence']),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_analysisResult!['confidence']}%',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                // Disease Name
                Text(
                  'Disease Identified:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _analysisResult!['disease'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 16),

                // Symptoms
                if (_analysisResult!['symptoms'] != null) ...[
                  Text(
                    'Key Symptoms:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _analysisResult!['symptoms'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                // Treatment
                if (_analysisResult!['treatment'] != null) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_pharmacy, color: Colors.green.shade700, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Recommended Treatment:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          _analysisResult!['treatment'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                // Prevention
                if (_analysisResult!['prevention'] != null) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield, color: Colors.blue.shade700, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Prevention Measures:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          _analysisResult!['prevention'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16),
          
          // Action Buttons for retaking
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: Icon(Icons.camera_alt),
                  label: Text('Take Another'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: Icon(Icons.photo_library),
                  label: Text('Choose Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Camera Button
        Container(
          width: double.infinity,
          height: 60,
          margin: EdgeInsets.only(bottom: 12),
          child: ElevatedButton.icon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: Icon(Icons.camera_alt, size: 28),
            label: Text(
              'Take Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ),
        
        // Gallery Button
        Container(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: Icon(Icons.photo_library, size: 28),
            label: Text(
              'Choose from Gallery',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _aiService.dispose();
    super.dispose();
  }
}
