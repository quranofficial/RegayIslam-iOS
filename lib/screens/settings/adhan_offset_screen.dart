import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/prayer_notifications.dart';

/// Original: BrdnapeshActivity — دواخستن و پێشخستنی کاتی بانگدان.
/// Per-prayer adhan offsets (-60..+60 minutes) applied when the
/// notifications are scheduled; changing a slider reschedules them.
class AdhanOffsetScreen extends StatefulWidget {
  const AdhanOffsetScreen({super.key});
  @override
  State<AdhanOffsetScreen> createState() => _AdhanOffsetScreenState();
}

class _AdhanOffsetScreenState extends State<AdhanOffsetScreen> {
  late final List<(String, String, int Function(), void Function(int))> _rows;

  @override
  void initState() {
    super.initState();
    final p = AppPrefs.I;
    _rows = [
      ('بانگی بەیانی', 'bayani', () => p.offsetBayani, (v) => p.offsetBayani = v),
      ('بانگی نیوەڕۆ', 'niwaro', () => p.offsetNiwaro, (v) => p.offsetNiwaro = v),
      ('بانگی عەسر', 'asr', () => p.offsetAsr, (v) => p.offsetAsr = v),
      ('بانگی ئێوارە', 'eywara', () => p.offsetEywara, (v) => p.offsetEywara = v),
      ('بانگی خەوتنان', 'esha', () => p.offsetIsha, (v) => p.offsetIsha = v),
    ];
  }

  String _label(int v) {
    if (v == 0) return 'بێ گۆڕان';
    if (v > 0) return '$v خولەك پێشخراوە';
    return '${-v} خولەك دواخراوە';
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('دواخستن و پێشخستنی کاتی بانگدان',
              style: TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Card(
            color: dark ? AppColors.nightCard : Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'کاتی بانگی هەر نوێژێک بە خولەک بدواخە یان پێشی بخە — نێگەتیڤ = دواخستن، پۆزیتیڤ = پێشخستن.',
                style: TextStyle(height: 1.7, color: txt)),
            ),
          ),
          const SizedBox(height: 8),
          for (final row in _rows)
            Card(
              color: dark ? AppColors.nightCard : Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Column(children: [
                  Row(children: [
                    Icon(Icons.notifications_active_rounded,
                        size: 18, color: AppColors.primaryDark),
                    const SizedBox(width: 8),
                    Text(row.$1,
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 14, color: txt)),
                    const Spacer(),
                    Text(_label(row.$3()),
                        style: TextStyle(fontSize: 12,
                            color: row.$3() == 0
                                ? txt.withOpacity(.55)
                                : AppColors.gold)),
                  ]),
                  Slider(
                      min: -60, max: 60, divisions: 120,
                      label: '${row.$3()}',
                      activeColor: AppColors.primaryDark,
                      value: row.$3().clamp(-60, 60).toDouble(),
                      onChanged: (v) => setState(() => row.$4(v.round())),
                      onChangeEnd: (_) =>
                          PrayerNotifications.I.scheduleAll()),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('-٦٠', style: TextStyle(
                            fontSize: 11, color: txt.withOpacity(.5))),
                        Text('٦٠+', style: TextStyle(
                            fontSize: 11, color: txt.withOpacity(.5))),
                      ]),
                ]),
              ),
            ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }
}
