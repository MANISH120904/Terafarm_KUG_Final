import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../config/api_keys.dart';

/// Uploads farm listing photos with free alternatives when Firebase Storage
/// is unavailable (Spark plan / object-not-found).
///
/// Order: Firebase Storage → ImgBB (if key) → Catbox (no key) → fail.
class FarmImageUploadService {
  static Future<FarmImageUploadResult> upload(File file) async {
    final compressed = await _compressJpeg(file);
    final raw = compressed ?? await file.readAsBytes();
    final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
    final fileName = 'farm_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // 1) Firebase Storage (works on Blaze; fails on Spark)
    try {
      final ref = FirebaseStorage.instance.ref('farm_images/$fileName');
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await task.ref.getDownloadURL();
      return FarmImageUploadResult.ok(url, provider: 'firebase');
    } catch (e) {
      // continue to free hosts
      final firebaseError = e.toString();

      // 2) ImgBB — free key from https://api.imgbb.com/
      if (ApiKeys.hasImgbb) {
        try {
          final url = await _uploadImgbb(bytes, fileName);
          return FarmImageUploadResult.ok(
            url,
            provider: 'imgbb',
            warning:
                'Firebase Storage unavailable; uploaded via ImgBB. ($firebaseError)',
          );
        } catch (_) {}
      }

      // 3) Catbox — no API key (demo / hackathon fallback)
      try {
        final url = await _uploadCatbox(bytes, fileName);
        return FarmImageUploadResult.ok(
          url,
          provider: 'catbox',
          warning:
              'Firebase Storage unavailable; uploaded via free Catbox host. ($firebaseError)',
        );
      } catch (catboxError) {
        return FarmImageUploadResult.fail(
          'All image hosts failed. '
          'Upgrade Firebase to Blaze, or set IMGBB_API_KEY in dart_defines.json. '
          'Firebase: $firebaseError | Catbox: $catboxError',
        );
      }
    }
  }

  static Future<List<int>?> _compressJpeg(File file) async {
    try {
      final raw = await file.readAsBytes();
      final decoded = img.decodeImage(raw);
      if (decoded == null) return null;
      final resized = decoded.width > 1280
          ? img.copyResize(decoded, width: 1280)
          : decoded;
      return img.encodeJpg(resized, quality: 78);
    } catch (_) {
      return null;
    }
  }

  static Future<String> _uploadImgbb(List<int> bytes, String fileName) async {
    final uri = Uri.parse('https://api.imgbb.com/1/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['key'] = ApiKeys.imgbb
      ..fields['name'] = fileName
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: fileName,
        ),
      );
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('ImgBB HTTP ${streamed.statusCode}: $body');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>?;
    final url = data?['url'] as String? ?? data?['display_url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('ImgBB response missing url');
    }
    return url;
  }

  static Future<String> _uploadCatbox(List<int> bytes, String fileName) async {
    final uri = Uri.parse('https://catbox.moe/user/api.php');
    final request = http.MultipartRequest('POST', uri)
      ..fields['reqtype'] = 'fileupload'
      ..files.add(
        http.MultipartFile.fromBytes(
          'fileToUpload',
          bytes,
          filename: fileName,
        ),
      );
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final body = (await streamed.stream.bytesToString()).trim();
    if (streamed.statusCode < 200 ||
        streamed.statusCode >= 300 ||
        !body.startsWith('http')) {
      throw Exception('Catbox failed: $body');
    }
    return body;
  }
}

class FarmImageUploadResult {
  final String url;
  final String? provider;
  final String? warning;
  final String? error;
  final bool success;

  const FarmImageUploadResult._({
    required this.url,
    required this.success,
    this.provider,
    this.warning,
    this.error,
  });

  factory FarmImageUploadResult.ok(
    String url, {
    required String provider,
    String? warning,
  }) =>
      FarmImageUploadResult._(
        url: url,
        success: true,
        provider: provider,
        warning: warning,
      );

  factory FarmImageUploadResult.fail(String error) => FarmImageUploadResult._(
        url: '',
        success: false,
        error: error,
      );
}
