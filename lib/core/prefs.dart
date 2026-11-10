import 'dart:convert';
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

  String get tafsir {
    // Normalise the legacy spellings ("masier"/"zhian" never existed as DB
    // columns) so an old install can never break the Quran reader again.
    final raw = _p.getString('tafsir') ?? 'rebar';
    return kTafsirLegacy[raw] ?? raw;
  }
  set tafsir(String v) => _p.setString('tafsir', kTafsirLegacy[v] ?? v);

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

  // --- startup announcement dialog: stamp of the last shown dialogg/ver ---
  String get dialogSeen => _p.getString('dialogg_seen') ?? '';
  set dialogSeen(String v) => _p.setString('dialogg_seen', v);

  // --- home section order (item 8: جوڵاندنی بەشەکان سەرەوە/خوارەوە) ---
  List<String> get homeOrder => _p.getStringList('homeOrder') ?? <String>[];
  set homeOrder(List<String> v) => _p.setStringList('homeOrder', v);

  // --- daily-ayah banner: index of the currently shown random ayah ---
  int get ayahBannerSeed => _p.getInt('ayahBannerSeed') ?? -1;
  set ayahBannerSeed(int v) => _p.setInt('ayahBannerSeed', v);

  // Persist the surah as well as the ayah index so the home card and widget
  // always refer to the same daily ayah after a rebuild or restart.
  int get ayahBannerSura => _p.getInt('ayahBannerSura') ?? 0;
  set ayahBannerSura(int v) => _p.setInt('ayahBannerSura', v);

  // --- library books json (MainActivity pref "onlybookme": the fetched
  //     ktebakan.json, kept offline) ---
  String get libraryJson => _p.getString('onlybookme') ?? '';
  set libraryJson(String v) => _p.setString('onlybookme', v);

  // --- downloaded PDF cache (PdfScreen key style "pdf_cache_<url>") ---
  String? pdfCachePath(String url) => _p.getString('pdf_cache_$url');
  void setPdfCachePath(String url, String path) =>
      _p.setString('pdf_cache_$url', path);

  // --- item 8: renamed home sections (default label -> custom name) ---
  String get homeNamesJson => _p.getString('homeNames') ?? '';
  set homeNamesJson(String v) => _p.setString('homeNames', v);
  Map<String, String> get homeNames {
    try {
      return (jsonDecode(homeNamesJson) as Map)
          .map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return <String, String>{};
    }
  }

  void setHomeName(String key, String? value) {
    final m = homeNames;
    if (value == null || value.trim().isEmpty || value.trim() == key) {
      m.remove(key);
    } else {
      m[key] = value.trim();
    }
    homeNamesJson = jsonEncode(m);
  }

  // --- item 17: per-device liked videos (survive restarts) ---
  List<String> get likedVideos => _p.getStringList('likedVideos') ?? <String>[];
  bool isVideoLiked(String id) => likedVideos.contains(id);
  void setVideoLiked(String id, bool v) {
    final l = likedVideos;
    if (v && !l.contains(id)) l.add(id);
    if (!v) l.remove(id);
    _p.setStringList('likedVideos', l);
  }

  // --- item 22: stamp of the last admin notification shown ---
  String get notifSeen => _p.getString('notifSeen') ?? '';
  set notifSeen(String v) => _p.setString('notifSeen', v);

  // --- item 6: daily-ayah font size (only the ayah text) ---
  int get ayahFontSize => _p.getInt('ayahSize') ?? 24;
  set ayahFontSize(int v) => _p.setInt('ayahSize', v);

  // --- item 6: stamp of the day the widget ayah was last pushed ---
  String get widgetAyahDay => _p.getString('widgetAyahDay') ?? '';
  set widgetAyahDay(String v) => _p.setString('widgetAyahDay', v);

  // --- smart daily ayah: the banner changes once per calendar day ---
  String get ayahDay => _p.getString('ayahDay') ?? '';
  set ayahDay(String v) => _p.setString('ayahDay', v);

  // --- Quran reader custom colors (studio editor). 0 = follow theme ---
  int get quranTextColor => _p.getInt('quranTextColor') ?? 0;
  set quranTextColor(int v) => _p.setInt('quranTextColor', v);
  int get quranBgColor => _p.getInt('quranBgColor') ?? 0;
  set quranBgColor(int v) => _p.setInt('quranBgColor', v);

  // --- admin panel: saved GitHub token so it is entered only once ---
  String get adminGhToken => _p.getString('admin_gh_token') ?? '';
  set adminGhToken(String v) => _p.setString('admin_gh_token', v);

  // --- item 13: the Quran Studio (image/video creator) remembers the
  //     last design so reopening the section shows the same look ---
  int get studioFontIndex => _p.getInt('studioFontIndex') ?? 0;
  set studioFontIndex(int v) => _p.setInt('studioFontIndex', v);
  double get studioTextSize => _p.getDouble('studioTextSize') ?? 46;
  set studioTextSize(double v) => _p.setDouble('studioTextSize', v);
  int get studioTextColor => _p.getInt('studioTextColor') ?? 0xFFFFFFFF;
  set studioTextColor(int v) => _p.setInt('studioTextColor', v);
  int get studioBgColor => _p.getInt('studioBgColor') ?? 0xFF0D2137;
  set studioBgColor(int v) => _p.setInt('studioBgColor', v);
  int get studioAnimation => _p.getInt('studioAnimation') ?? 0;
  set studioAnimation(int v) => _p.setInt('studioAnimation', v);

  // --- books: last read page per book url (reading history) ---
  int bookLastPage(String url) => _p.getInt('bookpage_$url') ?? 0;
  void setBookLastPage(String url, int page) {
    if (page > 0) _p.setInt('bookpage_$url', page);
  }

  // --- item 7: page HISTORY per book (last visited pages, so the reader
  //     can jump back several pages with one tap, not only the last one) ---
  List<int> bookPageHistory(String url) {
    final raw = _p.getStringList('bookhist_$url') ?? <String>[];
    return raw.map(int.tryParse).whereType<int>().toList();
  }

  void addBookPageHistory(String url, int page) {
    if (page < 0) return;
    final list = bookPageHistory(url);
    list.remove(page);
    list.insert(0, page);
    _p.setStringList('bookhist_$url',
        list.take(24).map((e) => '$e').toList());
  }

  void clearBookPageHistory(String url) =>
      _p.remove('bookhist_$url');

  // --- last mushaf page the user was reading ---
  int get mushafLastPage => _p.getInt('mushafLastPage') ?? 0;
  set mushafLastPage(int v) => _p.setInt('mushafLastPage', v);

  // --- item 3: last read position in the Quran reader (continue reading) ---
  int get lastReadSurah => _p.getInt('lastReadSurah') ?? 0;
  set lastReadSurah(int v) => _p.setInt('lastReadSurah', v);
  int get lastReadAyah => _p.getInt('lastReadAyah') ?? 0;
  set lastReadAyah(int v) => _p.setInt('lastReadAyah', v);
  String get lastReadWhen => _p.getString('lastReadWhen') ?? '';
  set lastReadWhen(String v) => _p.setString('lastReadWhen', v);
  void saveReadingPosition(int surahId, int ayah) {
    if (surahId <= 0 || ayah <= 0) return;
    _p.setInt('lastReadSurah', surahId);
    _p.setInt('lastReadAyah', ayah);
    final n = DateTime.now();
    _p.setString('lastReadWhen',
        '${n.year}/${n.month}/${n.day}');
  }

  // --- item 21: browse mode of the Quran tab (0 = سوورەت, 1 = لاپەڕە) ---
  int get quranBrowseMode => _p.getInt('quranBrowseMode') ?? 0;
  set quranBrowseMode(int v) => _p.setInt('quranBrowseMode', v);

  // --- item 10: remembered video playback speed (0.25 .. 2.0) ---
  double get videoSpeed => _p.getDouble('videoSpeed') ?? 1.0;
  set videoSpeed(double v) => _p.setDouble('videoSpeed', v);

  // --- item 4: continue to the next surah automatically (دەنگی قورئان) ---
  bool get autoNextSurah => _p.getBool('autoNextSurah') ?? true;
  set autoNextSurah(bool v) => _p.setBool('autoNextSurah', v);

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
        // Item 14: night mode everywhere — dialogs, sheets, snackbars,
        // app bars and dividers included.
        appBarTheme: AppBarTheme(
            backgroundColor:
                day ? AppColors.primaryDark : AppColors.nightCard,
            foregroundColor: Colors.white,
            elevation: 0),
        dialogBackgroundColor: day ? Colors.white : AppColors.nightCard,
        dialogTheme: DialogThemeData(
            backgroundColor: day ? Colors.white : AppColors.nightCard,
            titleTextStyle: TextStyle(
                color: day ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold, fontSize: 17),
            contentTextStyle: TextStyle(
                color: day ? Colors.black87 : Colors.white70,
                fontSize: 14, height: 1.6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: day ? Colors.white : AppColors.nightCard,
            modalBackgroundColor: day ? Colors.white : AppColors.nightCard),
        snackBarTheme: SnackBarThemeData(
            backgroundColor: day ? AppColors.primaryDark : AppColors.gold,
            contentTextStyle: TextStyle(color: Colors.white, fontSize: 13),
            behavior: SnackBarBehavior.floating),
        dividerColor: day ? Colors.black12 : Colors.white10,
        switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? (day ? AppColors.primaryDark : AppColors.gold)
                    : null),
            trackColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? (day
                        ? AppColors.primaryDark.withOpacity(.4)
                        : AppColors.gold.withOpacity(.4))
                    : (day ? Colors.black26 : Colors.white24))),
      );
}
