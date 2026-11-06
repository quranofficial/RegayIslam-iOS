import 'package:flutter/material.dart';

/// App-wide constants ported from the original Sketchware Pro project
/// (project.json + block colors used across screens).
class AppColors {
  static const Color primary = Color(0xFF000000); // color_primary
  static const Color primaryDark = Color(0xFF004D7B); // color_primary_dark
  static const Color accent = Color(0xFF000000); // color_accent
  static const Color nightBg = Color(0xFF303030); // night-mode background
  static const Color nightCard = Color(0xFF212121); // night-mode card bg
  static const Color dayBg = Colors.white;
  static const Color green = Color(0xFF4CAF50);
  static const Color red = Color(0xFFF44336);
  static const Color gold = Color(0xFFC8A24B);
}

/// Names of the five daily prayers as used in the app (time2.db columns).
const Map<String, String> kPrayerNames = {
  'bayani': 'بەیانی',
  'xorhalatn': 'گزنک',
  'niwaro': 'نیوەڕۆ',
  'asr': 'عەسر',
  'eywara': 'ئێوارە',
  'esha': 'خەوتنان',
};

const String kDbUrl = 'https://regayislam-1-default-rtdb.firebaseio.com';

/// Item 22: password of the in-app admin panel (ڕێکخستن → پانێلی بەڕێوەبەر).
/// Requested by the owner: "ismahil123".
const String kAdminPassword = 'ismahil123';

/// Tafsir columns of regayislam.db (ayah_text). The real column names are
/// "maiser" and "zhin" — the old list said "masier"/"zhian" which made the
/// whole Quran reader crash (empty list) whenever one of those was chosen.
const List<String> kTafsirs = [
  'rebar',
  'raman',
  'roshn',
  'sanahi',
  'hazhar',
  'tawhid',
  'asan',
  'maiser',
  'zhin',
  'puxta',
];

const Map<String, String> kTafsirNames = {
  'rebar': 'ڕێبەری سەرفیڕاز',
  'raman': 'ڕەمان',
  'roshn': 'ڕۆشن',
  'sanahi': 'سەناهی',
  'hazhar': 'هەژار',
  'tawhid': 'تەوحید',
  'asan': 'ئاسان',
  'maiser': 'مەیسر',
  'zhin': 'ژیان',
  'puxta': 'پوختە',
};

/// Old saved prefs may still hold the pre-fix spellings — map them onto the
/// real DB columns so no screen ever queries a missing column again.
const Map<String, String> kTafsirLegacy = {
  'masier': 'maiser',
  'zhian': 'zhin',
};

const List<String> kFontsUi = ['Rabar', 'Rabar2', 'NRT', 'Rudaw', 'Speda', 'Oko', 'Zyad'];
const List<String> kFontsQuran = ['Quran', 'Quran1', 'Quran3', 'Quran5', 'Quran7', 'Quran9'];

/// The article JSON files opened from the Home tab cards (Hack1Activity).
const Map<String, List<String>> kJsonCards = {
  'assets/data/zikrakan.json': ['زیکرەکان', 'زیکرەکان'],
  'assets/data/duha.json': ['دوعا و پاڕانەوە', 'دووعاكان'],
  'assets/data/agr.json': ['ئەهلی ئاگر', 'بابەتی ئەهلی ئاگر'],
  'assets/data/bahasht.json': ['بەهەشت', 'بابەتی بەهەشت'],
  'assets/data/xawn.json': ['خەونامە', 'بابەتی خەونامە'],
  'assets/data/wta.json': ['وتە و ئامۆژگاری', 'وتەکان'],
  'assets/data/zianakanygorani.json': ['زیانەکانی گۆرانی', 'زیانەکانی گۆرانی'],
  'assets/data/pexambarman.json': ['ژیانی پێغەمبەرمان ﷺ', 'ژیانی پێغەمبەرمان ﷺ'],
  'assets/data/pexambaran.json': ['ژیانی پێغەمبەران', 'ژیانی پێغەمبەران'],
  'assets/data/haram.json': ['حەڕام کراوەکان', 'حەڕام کراوەکان'],
  'assets/data/swnat.json': ['سونەت', 'بابەتی سونەت'],
  'assets/data/xaybat.json': ['تاوانی غەیبەت', 'تاوانی غەیبەت'],
  'assets/data/dajal.json': ['چیرۆکی دەجال', 'چیرۆکی دەجال'],
  'assets/data/hawal.json': ['هاوەڵانی پێغەمبەر ﷺ', 'هاوەڵانی پێغەمبەر ﷺ'],
  'assets/data/zanyaryquran.json': ['زانیاری قورئان', 'زانیاری قورئان'],
  'assets/data/tawanakan.json': ['تاوانەگەورەکان', 'تاوانەگەورەکان'],
  'assets/data/rawbochwn.json': ['ڕاو بۆچونەکان', 'ڕاو بۆچونەکان'],
  'assets/data/dozax.json': ['دۆزەخ', 'بابەتی دۆزەخ'],
  'assets/data/hajw.json': ['حەج و عومرە', 'بابەتی حەج'],
};

/// Static info screens rendered from assets/data/generated_static.json
/// (original activities: Hwhe, Whw, Gss, Hwuw, Vsbs, ...).
const Map<String, String> kInfoScreens = {
  'hwhe': 'نوێژە فەڕزەکان',
  'whw': 'نوێژی جەژن',
  'gss': 'بانگدان',
  'hwuw': 'شرۆڤەی بانگ',
  'vsbs': 'تەیەمموم',
  'cheshtan': 'پێویستییەکانی نوێژ',
  'estyxara': 'ئیستخارە',
  'islam': 'بنەماکانی ئیسلام',
  'fate7a': 'سوورەتی فاتیحە',
  'error': 'هەڵەکانی نوێژ',
  'manaynwezh': 'مانای بانگ',
  'page123': 'نوێژی ویتڕ',
  'dasalatakan': 'دوعاکانی نوێژ',
  'seetine': 'سیەرەتی پێغەمبەر ﷺ',
  'brdnapesh': 'بڕدانەپەش',
  'bayani': 'بەیانی',
  'eywara': 'ئێوارە',
  'sleep': 'خەوتن',
  'swrat': 'سوورەتەکان',
  'seng': 'سەنگ',
  'question': 'پرسیار و وەڵام',
  'book': 'کتێب',
};
