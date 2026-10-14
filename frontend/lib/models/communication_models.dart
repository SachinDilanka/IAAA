import 'package:flutter/material.dart';

enum VenueType {
  supermarket,
  hospital,
  bank,
  restaurant,
  other,
}

extension VenueTypeExtension on VenueType {
  String get slug {
    switch (this) {
      case VenueType.supermarket:
        return 'supermarket';
      case VenueType.hospital:
        return 'hospital';
      case VenueType.bank:
        return 'bank';
      case VenueType.restaurant:
        return 'restaurant';
      case VenueType.other:
        return 'other';
    }
  }

  String get displayNameEn {
    switch (this) {
      case VenueType.supermarket:
        return 'Supermarket';
      case VenueType.hospital:
        return 'Hospital';
      case VenueType.bank:
        return 'Bank';
      case VenueType.restaurant:
        return 'Restaurant';
      case VenueType.other:
        return 'Other Location';
    }
  }

  String get displayNameSi {
    switch (this) {
      case VenueType.supermarket:
        return 'සුපිරි වෙළඳසැල';
      case VenueType.hospital:
        return 'රෝහල';
      case VenueType.bank:
        return 'බැංකුව';
      case VenueType.restaurant:
        return 'ආපනශාලාව';
      case VenueType.other:
        return 'වෙනත් ස්ථානය';
    }
  }

  Color get themeColor {
    switch (this) {
      case VenueType.supermarket:
        return const Color(0xFF10B981); // Emerald Green
      case VenueType.hospital:
        return const Color(0xFFF43F5E); // Rose Red
      case VenueType.bank:
        return const Color(0xFF2563EB); // Royal Blue
      case VenueType.restaurant:
        return const Color(0xFFF59E0B); // Amber Orange
      case VenueType.other:
        return const Color(0xFF6B7280); // Slate Gray
    }
  }

  Color get backgroundColor {
    switch (this) {
      case VenueType.supermarket:
        return const Color(0xFFD1FAE5);
      case VenueType.hospital:
        return const Color(0xFFFFE4E6);
      case VenueType.bank:
        return const Color(0xFFDBEAFE);
      case VenueType.restaurant:
        return const Color(0xFFFEF3C7);
      case VenueType.other:
        return const Color(0xFFF3F4F6);
    }
  }

  IconData get icon {
    switch (this) {
      case VenueType.supermarket:
        return Icons.shopping_cart_outlined;
      case VenueType.hospital:
        return Icons.local_hospital_outlined;
      case VenueType.bank:
        return Icons.account_balance_outlined;
      case VenueType.restaurant:
        return Icons.restaurant_outlined;
      case VenueType.other:
        return Icons.place_outlined;
    }
  }
}

class VenueItem {
  final String id;
  final String name;
  final String shortName;
  final VenueType type;
  final double lat;
  final double lon;
  final String city;
  final String address;

  const VenueItem({
    required this.id,
    required this.name,
    required this.shortName,
    required this.type,
    required this.lat,
    required this.lon,
    required this.city,
    required this.address,
  });

  factory VenueItem.fromJson(Map<String, dynamic> json, VenueType type) {
    return VenueItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      shortName: json['short_name']?.toString() ?? json['name']?.toString() ?? '',
      type: type,
      lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : 0.0,
      lon: (json['lon'] is num) ? (json['lon'] as num).toDouble() : 0.0,
      city: json['city']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class CommunicationMessage {
  final int id;
  final String templateEn;
  final String templateSi;
  final String category;
  final String? iconName;

  const CommunicationMessage({
    required this.id,
    required this.templateEn,
    required this.templateSi,
    required this.category,
    this.iconName,
  });

  factory CommunicationMessage.fromJson(Map<String, dynamic> json) {
    return CommunicationMessage(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      templateEn: json['template_en']?.toString() ?? json['template']?.toString() ?? '',
      templateSi: json['template_si']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      iconName: json['icon']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'template_en': templateEn,
    'template_si': templateSi,
    'category': category,
    'icon': iconName,
  };
}

class CommunicationCategory {
  final String id;
  final String key;
  final String name;
  final String nameSi;
  final String nameEn;
  final IconData icon;
  final int count;
  final List<CommunicationMessage> messages;

  const CommunicationCategory({
    required this.id,
    required this.key,
    required this.name,
    required this.nameSi,
    required this.nameEn,
    required this.icon,
    required this.count,
    required this.messages,
  });

  factory CommunicationCategory.fromJson(Map<String, dynamic> json, IconData defaultIcon) {
    final rawMsgs = json['messages'] as List<dynamic>? ?? [];
    final msgs = rawMsgs.map((m) => CommunicationMessage.fromJson(m as Map<String, dynamic>)).toList();
    return CommunicationCategory(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameSi: json['name_si']?.toString() ?? '',
      nameEn: json['name_en']?.toString() ?? '',
      icon: defaultIcon,
      count: json['count'] is int ? json['count'] as int : msgs.length,
      messages: msgs,
    );
  }
}
