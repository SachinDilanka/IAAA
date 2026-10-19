import 'dart:convert';
import 'dart:html' as html;

const _storageKey = 'adaptive_sign_language_tutor.practice_logs';

List<Map<String, dynamic>> readWebPracticeLogs() {
  final storedLogs = html.window.localStorage[_storageKey];
  if (storedLogs == null || storedLogs.isEmpty) return [];

  final decoded = jsonDecode(storedLogs) as List<dynamic>;
  return decoded
      .map((entry) => Map<String, dynamic>.from(entry as Map))
      .toList();
}

void appendWebPracticeLog(Map<String, dynamic> log) {
  final logs = readWebPracticeLogs()..add(log);
  html.window.localStorage[_storageKey] = jsonEncode(logs);
}
