import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/wstunnel_config.dart';

class ConfigStorage {
  static const String _configKey = 'wstunnel_config';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Save configuration to secure storage
  static Future<void> saveConfig(WstunnelConfig config) async {
    try {
      final jsonString = jsonEncode(config.toJson());
      await _storage.write(key: _configKey, value: jsonString);
    } catch (e) {
      print('Error saving config: $e');
      rethrow;
    }
  }

  /// Load configuration from secure storage
  /// Returns null if configuration not found
  static Future<WstunnelConfig?> loadConfig() async {
    try {
      final jsonString = await _storage.read(key: _configKey);
      if (jsonString == null) {
        return null;
      }
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return WstunnelConfig.fromJson(json);
    } catch (e) {
      print('Error loading config: $e');
      return null;
    }
  }

  /// Delete saved configuration
  static Future<void> deleteConfig() async {
    try {
      await _storage.delete(key: _configKey);
    } catch (e) {
      print('Error deleting config: $e');
    }
  }
}

