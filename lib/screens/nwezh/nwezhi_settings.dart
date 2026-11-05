import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await Db.I.prayerTimes(AppPrefs.I.cityId, DateTime.now());
    final c = await Db.I.cities();
    if (!mounted) return;
    setState(() { _today = t; _cities = c; });
  }

  Future<void> _save() async {
    await PrayerNotifications.I.scheduleAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ئاگادارکردنەوەکان نوێکرانەوە ✅')));
  }

  Future<void> _enableExactAlarms() async {
    final allowed = await PrayerNotifications.I.requestExactAlarmPermission();
    if (!mounted) return;
    await PrayerNotifications.I.scheduleAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(allowed
        ? 'ئاگادارکردنەوەی کاتی ورد چالاک کرا ✅'
        : 'مۆڵەتی کاتی ورد نەدرا؛ ئاگادارکردنەوەکان بە شێوەی ئاسایی دادەنرێن'),
    ));
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
                value: p.cityId,
                isExpanded: true,
                items: [
                  for (final c in _cities)
                    DropdownMenuItem(
                        value: '${c['name']}',
                        child: Text('${c['name']}',
                            style: TextStyle(color: txt, fontSize: 13))),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() { p.cityId = v; p.cityName = v; });
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
                style: TextStyle(fontSize: 11, color: txt.withOpacity(.55))),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AdhanVoiceScreen()))
                .then((_) => setState(() {})),
          ),
          OutlinedButton.icon(
            onPressed: () => PrayerNotifications.I.showNow(
              'تاقیکردنەوەی بانگ', 'ئەمە تاقیکردنەوەی دەنگی بانگە'),
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
          activeColor: AppColors.primaryDark,
          title: Text(title, style: TextStyle(fontSize: 14, color: txt)),
          value: value,
          onChanged: onChanged);
}
