import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/prefs.dart';
import 'db.dart';

/// Port of the original prayer-notification logic
/// (SplashActivity.createNotificationChannel / scheduleNotification +
/// NowIsPrayerTimeActivity + AlarmReceiver.java).
class PrayerNotifications {
  PrayerNotifications._();
  static final PrayerNotifications I = PrayerNotifications._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _canUseExactAlarms = false;

  Future<void> init() async {
    const android = AndroidInitializationSettings('app_icon');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));
    tzdata.initializeTimeZones();
    // The app serves Iraq/Kurdistan (time2.db city tables).
    tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));
  }

  Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _canUseExactAlarms =
        await android?.canScheduleExactNotifications() ?? false;
  }

  Future<bool> requestExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    await android.requestExactAlarmsPermission();
    _canUseExactAlarms =
        await android.canScheduleExactNotifications() ?? false;
    return _canUseExactAlarms;
  }

  /// Item 3 + item 12: the notification rings with the SELECTED adhan voice
  /// when it was downloaded for offline use, otherwise with the bundled
  /// res/raw/adhan.mp3 — so the adhan always sounds, even with no internet.
  AndroidNotificationSound? _notificationSound() {
    if (!AppPrefs.I.adhanSoundEnabled) return null;
    try {
      final f = _downloadedVoiceFile();
      if (f != null && f.existsSync() && f.lengthSync() > 0) {
        return UriAndroidNotificationSound(Uri.file(f.path).toString());
      }
    } catch (_) {}
    return const RawResourceAndroidNotificationSound('adhan');
  }

  static File? _downloadedVoiceFile() {
    try {
      final file = AppPrefs.I.adhanVoiceFile.replaceAll('.mp3', '');
      if (file.isEmpty) return null;
      // Documents dir is resolved lazily; keep it best-effort.
      final dir = _docsDir;
      if (dir == null) return null;
      return File('${dir.path}/bang/$file.mp3');
    } catch (_) {
      return null;
    }
  }

  static Directory? _docsDir;

  /// Cache the documents dir at startup so scheduled notifications can find
  /// the downloaded adhan voice even when the app is idle.
  static Future<void> warmUp() async {
    try {
      _docsDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      _docsDir = null;
    }
  }

  AndroidNotificationDetails _androidDetails() {
    final p = AppPrefs.I;
    return AndroidNotificationDetails(
        'adhan_channel_v2_${p.adhanSoundEnabled ? 'sound' : 'silent'}',
        'بانگی نوێژ',
        channelDescription: 'ئاگادارکردنەوە و دەنگی بانگی نوێژ',
        sound: _notificationSound(),
        playSound: p.adhanSoundEnabled,
        importance: Importance.max,
        priority: Priority.high,
        enableLights: true,
        ledColor: const Color(0xFFF44336),
        enableVibration: p.adhanVibrationEnabled,
        visibility: NotificationVisibility.public);
  }

  Future<void> showNow(String title, String body) async {
    final p = AppPrefs.I;
    await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
        title, body,
        NotificationDetails(
            android: _androidDetails(),
            iOS: DarwinNotificationDetails(
                presentSound: p.adhanSoundEnabled,
                sound: p.adhanSoundEnabled ? 'adhan.mp3' : null)));
  }

  /// Item 2: fire one immediate notification so the user can verify the
  /// adhan pipeline (channel, sound, vibration) with a single tap.
  Future<void> testNotification() async {
    await showNow('ئەزموونی بانگ — ڕێگای ئیسلام',
        'ئەگەر ئەم ئاگادارکردنەوەیە بینیت، بانگی نوێژ بە دەنگ کاردەکات ✅');
  }

  /// Schedule the adhan notification for every prayer of the next 7 days.
  Future<void> scheduleAll() async {
    await _plugin.cancelAll();
    final p = AppPrefs.I;
    final city = p.cityId;
    final switches = {
      'bayani': p.notifFajr,
      'niwaro': p.notifDhuhr,
      'asr': p.notifAsr,
      'eywara': p.notifMaghrib,
      'esha': p.notifIsha,
    };
    final names = {
      'bayani': 'بانگی بەیانی',
      'niwaro': 'بانگی نیوەڕۆ',
      'asr': 'بانگی عەسر',
      'eywara': 'بانگی ئێوارە',
      'esha': 'بانگی خەوتنان',
    };
    var id = 1;
    final now = DateTime.now();
    for (var d = 0; d < 7; d++) {
      final date = now.add(Duration(days: d));
      try {
        final row = await Db.I.prayerTimes(city, date);
        if (row == null) continue;
        for (final entry in switches.entries) {
          if (!entry.value) continue;
          final time = row[entry.key];
          if (time == null || time.isEmpty) continue;
          final parts = time.split(':');
          if (parts.length < 2) continue;
          final h = int.tryParse(parts[0]); final m = int.tryParse(parts[1]);
          if (h == null || m == null) continue;
          // BrdnapeshActivity: per-prayer offset in minutes
          // (negative = دواخستن, positive = پێشخستن).
          final offset = p.adhanOffset(entry.key);
          final when = tz.TZDateTime(tz.local, date.year, date.month,
                  date.day, h, m).add(Duration(minutes: offset));
          if (when.isBefore(tz.TZDateTime.now(tz.local))) continue;
          await _plugin.zonedSchedule(
              id++, names[entry.key] ?? entry.key,
              'ئێستا کاتی ${names[entry.key]}ـە لە ${p.cityName}', when,
              NotificationDetails(
                  android: _androidDetails(),
                  iOS: DarwinNotificationDetails(
                      presentSound: p.adhanSoundEnabled,
                      sound: p.adhanSoundEnabled ? 'adhan.mp3' : null)),
              androidScheduleMode: _canUseExactAlarms
                  ? AndroidScheduleMode.exactAllowWhileIdle
                  : AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime);
        }
      } catch (_) {}
    }
  }
}
