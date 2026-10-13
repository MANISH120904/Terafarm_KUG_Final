import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/youtube_config.dart';

class YouTubeVideo {
  final String videoId;
  final String title;
  final String description;
  final String channelTitle;
  final String thumbnailUrl;
  final String publishedAt;
  final String duration;
  final int viewCount;
  
  YouTubeVideo({
    required this.videoId,
    required this.title,
    required this.description,
    required this.channelTitle,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.duration,
    required this.viewCount,
  });
  
  String get youtubeUrl => 'https://www.youtube.com/watch?v=$videoId';
  
  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    // Check if this is our simplified JSON structure (from toJson)
    if (json.containsKey('videoId') && json.containsKey('title')) {
      return YouTubeVideo(
        videoId: json['videoId'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        channelTitle: json['channelTitle'] ?? '',
        thumbnailUrl: json['thumbnailUrl'] ?? '',
        publishedAt: json['publishedAt'] ?? '',
        duration: json['duration'] ?? '',
        viewCount: json['viewCount'] ?? 0,
      );
    }
    
    // Handle YouTube API response structure
    final snippet = json['snippet'] ?? {};
    final thumbnails = snippet['thumbnails'] ?? {};
    final statistics = json['statistics'] ?? {};
    final contentDetails = json['contentDetails'] ?? {};
    
    return YouTubeVideo(
      videoId: json['id']?['videoId'] ?? json['id'] ?? '',
      title: snippet['title'] ?? '',
      description: snippet['description'] ?? '',
      channelTitle: snippet['channelTitle'] ?? '',
      thumbnailUrl: thumbnails['medium']?['url'] ?? 
                   thumbnails['high']?['url'] ?? 
                   thumbnails['default']?['url'] ?? '',
      publishedAt: snippet['publishedAt'] ?? '',
      duration: contentDetails['duration'] ?? '',
      viewCount: int.tryParse(statistics['viewCount']?.toString() ?? '0') ?? 0,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'description': description,
      'channelTitle': channelTitle,
      'thumbnailUrl': thumbnailUrl,
      'publishedAt': publishedAt,
      'duration': duration,
      'viewCount': viewCount,
    };
  }
}

class YouTubeService {
  static const String _baseUrl = YouTubeConfig.baseUrl;
  static const String _apiKey = YouTubeConfig.apiKey;
  
  /// Search for YouTube videos based on query with language preference
  Future<List<YouTubeVideo>> searchVideos({
    required String query,
    String language = 'en',
    int maxResults = 5,
    String order = 'relevance',
  }) async {
    try {
      // Create language-specific search query
      String searchQuery = _createLanguageSpecificQuery(query, language);
      
      final searchUrl = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'part': 'snippet',
        'q': searchQuery,
        'type': 'video',
        'maxResults': maxResults.toString(),
        'order': order,
        'relevanceLanguage': _getLanguageCode(language),
        'regionCode': _getRegionCode(language),
        'key': _apiKey,
        'safeSearch': 'moderate',
        'videoEmbeddable': 'true',
      });
      
      print('YouTube Search URL: $searchUrl');
      
      final response = await http.get(searchUrl);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        
        List<YouTubeVideo> videos = [];
        
        // Get video IDs for additional details
        if (items.isNotEmpty) {
          final videoIds = items
              .map((item) => item['id']['videoId'] as String)
              .where((id) => id.isNotEmpty)
              .join(',');
          
          // Get additional video details (duration, view count, etc.)
          final detailsVideos = await _getVideoDetails(videoIds);
          
          for (var item in items) {
            try {
              final videoId = item['id']['videoId'] as String;
              final detailsVideo = detailsVideos.firstWhere(
                (v) => v.videoId == videoId,
                orElse: () => YouTubeVideo.fromJson(item),
              );
              
              videos.add(detailsVideo);
            } catch (e) {
              print('Error parsing video item: $e');
              continue;
            }
          }
        }
        
        return videos;
      } else {
        print('YouTube API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to search YouTube videos: ${response.statusCode}');
      }
    } catch (e) {
      print('YouTube Service Error: $e');
      return [];
    }
  }
  
  /// Get detailed video information including duration and view count
  Future<List<YouTubeVideo>> _getVideoDetails(String videoIds) async {
    try {
      final detailsUrl = Uri.parse('$_baseUrl/videos').replace(queryParameters: {
        'part': 'snippet,contentDetails,statistics',
        'id': videoIds,
        'key': _apiKey,
      });
      
      final response = await http.get(detailsUrl);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];
        
        return items.map((item) => YouTubeVideo.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error getting video details: $e');
    }
    
    return [];
  }
  
  /// Create language-specific search query for farming schemes
  String _createLanguageSpecificQuery(String query, String language) {
    // Add language-specific terms for better search results
    Map<String, String> languageTerms = {
      'hi': 'किसान योजना tutorial hindi',
      'ta': 'விவசாயி திட்டம் tutorial tamil',
      'te': 'రైతు పథకం tutorial telugu',
      'en': 'farmer scheme tutorial english',
    };
    
    String langTerm = languageTerms[language] ?? languageTerms['en']!;
    
    // Combine original query with language-specific terms
    return '$query $langTerm india government';
  }
  
  /// Get YouTube language code for relevance
  String _getLanguageCode(String language) {
    switch (language.toLowerCase()) {
      case 'hi':
      case 'hindi':
        return 'hi';
      case 'ta':
      case 'tamil':
        return 'ta';
      case 'te':
      case 'telugu':
        return 'te';
      case 'en':
      case 'english':
      default:
        return 'en';
    }
  }
  
  /// Get region code for localized content
  String _getRegionCode(String language) {
    // All languages map to India for farming schemes
    return 'IN';
  }
  
  /// Search for scheme-specific tutorials
  Future<List<YouTubeVideo>> searchSchemeVideos({
    required String schemeName,
    required String language,
    int maxResults = 3,
  }) async {
    // Create scheme-specific search queries
    String searchQuery = _createSchemeSearchQuery(schemeName, language);
    
    return await searchVideos(
      query: searchQuery,
      language: language,
      maxResults: maxResults,
      order: 'relevance',
    );
  }
  
  /// Create specific search query for farming schemes
  String _createSchemeSearchQuery(String schemeName, String language) {
    Map<String, Map<String, String>> schemeTranslations = {
      'PM-KISAN': {
        'hi': 'पीएम किसान योजना आवेदन कैसे करें',
        'ta': 'பிரதமர் கிசான் திட்டம் விண்ணப்பிப்பது எப்படி',
        'te': 'పిఎం కిసాన్ పథకం దరఖాస్తు ఎలా చేయాలి',
        'en': 'PM KISAN scheme how to apply',
      },
      'PMFBY': {
        'hi': 'प्रधानमंत्री फसल बीमा योजना आवेदन',
        'ta': 'பிரதமர் பயிர் காப்பீட்டு திட்டம் விண்ணப்பம்',
        'te': 'ప్రధానమంత్రి పంట బీమా పథకం దరఖాస్తు',
        'en': 'Pradhan Mantri Fasal Bima Yojana application',
      },
      'KCC': {
        'hi': 'किसान क्रेडिट कार्ड आवेदन कैसे करें',
        'ta': 'கிசான் கிரெடிட் கார்டு விண்ணப்பிப்பது எப்படி',
        'te': 'కిసాన్ క్రెడిట్ కార్డ్ దరఖాస్తు ఎలా చేయాలి',
        'en': 'Kisan Credit Card how to apply',
      },
    };
    
    // Check if we have specific translation for this scheme
    for (String key in schemeTranslations.keys) {
      if (schemeName.toUpperCase().contains(key)) {
        return schemeTranslations[key]?[language] ?? 
               schemeTranslations[key]?['en'] ?? 
               '$schemeName tutorial $language';
      }
    }
    
    // Fallback to generic search
    return '$schemeName tutorial $language farming scheme india';
  }
  
  /// Format duration from ISO 8601 to readable format
  String formatDuration(String isoDuration) {
    if (isoDuration.isEmpty) return '';
    
    try {
      // Parse ISO 8601 duration (PT4M13S -> 4:13)
      final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
      final match = regex.firstMatch(isoDuration);
      
      if (match != null) {
        final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
        final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
        
        if (hours > 0) {
          return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
        } else {
          return '${minutes}:${seconds.toString().padLeft(2, '0')}';
        }
      }
    } catch (e) {
      print('Error formatting duration: $e');
    }
    
    return isoDuration;
  }
  
  /// Format view count to readable format
  String formatViewCount(int viewCount) {
    if (viewCount < 1000) {
      return viewCount.toString();
    } else if (viewCount < 1000000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    }
  }
}