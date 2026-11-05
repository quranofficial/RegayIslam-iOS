import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

/// Port of the original "color" SharedPreferences file used by the Sketchware
/// project. All keys keep their original names.
class AppPrefs {
  AppPrefs._();
  static final AppPrefs I = AppPrefs._();

  late SharedPreferences _p;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  bool get day => _p.getBool('day') ?? true; // true = light mode
  set day(bool v) => _p.setBool('day', v);

  /// Use Kurdish/Arabic-Indic numerals throughout the interface.
  bool get useKurdishDigits => _p.getBool('kurdishDigits') ?? true;
  set useKurdishDigits(bool v) => _p.setBool('kurdishDigits', v);

  bool get showQuranTafsir => _p.getBool('showQuranTafsir') ?? true;
  set showQuranTafsir(bool v) => _p.setBool('showQuranTafsir', v);
  bool get showQuranAyahNumbers => _p.getBool('showQuranAyahNumbers') ?? true;
  set showQuranAyahNumbers(bool v) => _p.setBool('showQuranAyahNumbers', v);
  bool get showQuranSurahName => _p.getBool('showQuranSurahName') ?? true;
  set showQuranSurahName(bool v) => _p.setBool('showQuranSurahName', v);

  int get fontSize => _p.getInt('SIZE') ?? 20; // global font size
  set fontSize(int v) => _p.setInt('SIZE', v);

  int get quranFontSize => _p.getInt('quranSize') ?? 26;
  set quranFontSize(int v) => _p.setInt('quranSize', v);

  String get fontUi => _p.getString('fontui') ?? 'Rabar';
  set fontUi(String v) => _p.setString('fontui', v);

  String get fontQuran => _p.getString('fontquran') ?? 'Quran';
  set fontQuran(String v) => _p.setString('fontquran', v);

  String get tafsir => _p.getString('tafsir') ?? 'rebar';
  set tafsir(String v) => _p.setString('tafsir', v);

  String get cityId => _p.getString('city') ?? 'Hawler';
  set cityId(String v) => _p.setString('city', v);

  String get cityName => _p.getString('cityname') ?? 'هەولێر';
  set cityName(String v) => _p.setString('cityname', v);

  /// Mushaf page mode ("shewamm" in the original).
  bool get mushafMode => _p.getBool('shewamm') ?? false;
  set mushafMode(bool v) => _p.setBool('shewamm', v);

  bool get screenFull => _p.getBool('screenful') ?? false;
  set screenFull(bool v) => _p.setBool('screenful', v);

  bool get dialoging => _p.getBool('dialoging') ?? false;
  set dialoging(bool v) => _p.setBool('dialoging', v);

  // --- prayer notification switches (NwezhiActivity) ---
  bool get notifFajr => _p.getBool('nfajr') ?? true;
  set notifFajr(bool v) => _p.setBool('nfajr', v);
  bool get notifDhuhr => _p.getBool('ndhuhr') ?? true;
  set notifDhuhr(bool v) => _p.setBool('ndhuhr', v);
  bool get notifAsr => _p.getBool('nasr') ?? true;
  set notifAsr(bool v) => _p.setBool('nasr', v);
  bool get notifMaghrib => _p.getBool('nmaghrib') ?? true;
  set notifMaghrib(bool v) => _p.setBool('nmaghrib', v);
  bool get notifIsha => _p.getBool('nisha') ?? true;
  set notifIsha(bool v) => _p.setBool('nisha', v);

  bool get adhanSoundEnabled => _p.getBool('adhanSoundEnabled') ?? true;
  set adhanSoundEnabled(bool v) => _p.setBool('adhanSoundEnabled', v);
  bool get adhanVibrationEnabled => _p.getBool('adhanVibrationEnabled') ?? true;
  set adhanVibrationEnabled(bool v) => _p.setBool('adhanVibrationEnabled', v);

  // --- quran reciter (QariakanActivity saves pref "url"; SplashActivity
  //     defaults it to سعد الغامدي) ---
  String get qariId => _p.getString('qariId') ?? '11';
  set qariId(String v) => _p.setString('qariId', v);
  String get qariName => _p.getString('qariName') ?? 'سعد الغامدي';
  set qariName(String v) => _p.setString('qariName', v);
  String get qariUrl =>
      _p.getString('qariUrl') ??
      'https://github.com/Hiwaselah/audio003/releases/download/Sa3d_ghamdi/';
  set qariUrl(String v) => _p.setString('qariUrl', v);

  // --- adhan reciter voice (KtebActivity: prefs "bang.name"/"bang.bang",
  //     default اسلام صبحي(کورت) = file 012 from dangebangbezh.json) ---
  String get adhanVoiceName =>
      _p.getString('adhanVoiceName') ?? 'اسلام صبحي (کورت)';
  set adhanVoiceName(String v) => _p.setString('adhanVoiceName', v);
  String get adhanVoiceFile => _p.getString('adhanVoiceFile') ?? '012';
  set adhanVoiceFile(String v) => _p.setString('adhanVoiceFile', v);
  String adhanVoiceUrl([String? file]) {
    final f = (file ?? adhanVoiceFile).replaceAll('.mp3', '');
    return 'https://github.com/quranofficial/DangeBangBezh/raw/main/$f.mp3';
  }

  // --- adhan time offsets in minutes, -60..+60 (BrdnapeshActivity:
  //     دواخستن و پێشخستنی کاتی بانگدان) ---
  int get offsetBayani => _p.getInt('off_bayani') ?? 0;
  set offsetBayani(int v) => _p.setInt('off_bayani', v);
  int get offsetNiwaro => _p.getInt('off_niwaro') ?? 0;
  set offsetNiwaro(int v) => _p.setInt('off_niwaro', v);
  int get offsetAsr => _p.getInt('off_asr') ?? 0;
  set offsetAsr(int v) => _p.setInt('off_asr', v);
  int get offsetEywara => _p.getInt('off_eywara') ?? 0;
  set offsetEywara(int v) => _p.setInt('off_eywara', v);
  int get offsetIsha => _p.getInt('off_esha') ?? 0;
  set offsetIsha(int v) => _p.setInt('off_esha', v);

  int adhanOffset(String prayerKey) => switch (prayerKey) {
        'bayani' => offsetBayani,
        'niwaro' => offsetNiwaro,
        'asr' => offsetAsr,
        'eywara' => offsetEywara,
        'esha' => offsetIsha,
        _ => 0,
      };

  // --- tasbih counters (TasbihFragmentActivity) ---
  List<String> get tasbihList => _p.getStringList('tasbihlist') ??
      <String>['سوبحان الله|33', 'الحمد لله|33', 'الله أكبر|34'];
  set tasbihList(List<String> v) => _p.setStringList('tasbihlist', v);

  // --- current generic-article context (set by Home cards, read by Hack1) ---
  String get articleFile => _p.getString('json') ?? 'zikrakan.json';
  set articleFile(String v) => _p.setString('json', v);
  String get articleTitle => _p.getString('nametitle') ?? 'زیکرەکان';
  set articleTitle(String v) => _p.setString('nametitle', v);

  // --- zikr detail (KrdnawaActivity: name / zkr / vip) ---
  String get zikrName => _p.getString('name') ?? '';
  set zikrName(String v) => _p.setString('name', v);
  String get zikrBody => _p.getString('zkr') ?? '';
  set zikrBody(String v) => _p.setString('zkr', v);
  String get zikrVip => _p.getString('vip') ?? '';
  set zikrVip(String v) => _p.setString('vip', v);

  // --- video comments profile name (ListvideokanActivity pref "nameprofile") ---
  String get commentName => _p.getString('nameprofile') ?? '';
  set commentName(String v) => _p.setString('nameprofile', v);

  // --- library books json (MainActivity pref "onlybookme": the fetched
  //     ktebakan.json, kept offline) ---
  String get libraryJson => _p.getString('onlybookme') ?? '';
  set libraryJson(String v) => _p.setString('onlybookme', v);

  // --- downloaded PDF cache (PdfScreen key style "pdf_cache_<url>") ---
  String? pdfCachePath(String url) => _p.getString('pdf_cache_$url');
  void setPdfCachePath(String url, String path) =>
      _p.setString('pdf_cache_$url', path);

  ThemeData get theme => ThemeData(
        brightness: day ? Brightness.light : Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: day ? AppColors.primaryDark : AppColors.gold,
          brightness: day ? Brightness.light : Brightness.dark,
        ),
        scaffoldBackgroundColor: day ? AppColors.dayBg : AppColors.nightBg,
        cardColor: day ? Colors.white : AppColors.nightCard,
        fontFamily: fontUi,
        useMaterial3: true,
      );
}
