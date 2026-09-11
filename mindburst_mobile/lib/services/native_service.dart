import 'package:flutter/services.dart';

class NativeService {
  static const MethodChannel _channel = MethodChannel('org.mindburst.mindburst_app/native');

  /// Opens Google Maps with a pin on the specified place
  static Future<void> openMaps(String place) async {
    try {
      await _channel.invokeMethod('openMaps', {'place': place});
    } catch (_) {}
  }

  /// Displays a native Android heads-up notification
  static Future<void> showNotification(String title, String body) async {
    try {
      await _channel.invokeMethod('showNotification', {'title': title, 'body': body});
    } catch (_) {}
  }

  /// Reads aloud the text (supports English and Tanglish phonetics)
  static Future<void> speak(String text) async {
    try {
      await _channel.invokeMethod('speak', {'text': text});
    } catch (_) {}
  }

  /// Stops ongoing speech
  static Future<void> stopSpeaking() async {
    try {
      await _channel.invokeMethod('stopSpeaking');
    } catch (_) {}
  }
}
