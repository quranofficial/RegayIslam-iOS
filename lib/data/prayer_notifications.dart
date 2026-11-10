import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/prefs.dart';
import 'db.dart';

/// Port of the original prayer-notification logic
/// (SplashActivity.createNotificationChannel / scheduleNotification +
/// NowIsPrayerTimeActivity + AlarmReceiver.java).
///
/// "بانگ دەنش ئەش نەکات" fix: every path here is defensive — the timezone
/// is always ready before scheduling, the exact-alarm permission is
/// re-checked live before every schedule run, a denied exact alarm falls
/// back to inexact instead of throwing, and nothing fails silently.
class PrayerNotifications {
  PrayerNotifications._();
  static final PrayerNotifications I = PrayerNotifications._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _canUseExactAlarms = false;

  /// True on real Android devices (never on web/desktop where the exact
  /// alarm flow is meaningless).
  static bool get isAndroidDevice {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Last known state of the exact-alarm permission (Android 12+).
  bool get exactAlarmsAllowed => _canUseExactAlarms;

  // ---- Item 5: timezone must be initialized BEFORE any scheduling ----
  static bool _tzReady = false;

  /// Idempotent timezone bootstrap — safe to call from main() and again
  /// from init()/scheduleAll(). The app serves Iraq/Kurdistan (time2.db
  /// city tables), so the local zone is pinned to Asia/Baghdad.
  static void ensureTimezone() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));
    _tzReady = true;
  }

  Future<void> init() async {
    ensureTimezone();
    const android = AndroidInitializationSettings('app_icon');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (resp) {
          debugPrint('bang notification tapped: ${resp.payload}');
        });
    // Android NEVER updates an already-created channel (sound/vibration
    // changes are ignored for an existing id), so old configs would stick
    // forever. Delete the legacy ids from previous app versions.
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final legacy in const [
      'adhan_channel_v2_sound',
      'adhan_channel_v2_silent',
    ]) {
      try {
        await impl?.deleteNotificationChannel(legacy);
      } catch (_) {}
    }
  }

  /// Live query of the exact-alarm permission; refreshes the cached flag
  /// used by scheduleAll(). Non-Android platforms have no such restriction.
  Future<bool> canScheduleExact() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    _canUseExactAlarms =
        await android?.canScheduleExactNotifications() ?? true;
    return _canUseExactAlarms;
  }

  Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await canScheduleExact();
    // Item 3 (feedback): بانگ must actually RING. On Android 12+ the
    // exact-alarm permission is a separate grant — if it is missing many
    // OEMs silently drop or delay the inexact fallback while the phone is
    // in deep sleep, and the user never hears the adhan. Ask for it right
    // here (opens the system alarm permission page) so scheduling starts
    // exact from the first launch.
    if (!_canUseExactAlarms) {
      try {
        await android?.requestExactAlarmsPermission();
        await canScheduleExact();
      } catch (_) {}
    }
  }

  /// Opens the system "Alarms & reminders" page. Rescheduling after the
  /// user grants the permission is the CALLER's job (settings screen).
  Future<bool> requestExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      await android.requestExactAlarmsPermission();
    } catch (_) {}
    return canScheduleExact();
  }

  /// Item 3 + item 12 + item 14: the notification rings with the SELECTED
  /// adhan voice when it was downloaded for offline use, otherwise with the
  /// bundled res/raw/adhan.mp3 (CI copies assets/sounds/dang.MP3 there) —
  /// so the adhan always sounds, even with no internet. The sound is
  /// routed through the ALARM audio attributes and a full-screen intent so
  /// it plays LOUD on every phone brand (many devices route plain
  /// notification sounds quietly or mute them in DND).
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

  /// Public accessor for BangWatcher (item 9): the downloaded adhan voice
  /// when present, so the in-app foreground bang uses the SAME voice the
  /// notifications use.
  static File? downloadedVoiceFile() => _downloadedVoiceFile();

  /// item 9: cancel TODAY's scheduled notification for prayer [index]
  /// (0..4 = bayani, niwaro, asr, eywara, esha) the moment the in-app
  /// watcher rings, so the adhan never plays TWICE at the same moment.
  /// scheduleAll() uses id = dayOffset*5 + index + 1, so today is index+1.
  Future<void> cancelTodayBang(int index) async {
    try {
      await _plugin.cancel(index + 1);
    } catch (_) {}
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

  /// Android channels are immutable: sound/vibration edits only take
  /// effect in a NEW channel id. Encode the sound settings in the id so
  /// every toggle gets a fresh, correctly-configured channel.
  String _channelId() {
    final p = AppPrefs.I;
    return 'adhan_v3_${p.adhanSoundEnabled ? '1' : '0'}'
        '${p.adhanVibrationEnabled ? '1' : '0'}';
  }

  AndroidNotificationDetails _androidDetails() {
    final p = AppPrefs.I;
    return AndroidNotificationDetails(
        _channelId(),
        'بانگی نوێژ',
        channelDescription: 'ئاگادارکردنەوە و دەنگی بانگی نوێژ',
        sound: _notificationSound(),
        playSound: p.adhanSoundEnabled,
        importance: Importance.max,
        priority: Priority.high,
        enableLights: true,
        ledColor: const Color(0xFFF44336),
        enableVibration: p.adhanVibrationEnabled,
        visibility: NotificationVisibility.public,
        // Item 14: مازووی دەنگ بۆ هەموو جۆرێکی مۆبایل —
        //  • alarm audio attributes: the adhan plays at the ALARM volume
        //    stream (never muted by media focus, loud on Xiaomi/Samsung/...)
        //  • full-screen intent: the adhan turns the screen on like an alarm
        //    clock instead of a silent head-up snackbar.
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        channelAction: AndroidNotificationChannelAction.createIfNotExists);
  }

  NotificationDetails _details() {
    final p = AppPrefs.I;
    return NotificationDetails(
        android: _androidDetails(),
        iOS: DarwinNotificationDetails(
            presentSound: p.adhanSoundEnabled,
            sound: p.adhanSoundEnabled ? 'adhan.mp3' : null));
  }

  Future<void> showNow(String title, String body) async {
    await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
        title, body, _details());
  }

  /// Item 2: fire one immediate notification so the user can verify the
  /// adhan pipeline (channel, sound, vibration) with a single tap.
  Future<void> testNotification() async {
    await showNow('ئەزموونی بانگ — ڕێگای ئیسلام',
        'ئەگەر ئەم ئاگادارکردنەوەیە بینیت، بانگی نوێژ بە دەنگ کاردەکات ✅');
  }

  /// Item 6: "تاقیکردنەوەی بانگ" — fire a notification in 5 seconds THROUGH
  /// the real alarm pipeline (AlarmManager + exact clock), so the user can
  /// verify the whole بانگ chain end-to-end, not just the immediate-show
  /// path.
  Future<void> scheduleTestBang({int seconds = 5}) async {
    ensureTimezone();
    await canScheduleExact();
    await _plugin.zonedSchedule(
        9991,
        'تاقیکردنەوەی بانگ',
        'ئەگەر لە ٥ چرکەی تر دەنگی بانگت گرت، بانگی نوێژەکانیش کار دەکەن ✅',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
        _details(),
        androidScheduleMode: _scheduleMode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_bang');
  }

  AndroidScheduleMode _scheduleMode() => _canUseExactAlarms
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  /// Schedule the adhan notification for every enabled prayer of the NEXT
  /// 7 DAYS — this always covers "today + tomorrow" (the 24h window) and
  /// keeps a full week of margin, so the adhan keeps ringing even when the
  /// phone is not opened daily. Cancel-then-reschedule so city/switch/offset
  /// changes never leave stale or duplicate alarms behind.
  ///
  /// Returns the number of alarms that were successfully scheduled.
  Future<int> scheduleAll() async {
    var scheduled = 0;
    ensureTimezone();
    try {
      await _plugin.cancelAll();
    } catch (_) {}
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
    // Re-check the exact-alarm permission EVERY run — a cached "denied"
    // from an earlier session must never downgrade the alarms (and a stale
    // "granted" would make zonedSchedule throw exact_alarms_not_permitted).
    await canScheduleExact();
    final keys = switches.keys.toList();
    final now = DateTime.now();
    for (var d = 0; d < 7; d++) {
      final date = now.add(Duration(days: d));
      Map<String, String>? row;
      try {
        row = await Db.I.prayerTimes(city, date);
      } catch (e) {
        debugPrint('bang: prayerTimes($city, day+$d) failed: $e');
        continue;
      }
      if (row == null) continue;
      for (var i = 0; i < keys.length; i++) {
        final key = keys[i];
        if (!switches[key]!) continue;
        final time = row[key];
        if (time == null || time.isEmpty) continue;
        final parts = time.split(':');
        if (parts.length < 2) continue;
        final h = int.tryParse(parts[0]); final m = int.tryParse(parts[1]);
        if (h == null || m == null) continue;
        // BrdnapeshActivity: per-prayer offset in minutes
        // (negative = دواخستن, positive = پێشخستن).
        final offset = p.adhanOffset(key);
        final when = tz.TZDateTime(tz.local, date.year, date.month,
                date.day, h, m).add(Duration(minutes: offset));
        if (!when.isAfter(tz.TZDateTime.now(tz.local))) continue;
        // Stable id per day+prayer: rescheduling replaces instead of
        // accumulating duplicates.
        final id = d * keys.length + i + 1;
        try {
          await _plugin.zonedSchedule(
              id, names[key] ?? key,
              'ئێستا کاتی ${names[key]}ـە لە ${p.cityName}', when,
              _details(),
              androidScheduleMode: _scheduleMode(),
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: key);
          scheduled++;
        } on PlatformException catch (e) {
          // Android 14 revoked SCHEDULE_EXACT_ALARM between our check and
          // the call: fall back to inexact instead of losing the prayer.
          if (e.code == 'exact_alarms_not_permitted') {
            _canUseExactAlarms = false;
            try {
              await _plugin.zonedSchedule(
                  id, names[key] ?? key,
                  'ئێستا کاتی ${names[key]}ـە لە ${p.cityName}', when,
                  _details(),
                  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                  uiLocalNotificationDateInterpretation:
                      UILocalNotificationDateInterpretation.absoluteTime,
                  payload: key);
              scheduled++;
            } catch (e2) {
              debugPrint('bang: schedule($key, day+$d) failed: $e2');
            }
          } else {
            debugPrint('bang: schedule($key, day+$d) failed: $e');
          }
        } catch (e) {
          debugPrint('bang: schedule($key, day+$d) failed: $e');
        }
      }
    }
    debugPrint('bang: $scheduled adhan alarms scheduled '
        '(exact=$_canUseExactAlarms, city=$city)');
    return scheduled;
  }
}
