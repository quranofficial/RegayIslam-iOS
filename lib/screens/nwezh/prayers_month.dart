import 'package:flutter/material.dart';
import '../../core/constants.dart';
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
    ('xorhalatn', 'گزشتن'),
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
                      child: DataTable(
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
                              for (final c in _cols)
                                DataCell(Text(_fmt(r[c.$1]),
                                    style: TextStyle(fontSize: 12, color: txt))),
                            ]),
                        ],
                      ),
                    ),
                  ),
                ),
        ]),
      ),
    );
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
}
