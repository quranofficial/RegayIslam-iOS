import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import '../../core/constants.dart';
import '../../core/kurdish_date.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../quran/open_quran.dart' show toArabicDigits;

/// Original: PrayersmonthActivity — monthly prayer-time table from time2.db.
class PrayersMonthScreen extends StatefulWidget {
  const PrayersMonthScreen({super.key});
  @override
  State<PrayersMonthScreen> createState() => _PrayersMonthScreenState();
}

class _PrayersMonthScreenState extends State<PrayersMonthScreen> {
  int _month = DateTime.now().month;
  List<Map<String, Object?>> _rows = [];
  bool _loading = true;
  final GlobalKey _tableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await Db.I.prayerMonth(AppPrefs.I.cityId, _month);
    if (!mounted) return;
    setState(() { _rows = rows; _loading = false; });
  }

  static const _cols = [
    ('D', 'بەروار'),
    ('bayani', 'بەیانی'),
    ('xorhalatn', 'گزنک'),
    ('niwaro', 'نیوەڕۆ'),
    ('asr', 'عەسر'),
    ('eywara', 'ئێوارە'),
    ('esha', 'خەوتنان'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    const months = [
      'کانوونی دووەم', 'شوبات', 'ئازار', 'نیسان', 'ئایار', 'حوزەیران',
      'تەمووز', 'ئاب', 'ئەیلوول', 'تشرینی یەکەم', 'تشرینی دووەم', 'کانوونی یەکەم'
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Text('کاتەکانی ${AppPrefs.I.cityName}',
              style: const TextStyle(color: Colors.white, fontSize: 17)),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: dark ? AppColors.nightCard : const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _month,
                  isExpanded: true,
                  items: [
                    for (var i = 1; i <= 12; i++)
                      DropdownMenuItem(value: i, child: Text(months[i - 1],
                          style: TextStyle(color: txt))),
                  ],
                  onChanged: (v) { setState(() => _month = v!); _load(); },
                ),
              ),
            ),
          ),
          _loading
              ? const Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      child: RepaintBoundary(
                      key: _tableKey,
                      child: Container(
                      color: dark ? AppColors.nightBg : Colors.white,
                      padding: const EdgeInsets.all(10),
                      child: Column(children: [
                      Text('کاتەکانی نوێژ — ${AppPrefs.I.cityName} — مانگی $_month',
                          style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 14, color: txt)),
                      const SizedBox(height: 6),
                      Text('ڕێگای ئیسلام',
                          style: TextStyle(fontSize: 10,
                              color: txt.withOpacity(.45))),
                      const SizedBox(height: 4),
                      DataTable(
                        headingRowColor:
                            WidgetStatePropertyAll(dark ? AppColors.nightCard : const Color(0xFFE8F0FE)),
                        dataRowMinHeight: 34, dataRowMaxHeight: 38,
                        columnSpacing: 18,
                        columns: [
                          for (final c in _cols)
                            DataColumn(label: Text(c.$2,
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 12, color: txt))),
                        ],
                        rows: [
                          for (final r in _rows)
                            DataRow(cells: [
                              // Item 16: the day carries all three formats —
                              // weekday, Hijri date and the normal date.
                              DataCell(_dateCell(r['D'], txt)),
                              for (final c in _cols.skip(1))
                                DataCell(Text(_fmt(r[c.$1]),
                                    style: TextStyle(fontSize: 12, color: txt))),
                            ]),
                        ],
                      ),
                      ]),
                      ),
                    ),
                  ),
                ),
                ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: dark ? AppColors.gold : AppColors.primaryDark,
                    foregroundColor: dark ? Colors.black : Colors.white),
                onPressed: _saveImage,
                icon: const Icon(Icons.save_alt_rounded, size: 20),
                label: const Text('پاشەکەوتکردنی وێنە بۆ گەلەری مۆبایل'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// Item 11: one-tap capture of the monthly timetable into the phone
  /// gallery (MediaStore via gal — no storage permission on Android 10+).
  Future<void> _saveImage() async {
    try {
      final boundary = _tableKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('no boundary');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.png))
              ?.buffer
              .asUint8List();
      if (bytes == null) throw Exception('encode failed');
      await Gal.putImageBytes(bytes, album: 'ڕێگای ئیسلام');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('وێنەکە پاشەکەوت کرا بۆ گەلەری ✅')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('پاشەکەوتکردن سەرکەوتوو نەبوو — '
              'مۆڵەتی وێنە پشتڕاست بکەوە')));
      final ok = await Gal.requestAccess();
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مۆڵەت درا — دووبارە هەوڵبدەرەوە')));
      }
    }
  }

  String _fmt(Object? v) {
    if (v == null) return '';
    final s = v.toString();
    if (RegExp(r'^\d{2}-\d{2}$').hasMatch(s)) {
      final p = s.split('-');
      return '${toArabicDigits(int.parse(p[1]))}/${toArabicDigits(int.parse(p[0]))}';
    }
    return s;
  }

  /// Item 16: three-line date cell — weekday (شەممە…) + Hijri date +
  /// normal (Gregorian) date, all in Sorani.
  Widget _dateCell(Object? v, Color txt) {
    final s = '${v ?? ''}';
    final m = RegExp(r'^(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) {
      return Text(_fmt(v), style: TextStyle(fontSize: 12, color: txt));
    }
    final now = DateTime.now();
    final d = DateTime(now.year, int.parse(m.group(1)!), int.parse(m.group(2)!));
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(weekdayKu(d), style: TextStyle(fontSize: 11.5,
          fontWeight: FontWeight.bold, color: txt)),
      Text(hijriKu(d), style: TextStyle(fontSize: 10,
          color: txt.withOpacity(.8))),
      Text(gregorianKu(d), style: TextStyle(fontSize: 10,
          color: txt.withOpacity(.6))),
    ]);
  }
}
