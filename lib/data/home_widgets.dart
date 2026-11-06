import 'dart:math';
import 'package:home_widget/home_widget.dart';
import '../core/prefs.dart';
import '../core/ui.dart' show suraLabel;
import 'db.dart';

/// Item 4: home-screen widgets for prayer times ("کاتەکانی بانگ") and the
/// daily Quran ayah. The native Android providers live in
/// android/app/src/main/kotlin/com/nwezhakanm/; this side pushes the data.
class HomeWidgets {
  HomeWidgets._();

  static Future<void> _save(String key, String? value) async {
    try {
      await HomeWidget.saveWidgetData<String>(key, value);
    } catch (_) {}
  }

  /// Push the next-prayer summary + today's five times.
  static Future<void> updatePrayer() async {
    try {
      final now = DateTime.now();
      final t = await Db.I.prayerTimes(AppPrefs.I.cityId, now);
      if (t == null) return;
      final names = {
        'bayani': 'بەیانی',
        'xorhalatn': 'گزنک',
        'niwaro': 'نیوەڕۆ',
        'asr': 'عەسر',
        'eywara': 'ئێوارە',
        'esha': 'خەوتنان',
      };
      await _save('prayer_city', AppPrefs.I.cityName);
      await _save('prayer_date',
          '${now.day}/${now.month}/${now.year}');
      var nextName = '';
      var nextTime = '';
      final hm = now.hour * 60 + now.minute;
      for (final e in names.entries) {
        final v = t[e.key];
        if (v == null || v.isEmpty) continue;
        final p = v.split(':');
        final m = (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
        if (m >= hm && nextName.isEmpty) {
          nextName = e.value;
          nextTime = v;
        }
      }
      await _save('prayer_next_name', nextName.isEmpty ? 'خەوتنان تێپەڕی' : 'دواترین بانگ: ${nextName}');
      await _save('prayer_next_time', nextTime.isEmpty ? '--:--' : nextTime);
      for (final e in names.entries) {
        await _save('prayer_${e.key}', t[e.key] ?? '--:--');
      }
      await HomeWidget.updateWidget(
          qualifiedAndroidName:
              'com.nwezhakanm.PrayerWidgetProvider');
    } catch (_) {}
  }

  /// Item 5: the Quran widget must always carry one ayah of the day —
  /// pushed once per calendar day at splash, using the exact same
  /// deterministic pick the home banner uses so both stay in sync.
  static Future<void> pushDailyAyah() async {
    try {
      final now = DateTime.now();
      final dayKey = '${now.year}-${now.month}-${now.day}';
      if (AppPrefs.I.widgetAyahDay == dayKey) return;
      // Keep the widget and the home banner on the exact same daily
      // selection. The surah is derived from the calendar day; the ayah
      // index is persisted so both surfaces remain identical after restart.
      final dailyRandom = Random(now.day * 31 + now.month);
      final sura = dailyRandom.nextInt(114) + 1;
      final pool = await Db.I.ayat(sura, AppPrefs.I.tafsir);
      if (pool.isEmpty) return;
      final saved = AppPrefs.I.ayahDay == dayKey
          ? AppPrefs.I.ayahBannerSeed
          : -1;
      final idx = saved >= 0 && saved < pool.length
          ? saved
          : Random(now.day * 31 + now.month).nextInt(pool.length);
      final row = pool[idx];
      AppPrefs.I.ayahDay = dayKey;
      AppPrefs.I.ayahBannerSeed = idx;
      await updateAyah(
        text: '${row['text'] ?? ''}',
        reference:
            '${suraLabel('${row['sura_name_ar'] ?? ''}')} — ئایەتی ${row['ayah'] ?? ''}',
      );
      AppPrefs.I.widgetAyahDay = dayKey;
    } catch (_) {}
  }

  /// Push the daily ayah (text + reference) to the Quran widget.
  static Future<void> updateAyah({String? text, String? reference}) async {
    try {
      await _save('ayah_text', text ?? '');
      await _save('ayah_ref', reference ?? '');
      await HomeWidget.updateWidget(
          qualifiedAndroidName: 'com.nwezhakanm.AyahWidgetProvider');
    } catch (_) {}
  }
}
