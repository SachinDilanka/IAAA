import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/detected_sound.dart';

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  List<DetectedSound> _history = [];

  List<DetectedSound> get history => _history;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedStr = prefs.getString('sound_detection_history');
    if (savedStr != null) {
      try {
        final List list = jsonDecode(savedStr);
        _history = list.map((e) => DetectedSound.fromJson(e)).toList();
      } catch (_) {
        _history = [];
      }
    }
  }

  Future<void> addEvent(DetectedSound event) async {
    _history.insert(0, event); // Latest first
    if (_history.length > 200) {
      _history = _history.sublist(0, 200); // Keep max 200 logs
    }
    await _save();
  }

  Future<void> removeEvent(String id) async {
    _history.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_history.map((e) => e.toJson()).toList());
    await prefs.setString('sound_detection_history', jsonStr);
  }
}

