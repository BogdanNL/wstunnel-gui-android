import 'package:flutter/services.dart';

class ForegroundService {
  static const MethodChannel _channel = MethodChannel('com.example.wstunnel_gui/foreground_service');

  /// Start foreground service for tunnel background operation
  static Future<bool> start() async {
    try {
      final result = await _channel.invokeMethod<bool>('startForegroundService');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error starting foreground service: ${e.message}');
      return false;
    }
  }

  /// Stop foreground service
  static Future<bool> stop() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopForegroundService');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Error stopping foreground service: ${e.message}');
      return false;
    }
  }
}

