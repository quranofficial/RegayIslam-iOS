import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/rtdb.dart';
import '../../data/favorites.dart';
import '../../main.dart' show toggleDayNight;
import '../articles/json_article_screen.dart';
import '../articles/info_screen.dart';
import '../misc/zikr_detail_screen.dart';
import '../media/live_screen.dart';
import '../media/videos_screen.dart';
import '../quran/ayat_screen.dart';
import '../quran/ayatul_kursi_screen.dart';
import '../quran/name_screen.dart';
import '../quran/qariakan_screen.dart';
import '../quran/quran_search_screen.dart';
import '../ramadan/ramazan_screen.dart';
import '../settings/question_screen.dart';
import '../tasbih/tasbih_counter.dart';
import '../qibla_screen.dart';
import '../books/kteb_screen.dart';
import '../nwezh/ruqya_screen.dart';
import '../nwezh/prayers_month.dart';
import '../nwezh/prayer_times_screen.dart';
import '../nwezh/dasalatakan_screen.dart';
import '../settings/tawanakanm_screen.dart';
import 'prayer/nwezh_hub.dart';

/// Original: HomeFragmentActivity — 186 widgets: banners, tasbih counter,
/// city prayer times and the feature grid. Labels are taken 1:1 from the
/// original home_fragment.xml.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, String>? _times;
  bool _timesError = false;
  Map<String, dynamic>? _ramadanDay;
  List<Map<String, dynamic>> _live = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await Db.I.prayerTimes(AppPrefs.I.cityId, DateTime.now());
      if (mounted) setState(() { _times = t; _timesError = t == null; });
    } catch (_) {
      if (mounted) setState(() => _timesError = true);
    }
    try {
      final r = await Rtdb.I.list('ramadan');
      if (r.isNotEmpty && mounted) setState(() => _ramadanDay = r.last);
    } catch (_) {}
    try {
      final l = await Rtdb.I.liveMuslim();
      if (mounted) setState(() => _live = l);
    } catch (_) {}
  }

  void _openJson(String file, String title) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => JsonArticleScreen(file: file, title: title)));
  }

  void _openInfo(String key, String title) {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => InfoScreen(screenKey: key, title: title)));
  }

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final card = dark ? AppColors.nightCard : Colors.white;
    final txt = dark ? Colors.white : Colors.black;
    return Scaffold(
      backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          _header(dark, txt),
          const SizedBox(height: 10),
          _ayatBanner(card, txt, dark),
          const SizedBox(height: 10),
          _banner(
              icon: Icons.wifi_tethering_rounded,
              title: 'پەخشی ڕاستەوخۆ',
              sub: _live.isEmpty ? 'Live' : '${_live.length} کەناڵ بەردەستە',
              color: const Color(0xFFD32F2F),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LiveScreen()))),
          const SizedBox(height: 10),
          _ramazanBanner(card, txt, dark),
          const SizedBox(height: 10),
          _fridayBanner(card, txt, dark),
          const SizedBox(height: 10),
          _tasbihCard(card, txt, dark),
          const SizedBox(height: 10),
          _prayerTimesCard(card, txt, dark),
          const SizedBox(height: 12),
          _grid(dark, card, txt),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _header(bool dark, Color txt) => Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/images/app_icon.png',
                width: 46, height: 46,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.mosque, size: 42))),
        const SizedBox(width: 10),
        Text('ڕێگای ئیسلام',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: txt)),
        const Spacer(),
        IconButton(
            onPressed: toggleDayNight,
            icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: txt)),
      ]);

  Widget _ayatBanner(Color card, Color txt, bool dark) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AyatScreen())),
        child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: dark ? AppColors.nightCard : const Color(0xFF004D7B),
                borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_stories_rounded,
                    color: dark ? AppColors.gold : Colors.white70, size: 18),
                const SizedBox(width: 6),
                Text('ئایەتی ڕۆژ',
                    style: TextStyle(
                        color: dark ? AppColors.gold : Colors.white70,
                        fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                Icon(Icons.chevron_left, color: Colors.white70, size: 18),
              ]),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                    'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Quran',
                        fontSize: 18, height: 1.8)),
              ),
            ])));

  Widget _banner({required IconData icon, required String title,
      required String sub, required Color color, required VoidCallback onTap}) =>
      InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(.7)]),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(sub, style: TextStyle(color: Colors.white.withOpacity(.8), fontSize: 12)),
                ]),
                const Spacer(),
                const Icon(Icons.chevron_left, color: Colors.white),
              ])));

  Widget _ramazanBanner(Color card, Color txt, bool dark) => InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RamazanScreen())),
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: dark ? AppColors.nightCard : const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.nights_stay_rounded, color: Colors.amber, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_ramadanDay?['title'] ?? 'ڕەمەزانتان پیرۆز',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              Text(_ramadanDay?['text'] ?? 'ڕۆژی ١ لە مانگی ڕەمەزانی پیرۆز',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(.85), fontSize: 12)),
            ])),
            const Icon(Icons.chevron_left, color: Colors.white70),
          ])));

  Widget _fridayBanner(Color card, Color txt, bool dark) => InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        AppPrefs.I.zikrName = 'ڕۆژی هەینی';
        AppPrefs.I.zikrBody =
            '١ - خۆشۆردن\n٢ - خۆبۆنخۆشکردن و سەرچاککردن\n٣ - زوو گەیشتن بە نوێژی هەینی\n٤ - خوێندنی سوورەتی کەهف\n٥ - زۆر سەڵاوات لەسەر پێغەمبەر ﷺ';
        AppPrefs.I.zikrVip = 'سونەتەکانی ڕۆژی هەینی';
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => const ZikrDetailScreen()));
      },
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: dark ? AppColors.nightCard : const Color(0xFF4A148C),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('شەوی هەینی یە با سەڵاوات لەبیرنەکەین لەسەر خۆشەویستمان ﷺ',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text('اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withOpacity(.85),
                        fontFamily: 'Quran', fontSize: 13)),
              ),
            ])),
            const Icon(Icons.chevron_left, color: Colors.white70),
          ])));

  Widget _tasbihCard(Color card, Color txt, bool dark) => InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const TasbihCounterScreen())),
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dark ? Colors.white10 : Colors.black12)),
          child: Row(children: [
            CircleAvatar(
                radius: 26,
                backgroundColor: dark ? AppColors.gold.withOpacity(.15) : AppColors.primaryDark.withOpacity(.08),
                child: Icon(Icons.fingerprint_rounded,
                    size: 32, color: dark ? AppColors.gold : AppColors.primaryDark)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تەسبیح', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: txt)),
              Text('ژماردنی زیکر و تەسبیحات', style: TextStyle(fontSize: 12, color: txt.withOpacity(.6))),
            ]),
            const Spacer(),
            const Icon(Icons.chevron_left),
          ])));

  Widget _prayerTimesCard(Color card, Color txt, bool dark) => InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const PrayerTimesScreen())),
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dark ? Colors.white10 : Colors.black12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.access_time_rounded, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text('کاتەکانی بانگ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: txt)),
              const Spacer(),
              Text(AppPrefs.I.cityName,
                  style: TextStyle(fontSize: 13, color: txt.withOpacity(.6))),
            ]),
            const SizedBox(height: 10),
            if (_timesError)
              Text('کێشەی بانگ نەدان !',
                  style: TextStyle(color: Colors.red, fontSize: 12))
            else if (_times == null)
              const Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _t('بەیانی', _times!['bayani'], txt, dark),
                _t('گزشتن', _times!['xorhalatn'], txt, dark),
                _t('نیوەڕۆ', _times!['niwaro'], txt, dark),
                _t('عەسر', _times!['asr'], txt, dark),
                _t('ئێوارە', _times!['eywara'], txt, dark),
                _t('خەوتنان', _times!['esha'], txt, dark),
              ]),
          ])));

  Widget _t(String label, String? v, Color txt, bool dark) => Column(children: [
        Text(label, style: TextStyle(fontSize: 11, color: txt.withOpacity(.6))),
        const SizedBox(height: 2),
        Text(v ?? '00:00',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: dark ? AppColors.gold : AppColors.primaryDark)),
      ]);

  Widget _grid(bool dark, Color card, Color txt) {
    final items = <_G>[
      _G('دڵخوازەکان', Icons.bookmarks_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()))),
      _G('نوێژکردن', Icons.mosque_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NwezhHubScreen()))),
      _G('ناوەکانی خودای گەورە', Icons.badge_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NameScreen()))),
      _G('ئایەتی کورسی', Icons.menu_book_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AyatulKursiScreen()))),
      _G('پرسیار و وەڵام', Icons.quiz_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuestionScreen()))),
      _G('ڤیدیۆی ئاینی', Icons.ondemand_video_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideosScreen()))),
      _G('تاوانەکانم', Icons.warning_amber_rounded,
          () => _openJson('assets/data/tawanakan.json', 'تاوانەگەورەکان')),
      _G('کتێبخانە', Icons.local_library_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KtebScreen()))),
      _G('ڕوقیەی شەرعی', Icons.healing_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RuqyaScreen()))),
      _G('زیکرەکان', Icons.self_improvement_rounded,
          () => _openJson('assets/data/zikrakan.json', 'زیکرەکان')),
      _G('فەرموودەکان', Icons.format_quote_rounded,
          () => _openJson('assets/data/farmwda.json', 'فەرموودەکان')),
      _G('مانگی ڕەمەزان', Icons.dark_mode_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RamazanScreen()))),
      _G('ئافرەتان', Icons.face_3_rounded,
          () => _openJson('assets/data/girlss.json', 'ئافرەتان')),
      _G('دوعا و پاڕانەوە', Icons.volunteer_activism_rounded,
          () => _openJson('assets/data/duha.json', 'دوعا و پاڕانەوە')),
      _G('چۆن تۆبە بکەم', Icons.change_circle_rounded,
          () => _openJson('assets/data/taybat.json', 'چۆن تۆبە بکەم')),
      _G('حەج و عومرە', Icons.flight_land_rounded,
          () => _openJson('assets/data/hajw.json', 'حەج و عومرە')),
      _G('ئەهلی ئاگر', Icons.local_fire_department_rounded,
          () => _openJson('assets/data/agr.json', 'ئەهلی ئاگر')),
      _G('بەهەشت', Icons.park_rounded,
          () => _openJson('assets/data/bahasht.json', 'بەهەشت')),
      _G('دۆزەخ', Icons.whatshot_rounded,
          () => _openJson('assets/data/dozax.json', 'دۆزەخ')),
      _G('خەونامە', Icons.bedtime_rounded,
          () => _openJson('assets/data/xawn.json', 'خەونامە')),
      _G('ژیانی پێغەمبەرمان ﷺ', Icons.person_rounded,
          () => _openJson('assets/data/pexambarman.json', 'ژیانی پێغەمبەرمان ﷺ')),
      _G('ژیانی پێغەمبەران', Icons.groups_rounded,
          () => _openJson('assets/data/pexambaran.json', 'ژیانی پێغەمبەران')),
      _G('هاوەڵانی پێغەمبەر ﷺ', Icons.people_rounded,
          () => _openJson('assets/data/hawal.json', 'هاوەڵانی پێغەمبەر ﷺ')),
      _G('سونەت', Icons.star_rounded,
          () => _openJson('assets/data/swnat.json', 'سونەت')),
      _G('زانیاری قورئان', Icons.info_rounded,
          () => _openJson('assets/data/zanyaryquran.json', 'زانیاری قورئان')),
      _G('تاوانەگەورەکان', Icons.gavel_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TawanakanmScreen()))),
      _G('ڕاو بۆچونەکان', Icons.forum_rounded,
          () => _openJson('assets/data/rawbochwn.json', 'ڕاو بۆچونەکان')),
      _G('وتە و ئامۆژگاری', Icons.record_voice_over_rounded,
          () => _openJson('assets/data/wta.json', 'وتە و ئامۆژگاری')),
      _G('حەڕام کراوەکان', Icons.block_rounded,
          () => _openJson('assets/data/haram.json', 'حەڕام کراوەکان')),
      _G('زیانەکانی گۆرانی', Icons.music_off_rounded,
          () => _openJson('assets/data/zianakanygorani.json', 'زیانەکانی گۆرانی')),
      _G('تاوانی غەیبەت', Icons.volume_off_rounded,
          () => _openJson('assets/data/xaybat.json', 'تاوانی غەیبەت')),
      _G('چیرۆکی دەجال', Icons.crisis_alert_rounded,
          () => _openJson('assets/data/dajal.json', 'چیرۆکی دەجال')),
      _G('قیبلەنما', Icons.explore_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QiblaScreen()))),
      _G('دەنگی قورئان', Icons.graphic_eq_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QariakanScreen()))),
      _G('گەڕان لە قورئان', Icons.search_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranSearchScreen()))),
      _G('دوعاکانی نوێژ', Icons.waving_hand_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DasalatakanScreen()))),
      _G('کاتەکانی مانگ', Icons.calendar_month_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrayersMonthScreen()))),
    ];
    return GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: .82,
        children: [
          for (final g in items)
            InkWell(
                onTap: g.onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: dark ? Colors.white10 : Colors.black12)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(g.icon, size: 30,
                          color: dark ? AppColors.gold : AppColors.primaryDark),
                      const SizedBox(height: 8),
                      Text(g.label,
                          textAlign: TextAlign.center, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, height: 1.3, color: txt)),
                    ]))),
        ]);
  }
}

class _G {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _G(this.label, this.icon, this.onTap);
}
