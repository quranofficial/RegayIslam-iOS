/// Kurdish (Sorani) date formatting — item 16:
/// "لە کاتەکانی بانگ ڕۆژەکە بە سێ شێواز بنووسرێت":
///   • the weekday in Kurdish (شەممە، یەکشەممە، …، هەینی);
///   • the Hijri date (بەرواری حێجری) with Kurdish month names;
///   • the normal (Gregorian) date (بەرواری ئاسایی).
/// All three ride together wherever prayer times show a day.
library;

const List<String> kWeekdaysKu = [
  'دووشەممە', // Monday
  'سێشەممە', // Tuesday
  'چوارشەممە', // Wednesday
  'پێنجشەممە', // Thursday
  'هەینی', // Friday
  'شەممە', // Saturday
  'یەکشەممە', // Sunday
];

const List<String> kGregMonthsKu = [
  'کانوونی دووەم', 'شوبات', 'ئازار', 'نیسان', 'ئایار', 'حوزەیران',
  'تەمووز', 'ئاب', 'ئەیلوول', 'تشرینی یەکەم', 'تشرینی دووەم', 'کانوونی یەکەم',
];

const List<String> kHijriMonthsKu = [
  'موحەڕەم', 'سەفەر', 'ڕەبیع الاول', 'ڕەبیعی دووەم',
  'جەمادیولولا', 'جەمادیولاخر', 'ڕەجەب', 'شەعبان',
  'ڕەمەزان', 'شەوال', 'زولقەعدە', 'زولحەججە',
];

/// Kurdish/Arabic-Indic digits (independent of the app preference — the
/// date triple stays readable inside images/tables).
String kuDigits(int n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

/// Tabular (Kuwaiti-algorithm) Hijri date for a Gregorian date. Offline —
/// no API needed; like every tabular calendar it can drift ±1 day from the
/// moon sighting.
(int, int, int) hijriOf(DateTime g) {
  final a = (14 - g.month) ~/ 12;
  final y2 = g.year + 4800 - a;
  final m2 = g.month + 12 * a - 3;
  final jdn = g.day +
      (153 * m2 + 2) ~/ 5 +
      365 * y2 +
      y2 ~/ 4 -
      y2 ~/ 100 +
      y2 ~/ 400 -
      32045;
  var l = jdn - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
      (l ~/ 5670) * ((43 * l) ~/ 15238);
  l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
      (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
  final hm = (24 * l) ~/ 709;
  final hd = l - (709 * hm) ~/ 24;
  final hy = 30 * n + j - 30;
  return (hy, hm, hd);
}

/// The weekday name (DateTime.weekday: 1 = Monday .. 7 = Sunday).
String weekdayKu(DateTime d) => kWeekdaysKu[d.weekday - 1];

/// "هەینی • ١٤ی تشرینی دووەم ٢٠٢٦" — the normal (Gregorian) line.
String gregorianKu(DateTime d) =>
    '${kuDigits(d.day)}ی ${kGregMonthsKu[d.month - 1]} ${kuDigits(d.year)}';

/// "١٤ی جەمادیولاخر ١٤٤٧" — the Hijri line.
String hijriKu(DateTime d) {
  final (hy, hm, hd) = hijriOf(d);
  return '${kuDigits(hd)}ی ${kHijriMonthsKu[hm - 1]} ${kuDigits(hy)}';
}

/// Item 16: the full three-format line used where prayer times show a day:
/// "شەممە — ٦ی تشرینی دووەم ٢٠٢٦ — ٢٥ی جەمادیولولا ١٤٤٨"
String fullDateKu(DateTime d) =>
    '${weekdayKu(d)} — ${gregorianKu(d)} — ${hijriKu(d)}';
