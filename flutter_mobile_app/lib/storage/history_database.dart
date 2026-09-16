import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/detection_event.dart';

class HistoryDatabase extends ChangeNotifier {
  static final HistoryDatabase _instance = HistoryDatabase._internal();
  factory HistoryDatabase() => _instance;
  HistoryDatabase._internal();

  static const String _storageKey = 'offline_detection_history';
  List<DetectionEvent> _history = [];

  List<DetectionEvent> get history => List.unmodifiable(_history);

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawJson = prefs.getString(_storageKey);
    if (rawJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson);
        _history = decoded.map((e) => DetectionEvent.fromJson(e)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint("Error loading detection history: $e");
      }
    }
  }

  Future<void> saveEvent(DetectionEvent event) async {
    _history.insert(0, event); // Latest first
    if (_history.length > 100) {
      _history = _history.sublist(0, 100);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final String rawJson = jsonEncode(_history.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, rawJson);
  }

  Future<void> clearHistory() async {
    _history.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
