import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
    final canSchedule = await android?.canScheduleExactNotifications();
    if (canSchedule != true) {
      await android?.requestExactAlarmsPermission();
    }
    _canUseExactAlarms =
        await android?.canScheduleExactNotifications() ?? false;
  }

  Future<void> showNow(String title, String body) async {
    const android = AndroidNotificationDetails(
        'adhan_channel_v2', 'بانگی نوێژ',
        channelDescription: 'ئاگادارکردنەوە و دەنگی بانگی نوێژ',
        sound: RawResourceAndroidNotificationSound('adhan'),
        playSound: true,
        importance: Importance.max,
        priority: Priority.high,
        enableLights: true,
        ledColor: Color(0xFFF44336),
        enableVibration: true,
        visibility: NotificationVisibility.public);
    await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
        title, body,
        const NotificationDetails(android: android, iOS: DarwinNotificationDetails(presentSound: true, sound: 'adhan.caf')));
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
          final when =
              tz.TZDateTime(tz.local, date.year, date.month, date.day, h, m);
          if (when.isBefore(tz.TZDateTime.now(tz.local))) continue;
          final android = AndroidNotificationDetails(
              'adhan_channel_v2', 'بانگی نوێژ',
              channelDescription: 'دەنگی بانگی نوێژ',
              sound: const RawResourceAndroidNotificationSound('adhan'),
              playSound: true,
              importance: Importance.max,
              priority: Priority.high,
              enableVibration: true,
              visibility: NotificationVisibility.public);
          await _plugin.zonedSchedule(
              id++, names[entry.key] ?? entry.key,
              'ئێستا کاتی ${names[entry.key]}ـە لە ${p.cityName}', when,
              NotificationDetails(android: android, iOS: const DarwinNotificationDetails(presentSound: true, sound: 'adhan.caf')),
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
