/// Centralized network configuration.
///
/// Set the backend base URL here in one place:
/// - Android emulator: `http://10.0.2.2:5000`
/// - Real phone: `http://<YOUR_PC_LAN_IP>:5000` (e.g., `http://192.168.8.100:5000`)
/// - Web / Windows Desktop / Local testing: `http://127.0.0.1:5000`
class AppConfig {
  /// Base host of the Python backend.
  static const String backendBaseUrl = 'http://127.0.0.1:5000';

  /// Base URL for SuggestApi so that requests call path '/api/suggest'.
  static const String suggestApiBaseUrl = '$backendBaseUrl/api';
}
