import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/home_widgets.dart';
import '../../data/prayer_notifications.dart';
import '../settings/adhan_voice_screen.dart';

/// Original: NwezhiActivity — per-prayer notification switches + city picker.
class NwezhiSettingsScreen extends StatefulWidget {
  const NwezhiSettingsScreen({super.key});
  @override
  State<NwezhiSettingsScreen> createState() => _NwezhiSettingsScreenState();
}

class _NwezhiSettingsScreenState extends State<NwezhiSettingsScreen> {
  Map<String, String>? _today;
  List<Map<String, Object?>> _cities = [];
  bool _exactAllowed = true;
  bool _askedExactOnce = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await Db.I.prayerTimes(AppPrefs.I.cityId, DateTime.now());
    final c = await Db.I.cities();
    final exact = await PrayerNotifications.I.canScheduleExact();
    if (!mounted) return;
    setState(() { _today = t; _cities = c; _exactAllowed = exact; });
    _guideExactAlarmIfNeeded();
  }

  /// Item 2: if the exact-alarm permission is missing the adhan can be
  /// dropped/delayed by the system — NEVER fail silently, guide the user.
  void _guideExactAlarmIfNeeded() {
    if (_exactAllowed || _askedExactOnce) return;
    if (!PrayerNotifications.isAndroidDevice) return;
    _askedExactOnce = true;
    showDialog(
      context: context,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ئاگادارکردنەوەی بانگ کارا نییە',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark)),
          content: const Text(
              'ڕێگەی Exact Alarm نەدرا — بڕۆ ناو ڕێکخستنەکانی مۆبایل و بەخشبێ بە "ئاگادارکردنەوە و وردی زانیاری" بۆ ئەپەکە، تا بانگی نوێژ لە کاتی خۆیدا بە دەنگ بگرێت 🔔',
              style: TextStyle(fontSize: 13.5, height: 1.8)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('دواتر',
                    style: TextStyle(color: AppColors.primaryDark))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(c);
                  _enableExactAlarms();
                },
                child: const Text('کردنەوەی ڕێکخستنی مۆبایل')),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final n = await PrayerNotifications.I.scheduleAll();
    await HomeWidgets.updatePrayer();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n > 0
            ? 'بانگ بۆ ٧ ڕۆژ خشتەکرا ($n ئاگادارکردنەوە) ✅'
            : 'ئاگادارکردنەوەکان نوێکرانەوە')));
    if (!await PrayerNotifications.I.canScheduleExact()) {
      if (!mounted) return;
      setState(() => _exactAllowed = false);
      _guideExactAlarmIfNeeded();
    } else if (mounted) {
      setState(() => _exactAllowed = true);
    }
  }

  Future<void> _enableExactAlarms() async {
    final allowed = await PrayerNotifications.I.requestExactAlarmPermission();
    if (!mounted) return;
    setState(() => _exactAllowed = allowed);
    await PrayerNotifications.I.scheduleAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(allowed
        ? 'ئاگادارکردنەوەی کاتی ورد چالاک کرا ✅'
        : 'ڕێگەی Exact Alarm نەدرا — بڕۆ ناو ڕێکخستنەکانی مۆبایل و بەخشبێ بە "ئاگادارکردنەوە و وردی زانیاری"'),
    ));
  }

  /// Item 2: verify the whole notification pipeline with one tap.
  Future<void> _testAdhan() async {
    try {
      await PrayerNotifications.I.testNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('نۆتیفیکێشنی تاقیکردنەوە نێردرا — سەیری ئاگادارکردنەوەکان بکە')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('نۆتیفیکێشن سەرکەوتوو نەبوو')));
    }
  }

  /// Item 6: "تاقیکردنەوەی بانگ" — rings in 5 seconds through the REAL
  /// alarm pipeline (AlarmManager + exact clock), so the user verifies the
  /// بانگ chain end-to-end, not only the immediate-show path.
  Future<void> _testBangIn5s() async {
    try {
      await PrayerNotifications.I.scheduleTestBang();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'بانگی تاقیکردنەوە لە ٥ چرکەی تر دەگات — بۆ دەرچوون بکە و چاوەڕوان بە 🔔')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('خشتەکردنی بانگی تاقیکردنەوە سەرکەوتوو نەبوو')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final p = AppPrefs.I;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('ڕێکخستنی بانگ',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          if (!_exactAllowed) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0x1FF44336),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x66F44336))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('ئاگادارکردنەوەی بانگ کارا نییە',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF44336))),
                const SizedBox(height: 4),
                const Text(
                    'ڕێگەی Exact Alarm نەدرا — بڕۆ ناو ڕێکخستنەکانی مۆبایل',
                    style: TextStyle(fontSize: 12.5, height: 1.6)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _enableExactAlarms,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('کردنەوەی ڕێکخستنی مۆبایل'),
                ),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          Text('شار',
              style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: dark ? AppColors.nightCard : const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _cities.any((c) => '${c['id']}' == p.cityId)
                    ? p.cityId : null,
                isExpanded: true,
                items: [
                  for (final c in _cities)
                    DropdownMenuItem(
                        value: '${c['id']}',
                        child: Text('${c['name']}',
                            style: TextStyle(color: txt, fontSize: 13))),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() {
                    p.cityId = v;
                    p.cityName = _cities
                        .where((c) => '${c['id']}' == v)
                        .map((c) => '${c['name']}')
                        .join();
                  });
                  final t = await Db.I.prayerTimes(v, DateTime.now());
                  if (!mounted) return;
                  setState(() => _today = t);
                  await _save();
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_today != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: dark ? AppColors.nightCard : const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(12)),
              child: Wrap(spacing: 14, runSpacing: 8, children: [
                for (final e in _today!.entries)
                  if (kPrayerNames.containsKey(e.key))
                    Text('${kPrayerNames[e.key]}: ${e.value}',
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: dark ? AppColors.gold : AppColors.primaryDark)),
              ]),
            ),
          const SizedBox(height: 14),
          Text('ئاگادارکردنەوەی بانگ',
              style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
          _sw('بانگی بەیانی', p.notifFajr, (v) { setState(() => p.notifFajr = v); _save(); }, txt, dark),
          _sw('بانگی نیوەڕۆ', p.notifDhuhr, (v) { setState(() => p.notifDhuhr = v); _save(); }, txt, dark),
          _sw('بانگی عەسر', p.notifAsr, (v) { setState(() => p.notifAsr = v); _save(); }, txt, dark),
          _sw('بانگی ئێوارە', p.notifMaghrib, (v) { setState(() => p.notifMaghrib = v); _save(); }, txt, dark),
          _sw('بانگی خەوتنان', p.notifIsha, (v) { setState(() => p.notifIsha = v); _save(); }, txt, dark),
          const Divider(height: 20),
          _sw('دەنگی بانگ', p.adhanSoundEnabled, (v) { setState(() => p.adhanSoundEnabled = v); _save(); }, txt, dark),
          _sw('لەرزینی مۆبایل', p.adhanVibrationEnabled, (v) { setState(() => p.adhanVibrationEnabled = v); _save(); }, txt, dark),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.record_voice_over_rounded,
                color: AppColors.primaryDark),
            title: Text('دەنگی بانگبێژ', style: TextStyle(fontSize: 14, color: txt)),
            subtitle: Text('دەنگی هەڵبژێردراو : ${p.adhanVoiceName}',
                style: TextStyle(
                    fontSize: 11, color: txt.withValues(alpha: .55))),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AdhanVoiceScreen()))
                .then((_) => setState(() {})),
          ),
          OutlinedButton.icon(
            onPressed: _testBangIn5s,
            icon: const Icon(Icons.alarm_add_rounded),
            label: const Text('تاقیکردنەوەی بانگ (لە ٥ چرکە)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testAdhan,
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('تاقیکردنەوەی دەنگی بانگ'),
          ),
          if (Theme.of(context).platform == TargetPlatform.android) ...[
            OutlinedButton.icon(
              onPressed: _enableExactAlarms,
              icon: const Icon(Icons.alarm_on_rounded),
              label: const Text('چالاککردنی کاتی وردی بانگ'),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _save,
              icon: const Icon(Icons.notifications_active_rounded),
              label: const Text('دووبارە خشتەکردنی ئاگادارکردنەوەکان')),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _sw(String title, bool value, ValueChanged<bool> onChanged,
          Color txt, bool dark) =>
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.primaryDark,
          title: Text(title, style: TextStyle(fontSize: 14, color: txt)),
          value: value,
          onChanged: onChanged);
}
