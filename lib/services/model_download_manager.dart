import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class ModelDownloadManager {
  static final ModelDownloadManager _instance = ModelDownloadManager._internal();
  factory ModelDownloadManager() => _instance;
  ModelDownloadManager._internal();

  final Dio _dio = Dio();
  
  // Model URLs (replace with your actual model URLs)
  static const String PLANT_DISEASE_MODEL_URL = 'https://your-server.com/models/plant_disease_model.tflite';
  static const String GEMMA_MODEL_URL = 'https://your-server.com/models/gemma_2b_it.bin';
  static const String PLANT_LABELS_URL = 'https://your-server.com/models/plant_disease_labels.txt';
  
  Future<String> getExternalStorageDir() async {
    final directory = await getExternalStorageDirectory();
    final modelDir = Directory('${directory!.path}/ai_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir.path;
  }

  Future<File?> downloadModel({
    required String url,
    required String fileName,
    required Function(double) onProgress,
    required BuildContext context,
  }) async {
    try {
      final modelDir = await getExternalStorageDir();
      final filePath = '$modelDir/$fileName';
      final file = File(filePath);
      
      // Check if model already exists
      if (await file.exists()) {
        return file;
      }

      // Download with progress tracking
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );
      
      return file;
    } catch (e) {
      print('Error downloading model: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download $fileName: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<bool> isModelAvailable(String fileName) async {
    try {
      final modelDir = await getExternalStorageDir();
      final file = File('$modelDir/$fileName');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  Future<String?> getModelPath(String fileName) async {
    try {
      final modelDir = await getExternalStorageDir();
      final filePath = '$modelDir/$fileName';
      final file = File(filePath);
      
      if (await file.exists()) {
        return filePath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteModel(String fileName) async {
    try {
      final modelDir = await getExternalStorageDir();
      final file = File('$modelDir/$fileName');
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting model: $e');
    }
  }

  Future<double> getModelSize(String fileName) async {
    try {
      final modelDir = await getExternalStorageDir();
      final file = File('$modelDir/$fileName');
      
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.size / (1024 * 1024); // Return size in MB
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }
}
