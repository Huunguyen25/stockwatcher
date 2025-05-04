import 'package:flutter/services.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  Map<String, String> _config = {};
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final String content =
          await rootBundle.loadString('assets/config/config.properties');
      _config = _parseProperties(content);
      _initialized = true;
    } catch (e) {
      throw Exception('Failed to load configuration: $e');
    }
  }

  String get finnhubApiKey {
    _checkInitialization();
    return _config['finnhub.api.key'] ?? '';
  }

  void _checkInitialization() {
    if (!_initialized) {
      throw StateError('ConfigService must be initialized before use');
    }
  }

  Map<String, String> _parseProperties(String content) {
    final Map<String, String> properties = {};
    final List<String> lines = content.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final parts = line.split('=');
      if (parts.length == 2) {
        properties[parts[0].trim()] = parts[1].trim();
      }
    }

    return properties;
  }
}
