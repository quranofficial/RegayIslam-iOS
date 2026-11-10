import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/prefs.dart';
import '../../../main.dart' show toggleDayNight, kThemeEpoch;
import '../../../core/ui.dart' show bottomInset, sharePage;
import '../../articles/info_screen.dart';
import '../../misc/zikr_detail_screen.dart';
import '../../nwezh/prayers_month.dart';
import '../../nwezh/nwezhi_settings.dart';
import '../../nwezh/dasalatakan_screen.dart';
import '../../settings/question_screen.dart';

/// Original: NwezhActivity — the prayer hub; every card opens one of the
/// original prayer-education activities (Fate7a, Dastnwezh, Error, Islam,
/// Vsbs, Page123, Gss, Hwhe, Hwuw, Whw, Cheshtan, Estyxara, Manaynwezh,
/// Nwezhi, Krdnawa...) through InfoScreen or a dedicated screen.
///
/// Items 5 + 11: a search field filters the cards, and (item 12) the hub
/// repaints immediately when dark mode toggles from its own app bar —
/// no restart anywhere.
class NwezhHubScreen extends StatefulWidget {
  const NwezhHubScreen({super.key});
  @override
  State<NwezhHubScreen> createState() => _NwezhHubScreenState();
}

class _NwezhHubScreenState extends State<NwezhHubScreen> {
  final TextEditingController _search = TextEditingController();
  String _q = '';

  void _info(BuildContext c, String key, String title) {
    Navigator.push(c,
        MaterialPageRoute(builder: (_) => InfoScreen(screenKey: key, title: title)));
  }

  void _zikr(BuildContext c) {
    AppPrefs.I.zikrName = 'ئەو زیکرانەی لەدوای نوێژ دەگوترێن';
    AppPrefs.I.zikrBody =
        'أَسْتَغْفِرُ اللهَ (٣ جار)\n\nاللَّهُمَّ أَنْتَ السَّلاَمُ وَمِنْكَ السَّلاَمُ تَبَارَكْتَ يَا ذَا الْجَلاَلِ وَالإِكْرَامِ';
    AppPrefs.I.zikrVip = 'زیکرەکان';
    Navigator.push(c,
        MaterialPageRoute(builder: (_) => const ZikrDetailScreen()));
  }

  List<_P> _items(BuildContext context) => [
    _P('سوورەتی فاتیحە', 'بەڵگە و فەزڵەکانی', Icons.menu_book_rounded,
        () => _info(context, 'fate7a', 'سوورەتی فاتیحە')),
    _P('دەست نوێژ', 'چۆن دەستنوێژ بکرێت', Icons.clean_hands_rounded,
        () => _info(context, 'dastnwezh', 'دەست نوێژ')),
    _P('هەڵەکانی نوێژ', 'ئەوانەی نوێژ دەشکێنن', Icons.error_outline_rounded,
        () => _info(context, 'error', 'هەڵەکانی نوێژ')),
    _P('ئیسلام و باوەر', 'شەش بنەما', Icons.foundation_rounded,
        () => _info(context, 'islam', 'ئیسلام و باوەر')),
    _P('تەیەمموم', 'کات و شێوازی', Icons.water_drop_rounded,
        () => _info(context, 'vsbs', 'تەیەمموم')),
    _P('چونە سەرئاو', 'ویردی دەستنوێژ', Icons.shower_rounded,
        () => _info(context, 'page123', 'چونە سەرئاو')),
    _P('بانگدان', 'دەقی بانگ و مانای', Icons.campaign_rounded,
        () => _info(context, 'gss', 'بانگدان')),
    _P('مانای نوێژ', 'وەرگێڕانی نوێژ', Icons.translate_rounded,
        () => _info(context, 'manaynwezh', 'مانای نوێژ')),
    _P('بەتاڵکردنەوەی نوێژ', 'ئەوانەی نوێژ و دەستنوێژ ئەشکێنن', Icons.disabled_by_default_rounded,
        () => _info(context, 'nwezhi', 'بەتاڵکردنەوەی نوێژ')),
    _P('نوێژە فەڕزەکان', '١٧ ڕکاعەت', Icons.mosque_rounded,
        () => _info(context, 'hwhe', 'نوێژە فەڕزەکان')),
    _P('شەونوێژ', 'نوێژی شەو', Icons.dark_mode_rounded,
        () => _info(context, 'hwuw', 'شەونوێژ')),
    _P('نوێژی ئیستیخارە', 'چۆن بکرێت', Icons.help_center_rounded,
        () => _info(context, 'estyxara', 'نوێژی ئیستیخارە')),
    _P('نوێژی چێشتەنگاو', 'چۆن ئەنجام بدرێت', Icons.soup_kitchen_rounded,
        () => _info(context, 'cheshtan', 'نوێژی چێشتەنگاو')),
    _P('نوێژی جەژن', 'چۆن ئەنجام بدرێت', Icons.celebration_rounded,
        () => _info(context, 'whw', 'نوێژی جەژن')),
    _P('زیکرەکان', 'ئەو زیکرانەی دوای نوێژ', Icons.self_improvement_rounded,
        () => _zikr(context)),
    _P('دوعاکانی نوێژ', 'لە ڕکاعەتەکاندا', Icons.waving_hand_rounded,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DasalatakanScreen()))),
    _P('کاتەکانی مانگ', 'خشتەی مانگانە', Icons.calendar_month_rounded,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PrayersMonthScreen()))),
    _P('ڕێکخستنی بانگ', 'ئاگادارکردنەوەکان', Icons.notifications_active_rounded,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NwezhiSettingsScreen()))),
    _P('پرسیار و وەڵام', 'لەبارەی نوێژ', Icons.quiz_rounded,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const QuestionScreen()))),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Item 12: listen to the theme epoch so the hub recolors in place when
    // the moon/sun button in its own app bar is tapped.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ValueListenableBuilder<int>(
        valueListenable: kThemeEpoch,
        builder: (context, __, ___) {
          final dark = !AppPrefs.I.day;
          final txt = dark ? Colors.white : Colors.black;
          final card = dark ? AppColors.nightCard : Colors.white;
          final accent = dark ? AppColors.gold : AppColors.primaryDark;
          final all = _items(context);
          final q = _q.trim().toLowerCase();
          final shown = q.isEmpty
              ? all
              : all
                  .where((p) =>
                      p.title.toLowerCase().contains(q) ||
                      p.sub.toLowerCase().contains(q))
                  .toList();
          return Scaffold(
            backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
            appBar: AppBar(
              backgroundColor:
                  dark ? AppColors.nightCard : AppColors.primaryDark,
              title: const Text('نوێژکردن',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                    tooltip: 'هاوبەشی',
                    onPressed: () => sharePage(
                        'نوێژکردن — شێواز، مەحڕەمەکان و دوعاکانی نوێژ',
                        title: 'نوێژکردن'),
                    icon: const Icon(Icons.share_rounded, color: Colors.white)),
                IconButton(
                    onPressed: toggleDayNight,
                    icon: Icon(
                        dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: Colors.white)),
              ],
            ),
            body: Column(children: [
              // Items 5 + 11: search inside the section itself.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'گەڕان لە بەشەکانی نوێژ...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: card,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text('هیچ بەشێک نەدۆزرایەوە',
                            style: TextStyle(color: txt.withOpacity(.5))))
                    : GridView.count(
                        padding: EdgeInsets.fromLTRB(12, 8, 12,
                            bottomInset(context, extra: 14)),
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.35,
                        children: [
                          for (final p in shown)
                            InkWell(
                              onTap: p.onTap,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: card,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: dark
                                            ? Colors.white10
                                            : Colors.black12)),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                  Icon(p.icon, size: 28, color: accent),
                                  const Spacer(),
                                  Text(p.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: txt)),
                                  Text(p.sub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: txt.withOpacity(.55))),
                                ]),
                              ),
                            ),
                        ],
                      ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _P {
  final String title, sub;
  final IconData icon;
  final VoidCallback onTap;
  _P(this.title, this.sub, this.icon, this.onTap);
}
