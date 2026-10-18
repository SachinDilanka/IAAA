import 'package:flutter/material.dart';

enum AlertLevel {
  high(
    'HIGH',
    'ඉහළ අවදානම',
    Color(0xFFDC2626), // Natural Emergency Crimson
    Icons.warning_rounded,
    20,
  ),
  medium(
    'MEDIUM',
    'මධ්‍යම අවදානම',
    Color(0xFFD97706), // Natural Warning Amber
    Icons.error_outline_rounded,
    30,
  ),
  low(
    'LOW',
    'අඩු අවදානම',
    Color(0xFF059669), // Natural Forest Emerald
    Icons.info_outline_rounded,
    45,
  ),
  none(
    'NORMAL',
    'සාමාන්‍ය',
    Color(0xFF64748B), // Natural Slate Grey
    Icons.check_circle_outline_rounded,
    0,
  );

  final String name;
  final String sinhalaLabel;
  final Color color;
  final IconData icon;
  final int cooldownSeconds;

  const AlertLevel(
    this.name,
    this.sinhalaLabel,
    this.color,
    this.icon,
    this.cooldownSeconds,
  );
}

// Global safe helper function
Color getAlertColor(AlertLevel? level) {
  return level?.color ?? const Color(0xFF2563EB);
}

