import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/prayer_notifications.dart';

/// Original: DastnwezhActivity — user-defined manual prayer times.
class DastnwezhScreen extends StatefulWidget {
  const DastnwezhScreen({super.key});
  @override
  State<DastnwezhScreen> createState() => _DastnwezhScreenState();
}

class _DastnwezhScreenState extends State<DastnwezhScreen> {
  late Map<String, TextEditingController> _controllers;
  TimeOfDay? _pick(String key) {
    final v = _controllers[key]!.text;
    if (v.isEmpty) return null;
    final p = v.split(':');
    if (p.length != 2) return null;
    return TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p[1]) ?? 0);
  }

  @override
  void initState() {
    super.initState();
    final manual = AppPrefs.I.manualTimes();
    _controllers = {
      for (final k in ['bayani', 'niwaro', 'asr', 'eywara', 'esha'])
        k: TextEditingController(text: manual[k] ?? ''),
    };
  }

  Future<void> _pickTime(String key) async {
    final t = await showTimePicker(
        context: context, initialTime: _pick(key) ?? TimeOfDay.now());
    if (t != null) {
      setState(() =>
          _controllers[key]!.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    for (final e in _controllers.entries) {
      AppPrefs.I.setManualTime(e.key, e.value.text);
    }
    AppPrefs.I.useManual = true;
    await PrayerNotifications.I.scheduleAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کاتەکان پاشەکەوتکران ✅')));
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final labels = {
      'bayani': 'بەیانی (فەجر)',
      'niwaro': 'نیوەڕۆ (زوھر)',
      'asr': 'عەسر',
      'eywara': 'ئێوارە (مەغریب)',
      'esha': 'خەوتنان (عیشا)',
    };
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('دەستنوێژ (کاتی دەستی)',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('کاتەکان بە دەست دیاری بکە (شێوەی 24 کاتژمێر، بۆ نموونە 05:45)',
              style: TextStyle(fontSize: 12.5, color: txt.withOpacity(.6))),
          const SizedBox(height: 14),
          for (final e in _controllers.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: dark ? Colors.white12 : Colors.black12)),
                tileColor: dark ? AppColors.nightCard : const Color(0xFFF9FAFB),
                title: Text(labels[e.key]!,
                    style: TextStyle(fontSize: 14, color: txt)),
                trailing: Text(e.value.text.isEmpty ? '--:--' : e.value.text,
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark)),
                onTap: () => _pickTime(e.key),
              ),
            ),
          const SizedBox(height: 6),
          ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13)),
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('پاشەکەوتکردن')),
        ]),
      ),
    );
  }
}
