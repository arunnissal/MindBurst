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
  static Future<void> showNotification(String title, String body, {int? id}) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
        if (id != null) 'id': id,
      });
    } catch (_) {}
  }

  /// Schedules a native exact AlarmManager notification
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int triggerAtMillis,
  }) async {
    try {
      await _channel.invokeMethod('scheduleNotification', {
        'id': id,
        'title': title,
        'body': body,
        'triggerAtMillis': triggerAtMillis,
      });
    } catch (_) {}
  }

  /// Cancels a scheduled notification by ID
  static Future<void> cancelNotification(int id) async {
    try {
      await _channel.invokeMethod('cancelNotification', {'id': id});
    } catch (_) {}
  }

  /// Converts date string (e.g. '2026-09-11') and time string (e.g. '7:40 PM', '19:40', '7.40pm')
  /// into exact DateTime object
  static DateTime? parseReminderDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null && timeStr == null) return null;

    DateTime baseDate = DateTime.now();
    if (dateStr != null && dateStr.trim().isNotEmpty) {
      try {
        baseDate = DateTime.parse(dateStr.trim());
      } catch (_) {}
    }

    int hour = 9;
    int minute = 0;
    if (timeStr != null && timeStr.trim().isNotEmpty) {
      final clean = timeStr.trim().replaceAll('.', ':');
      final match = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false).firstMatch(clean);
      if (match != null) {
        hour = int.tryParse(match.group(1) ?? '9') ?? 9;
        minute = match.group(2) != null ? (int.tryParse(match.group(2)!) ?? 0) : 0;
        final amPm = match.group(3)?.toLowerCase();
        if (amPm == 'pm' && hour < 12) hour += 12;
        if (amPm == 'am' && hour == 12) hour = 0;
      }
    }

    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
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
