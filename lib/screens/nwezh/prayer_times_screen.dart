import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../nwezh/prayers_month.dart';
import '../nwezh/nwezhi_settings.dart';

/// Dedicated prayer-times page; it is separate from the prayer-learning hub.
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});
  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  Map<String, String>? _times;
  List<Map<String, Object?>> _cities = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        Db.I.prayerTimes(AppPrefs.I.cityId, DateTime.now()),
        Db.I.cities(),
      ]);
      if (!mounted) return;
      setState(() {
        _times = results[0] as Map<String, String>?;
        _cities = results[1] as List<Map<String, Object?>>;
        _loading = false;
        if (_times == null) _error = 'کاتی ئەمڕۆ لە داتابەیسدا نەدۆزرایەوە';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'نەتوانرا کاتەکانی بانگ بهێنرێن'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final card = dark ? AppColors.nightCard : Colors.white;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('کاتەکانی بانگ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: const Icon(Icons.settings_rounded, color: Colors.white),
              tooltip: 'ڕێکخستنی بانگ',
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const NwezhiSettingsScreen())).then((_) => _load())),
          ],
        ),
        body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(14), children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: card,
                  borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('شار: ${AppPrefs.I.cityName}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: txt)),
                  const SizedBox(height: 4),
                  Text('${DateTime.now().year}/${DateTime.now().month}/${DateTime.now().day}',
                    style: TextStyle(color: txt.withOpacity(.55))),
                  if (_cities.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _cities.any((c) => '${c['id']}' == AppPrefs.I.cityId)
                        ? AppPrefs.I.cityId : null,
                      decoration: const InputDecoration(labelText: 'گۆڕینی شار'),
                      items: [for (final c in _cities)
                        DropdownMenuItem(value: '${c['id']}',
                          child: Text('${c['name']}'))],
                      onChanged: (v) async {
                        if (v == null) return;
                        AppPrefs.I.cityId = v;
                        AppPrefs.I.cityName = _cities
                            .where((c) => '${c['id']}' == v)
                            .map((c) => '${c['name']}')
                            .join();
                        await _load();
                      },
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              else
                for (final entry in kPrayerNames.entries)
                  Card(
                    color: card,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: dark ? AppColors.gold.withOpacity(.15)
                          : AppColors.primaryDark.withOpacity(.08),
                        child: Icon(Icons.access_time_rounded,
                          color: dark ? AppColors.gold : AppColors.primaryDark)),
                      title: Text(entry.value,
                        style: TextStyle(fontWeight: FontWeight.w600, color: txt)),
                      trailing: Text(_times?[entry.key] ?? '--:--',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                          color: dark ? AppColors.gold : AppColors.primaryDark)),
                    ),
                  ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const PrayersMonthScreen())),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('خشتەی کاتەکانی مانگ'),
              ),
            ]),
      ),
    );
  }
}
