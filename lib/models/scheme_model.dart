import '../services/youtube_service.dart';

class SchemeModel {
  final String id;
  final String name;
  final String description;
  final String eligibility;
  final String benefits;
  final String applicationProcess;
  final String contactInfo;
  final String documentUrl;
  final List<String> keywords;
  final String category;
  final DateTime lastUpdated;

  SchemeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.eligibility,
    required this.benefits,
    required this.applicationProcess,
    required this.contactInfo,
    required this.documentUrl,
    required this.keywords,
    required this.category,
    required this.lastUpdated,
  });

  factory SchemeModel.fromJson(Map<String, dynamic> json) {
    return SchemeModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      eligibility: json['eligibility'] ?? '',
      benefits: json['benefits'] ?? '',
      applicationProcess: json['applicationProcess'] ?? '',
      contactInfo: json['contactInfo'] ?? '',
      documentUrl: json['documentUrl'] ?? '',
      keywords: List<String>.from(json['keywords'] ?? []),
      category: json['category'] ?? '',
      lastUpdated: DateTime.tryParse(json['lastUpdated'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'eligibility': eligibility,
      'benefits': benefits,
      'applicationProcess': applicationProcess,
      'contactInfo': contactInfo,
      'documentUrl': documentUrl,
      'keywords': keywords,
      'category': category,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<SchemeModel>? recommendedSchemes;
  final List<dynamic>? videos; // Keep as dynamic to avoid circular imports

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.recommendedSchemes,
    this.videos,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      isUser: json['isUser'] ?? true,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      recommendedSchemes: json['recommendedSchemes'] != null
          ? (json['recommendedSchemes'] as List)
              .map((scheme) => SchemeModel.fromJson(scheme))
              .toList()
          : null,
      videos: json['videos'] != null 
          ? (json['videos'] as List)
              .map((video) => video is Map<String, dynamic> 
                  ? YouTubeVideo.fromJson(video)
                  : video)
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'recommendedSchemes': recommendedSchemes?.map((scheme) => scheme.toJson()).toList(),
      'videos': videos?.map((video) => video is YouTubeVideo 
          ? video.toJson() 
          : video).toList(),
    };
  }
}

class UserProfile {
  final String farmSize;
  final String location;
  final String cropType;
  final String experience;
  final String income;
  final List<String> interests;
  final String preferredLanguage;

  UserProfile({
    required this.farmSize,
    required this.location,
    required this.cropType,
    required this.experience,
    required this.income,
    required this.interests,
    this.preferredLanguage = 'hindi',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      farmSize: json['farmSize'] ?? '',
      location: json['location'] ?? '',
      cropType: json['cropType'] ?? '',
      experience: json['experience'] ?? '',
      income: json['income'] ?? '',
      interests: List<String>.from(json['interests'] ?? []),
      preferredLanguage: json['preferredLanguage'] ?? 'hindi',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'farmSize': farmSize,
      'location': location,
      'cropType': cropType,
      'experience': experience,
      'income': income,
      'interests': interests,
      'preferredLanguage': preferredLanguage,
    };
  }
}