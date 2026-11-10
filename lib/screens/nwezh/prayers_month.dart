import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/kurdish_date.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show kAppUrl;
import '../../data/db.dart';
import '../quran/open_quran.dart' show toArabicDigits;

/// Original: PrayersmonthActivity — monthly prayer-time table from time2.db,
/// rebuilt as a print-quality sheet (item 5-c): the printable part stays
/// white even in night mode, with a primary-dark header band, striped rows,
/// gold Friday highlighting and a "پرینت / هاوبەشی وێنە" action that renders
/// the sheet to a 3x PNG and hands it to the system share sheet.
class PrayersMonthScreen extends StatefulWidget {
  const PrayersMonthScreen({super.key});
  @override
  State<PrayersMonthScreen> createState() => _PrayersMonthScreenState();
}

class _PrayersMonthScreenState extends State<PrayersMonthScreen> {
  static const List<(String, String)> _cols = [
    ('D', 'بەروار'),
    ('bayani', 'بەیانی'),
    ('xorhalatn', 'گزنک'),
    ('niwaro', 'نیوەڕۆ'),
    ('asr', 'عەسر'),
    ('eywara', 'ئێوارە'),
    ('esha', 'خەوتنان'),
  ];

  static const List<String> _months = [
    'کانوونی دووەم', 'شوبات', 'ئازار', 'نیسان', 'ئایار', 'حوزەیران',
    'تەمووز', 'ئاب', 'ئەیلوول', 'تشرینی یەکەم', 'تشرینی دووەم', 'کانوونی یەکەم',
  ];

  // --- palette of the PRINTED sheet (always light, never themed) ---
  static const Color _grid = Color(0xFFDDDDDD); // thin table borders
  static const Color _stripe = Color(0xFFF7F7F7); // alternating rows
  static const Color _sep = Color(0xFFBBBBBB); // date-column separator
  static const Color _ink = Color(0xFF1A1A1A); // sheet body text
  static const Color _inkSoft = Color(0xFF6B6B6B); // secondary sheet text
  static const Color _fridayInk = Color(0xFF8F7223); // readable gold on white

  int _month = DateTime.now().month;
  List<Map<String, Object?>> _rows = [];
  bool _loading = true;
  bool _busy = false;
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

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final year = DateTime.now().year;
    final w = MediaQuery.sizeOf(context).width;
    // Wide enough for a readable print sheet; phones scroll it sideways.
    final sheetW = (w - 24).clamp(520.0, 680.0).toDouble();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF0F2F6),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          foregroundColor: Colors.white,
          title: Text('کاتەکانی نوێژ — ${AppPrefs.I.cityName}',
              style: const TextStyle(color: Colors.white, fontSize: 16.5,
                  fontWeight: FontWeight.w700)),
          actions: [
            if (!_loading && _rows.isNotEmpty)
              IconButton(
                tooltip: 'پرینت / هاوبەشی وێنە',
                onPressed: _busy ? null : _shareImage,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2,
                            color: Colors.white))
                    : const Icon(Icons.print_outlined, size: 22),
              ),
          ],
        ),
        body: Column(children: [
          _monthSelector(dark, txt, year),
          _printHint(dark),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(
                    color: dark ? AppColors.gold : AppColors.primaryDark))
                : _rows.isEmpty
                    ? _emptyState(dark, txt)
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            width: sheetW,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: .12),
                                    blurRadius: 14, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: RepaintBoundary(
                              key: _tableKey,
                              child: Column(children: [
                                _sheetHeader(year),
                                Container(height: 3, color: AppColors.gold),
                                _sheetTable(year),
                                _sheetFooter(),
                              ]),
                            ),
                          ),
                        ),
                      ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: dark ? AppColors.gold : AppColors.primaryDark,
                    foregroundColor: dark ? Colors.black : Colors.white),
                onPressed: _busy ? null : _saveImage,
                icon: const Icon(Icons.save_alt_rounded, size: 20),
                label: const Text('پاشەکەوتکردنی وێنە بۆ گەلەری مۆبایل'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------------ chrome

  Widget _monthSelector(bool dark, Color txt, int year) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: dark ? AppColors.nightCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark
                  ? Colors.white.withValues(alpha: .08)
                  : const Color(0xFFE3E6EC)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _month,
                isExpanded: true,
                icon: Icon(Icons.expand_more_rounded, size: 20,
                    color: dark ? AppColors.gold : AppColors.primaryDark),
                dropdownColor: dark ? AppColors.nightCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                items: [
                  for (var i = 1; i <= 12; i++)
                    DropdownMenuItem(value: i, child: Text(_months[i - 1],
                        style: TextStyle(color: txt, fontSize: 13.5))),
                ],
                onChanged: (v) { setState(() => _month = v!); _load(); },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: dark ? AppColors.gold : AppColors.primaryDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_dg('$year'),
              style: const TextStyle(color: Colors.white, fontSize: 13.5,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _printHint(bool dark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: .05)
            : AppColors.primaryDark.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dark
            ? Colors.white.withValues(alpha: .1)
            : AppColors.primaryDark.withValues(alpha: .12)),
      ),
      child: Row(children: [
        Icon(Icons.print_rounded, size: 16,
            color: dark ? AppColors.gold : AppColors.primaryDark),
        const SizedBox(width: 8),
        Expanded(
          child: Text('بۆ پرینت: پەیوەند بە وێنەکە بکە و لە پۆستەر بیکە '
              '• شێوەی پانی (Landscape) باشترە',
              style: TextStyle(fontSize: 11,
                  color: dark
                      ? Colors.white.withValues(alpha: .75)
                      : Colors.black.withValues(alpha: .7))),
        ),
      ]),
    );
  }

  Widget _emptyState(bool dark, Color txt) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.event_busy_rounded, size: 42,
          color: dark ? AppColors.gold : AppColors.primaryDark),
      const SizedBox(height: 10),
      Text('داتای کاتەکانی نوێژ بۆ ئەم مانگە بەردەست نییە',
          style: TextStyle(fontSize: 13, color: txt.withValues(alpha: .8))),
    ]));
  }

  // ------------------------------------------------------- printable sheet

  /// Dark header band of the printed sheet — city, Kurdish month + year and
  /// the Hijri range of the month.
  Widget _sheetHeader(int year) {
    final first = DateTime(year, _month, 1);
    final last = DateTime(year, _month + 1, 0);
    return Container(
      width: double.infinity,
      color: AppColors.primaryDark,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(children: [
        const Text('کاتەکانی نوێژ',
            style: TextStyle(fontFamily: 'Rabar', fontSize: 21,
                fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
        const SizedBox(height: 4),
        Text('${AppPrefs.I.cityName} — ${_months[_month - 1]} ${_dg('$year')}',
            style: const TextStyle(fontFamily: 'Rabar', fontSize: 13,
                fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 3),
        Text('${hijriKu(first)} — ${hijriKu(last)}',
            style: TextStyle(fontSize: 10.5,
                color: Colors.white.withValues(alpha: .72))),
      ]),
    );
  }

  /// The days × prayer-times table. Column names ride from time2.db as-is.
  Widget _sheetTable(int year) {
    return Table(
      textDirection: TextDirection.rtl,
      border: TableBorder.all(color: _grid, width: .8),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
        5: FlexColumnWidth(1),
        6: FlexColumnWidth(1),
      },
      children: [
        TableRow(children: [
          for (final c in _cols) _headCell(c.$2),
        ]),
        for (var i = 0; i < _rows.length; i++) _dataRow(_rows[i], i, year),
      ],
    );
  }

  Widget _headCell(String label) {
    return Container(
      color: AppColors.primaryDark,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      alignment: Alignment.center,
      child: Text(label,
          style: const TextStyle(fontFamily: 'Rabar', fontSize: 11.5,
              fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  TableRow _dataRow(Map<String, Object?> r, int i, int year) {
    final d = _dayOf(r['D'], year);
    final friday = d != null && d.weekday == DateTime.friday;
    final bg = friday
        ? AppColors.gold.withValues(alpha: .12)
        : (i.isOdd ? _stripe : Colors.white);
    return TableRow(children: [
      _cell(_dayCell(r['D'], d, friday), bg: bg, dateCol: true),
      for (final c in _cols.skip(1))
        _cell(_timeCell(r[c.$1], friday),
            bg: bg, firstTime: c.$1 == _cols[1].$1),
    ]);
  }

  /// Three-line date cell: bold day number, weekday, Hijri, then the normal
  /// (Gregorian) date — all three formats ride together (item 16).
  Widget _dayCell(Object? v, DateTime? d, bool friday) {
    if (d == null) {
      return Text(_fmt(v), style: const TextStyle(fontSize: 11, color: _ink));
    }
    final dayColor = friday ? _fridayInk : _ink;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${_dg('${d.day}')}/${_dg('${d.month}')}',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800,
              color: dayColor, height: 1.1)),
      Text(weekdayKu(d),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: dayColor, height: 1.25)),
      _fit(Text(hijriKu(d), style: const TextStyle(fontSize: 8.5,
          color: _inkSoft, height: 1.2))),
      _fit(Text(gregorianKu(d), style: TextStyle(fontSize: 8.5,
          color: _inkSoft.withValues(alpha: .75), height: 1.2))),
    ]);
  }

  Widget _timeCell(Object? v, bool friday) {
    return Text(_dg('${v ?? ''}'),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: friday ? _fridayInk : _ink));
  }

  Widget _cell(Widget child, {required Color bg, bool dateCol = false,
      bool firstTime = false}) {
    const BorderSide sep = BorderSide(width: 1.3, color: _sep);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: dateCol
            ? const Border(left: sep)
            : (firstTime ? const Border(right: sep) : null),
      ),
      child: child,
    );
  }

  /// Keeps the long Hijri/Gregorian lines inside the narrow date column.
  Widget _fit(Text t) => FittedBox(fit: BoxFit.scaleDown, child: t);

  Widget _sheetFooter() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 11, height: 11,
              decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: .12),
                  border: Border.all(color: AppColors.gold, width: .8))),
          const SizedBox(width: 6),
          const Text('ڕۆژی هەینی',
              style: TextStyle(fontSize: 9.5, color: _inkSoft)),
        ]),
        const SizedBox(height: 6),
        Container(height: 1, color: _grid),
        const SizedBox(height: 7),
        const Text('ڕێگای ئیسلام',
            style: TextStyle(fontFamily: 'Rabar', fontSize: 11.5,
                fontWeight: FontWeight.w800, color: Color(0xFF333333))),
        Text(kAppUrl.replaceFirst('https://', ''),
            style: TextStyle(fontSize: 9.5,
                color: _inkSoft.withValues(alpha: .8))),
      ]),
    );
  }

  // ---------------------------------------------------------- image export

  /// Renders the RepaintBoundary sheet to a PNG at 3x — sharp enough to
  /// print as a poster (item 5-c).
  Future<Uint8List?> _renderTablePng() async {
    final boundary =
        _tableKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    return (await image.toByteData(format: ui.ImageByteFormat.png))
        ?.buffer
        .asUint8List();
  }

  /// Appbar action "پرینت / هاوبەشی وێنە": PNG → temp file → share sheet
  /// (same temp-file pattern as QuranStudio; the OS print targets are
  /// reachable from there).
  Future<void> _shareImage() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _renderTablePng();
      if (bytes == null) throw Exception('no boundary');
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}'
          '/regayislam-prayers-${AppPrefs.I.cityId}-$_month.png');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path, mimeType: 'image/png')],
          text: 'کاتەکانی نوێژی ${AppPrefs.I.cityName} — '
              'مانگی ${_months[_month - 1]} — ڕێگای ئیسلام');
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('وێنەکە ئامادە نەبوو — دووبارە هەوڵبدەرەوە')));
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Item 11: one-tap capture of the monthly timetable into the phone
  /// gallery (MediaStore via gal — no storage permission on Android 10+).
  Future<void> _saveImage() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _renderTablePng();
      if (bytes == null) throw Exception('no boundary');
      await Gal.putImageBytes(bytes, album: 'ڕێگای ئیسلام');
      messenger.showSnackBar(const SnackBar(
          content: Text('وێنەکە پاشەکەوت کرا بۆ گەلەری ✅')));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
          content: const Text('پاشەکەوتکردن سەرکەوتوو نەبوو — '
              'مۆڵەتی وێنە پشتڕاست بکەوە'),
          action: SnackBarAction(
              label: 'مۆڵەت',
              onPressed: () async {
                final ok = await Gal.requestAccess();
                if (ok) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('مۆڵەت درا — دووبارە هەوڵبدەرەوە')));
                }
              })),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  // -------------------------------------------------------------- helpers

  /// Kurdish digits applied per character, honouring the user's numeral
  /// preference (toArabicDigits already used by this screen).
  String _dg(String s) {
    final b = StringBuffer();
    for (final c in s.split('')) {
      final n = int.tryParse(c);
      b.write(n == null ? c : toArabicDigits(n));
    }
    return b.toString();
  }

  DateTime? _dayOf(Object? v, int year) {
    final m = RegExp(r'^(\d{2})-(\d{2})$').firstMatch('${v ?? ''}');
    if (m == null) return null;
    return DateTime(year, int.parse(m.group(1)!), int.parse(m.group(2)!));
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
