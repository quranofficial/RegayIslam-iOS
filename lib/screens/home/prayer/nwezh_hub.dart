import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/prefs.dart';
import '../../../main.dart' show toggleDayNight;
import '../../articles/info_screen.dart';
import '../../misc/zikr_detail_screen.dart';
import '../../nwezh/prayers_month.dart';
import '../../nwezh/nwezhi_settings.dart';
import '../../nwezh/dastnwezh_screen.dart';
import '../../nwezh/dasalatakan_screen.dart';
import '../../settings/question_screen.dart';

/// Original: NwezhActivity — the prayer hub; every card opens one of the
/// original prayer-education activities (Fate7a, Dastnwezh, Error, Islam,
/// Vsbs, Page123, Gss, Hwhe, Hwuw, Whw, Cheshtan, Estyxara, Manaynwezh,
/// Nwezhi, Krdnawa...).
class NwezhHubScreen extends StatelessWidget {
  const NwezhHubScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    final card = dark ? AppColors.nightCard : Colors.white;
    final items = <_P>[
      _P('سوورەتی فاتیحە', 'بەڵگە و فەزڵەکانی', Icons.menu_book_rounded,
          () => _info(context, 'fate7a', 'سوورەتی فاتیحە')),
      _P('نوێژە فەڕزەکان', '١٧ ڕکاعەت', Icons.mosque_rounded,
          () => _info(context, 'hwhe', 'نوێژە فەڕزەکان')),
      _P('نوێژی جەژن', 'چۆن ئەنجام بدرێت', Icons.celebration_rounded,
          () => _info(context, 'whw', 'نوێژی جەژن')),
      _P('بانگدان', 'دەقی بانگ و مانای', Icons.campaign_rounded,
          () => _info(context, 'gss', 'بانگدان')),
      _P('شرۆڤەی بانگ', 'واتەی هەر جملەیەک', Icons.record_voice_over_rounded,
          () => _info(context, 'hwuw', 'شرۆڤەی بانگ')),
      _P('تەیەمموم', 'کات و شێوازی', Icons.water_drop_rounded,
          () => _info(context, 'vsbs', 'تەیەمموم')),
      _P('پێویستییەکانی نوێژ', 'شەرتی دروستی', Icons.checklist_rounded,
          () => _info(context, 'cheshtan', 'پێویستییەکانی نوێژ')),
      _P('ئیستخارە', 'چۆن بکرێت', Icons.help_center_rounded,
          () => _info(context, 'estyxara', 'ئیستخارە')),
      _P('نوێژی ویتڕ', 'ڕکاعەتەکانی', Icons.auto_awesome_rounded,
          () => _info(context, 'page123', 'نوێژی ویتڕ')),
      _P('دوعاکانی نوێژ', 'لە ڕکاعەتەکاندا', Icons.waving_hand_rounded,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DasalatakanScreen()))),
      _P('کاتەکانی مانگ', 'خشتەی مانگانە', Icons.calendar_month_rounded,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PrayersMonthScreen()))),
      _P('دەستنوێژ (دەستکاری)', 'کاتی خۆت دیاری بکە', Icons.edit_calendar_rounded,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DastnwezhScreen()))),
      _P('هەڵەکانی نوێژ', 'ئەوانەی نوێژ دەشکێنن', Icons.error_outline_rounded,
          () => _info(context, 'error', 'هەڵەکانی نوێژ')),
      _P('بنەماکانی ئیسلام', 'شەش بنەما', Icons.foundation_rounded,
          () => _info(context, 'islam', 'بنەماکانی ئیسلام')),
      _P('مانای بانگ', 'وەرگێڕانی بانگ', Icons.translate_rounded,
          () => _info(context, 'manaynwezh', 'مانای بانگ')),
      _P('ڕێکخستنی بانگ', 'ئاگادارکردنەوەکان', Icons.notifications_active_rounded,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NwezhiSettingsScreen()))),
      _P('زیکری دوای نوێژ', 'ئەو زیکرانەی دوای نوێژ', Icons.self_improvement_rounded,
          () => _zikr(context)),
      _P('پرسیار و وەڵام', 'لەبارەی نوێژ', Icons.quiz_rounded,
          () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const QuestionScreen()))),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('نوێژکردن',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                onPressed: toggleDayNight,
                icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: Colors.white)),
          ],
        ),
        body: GridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            for (final p in items)
              InkWell(
                onTap: p.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: dark ? Colors.white10 : Colors.black12)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(p.icon, size: 30,
                        color: dark ? AppColors.gold : AppColors.primaryDark),
                    const Spacer(),
                    Text(p.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
                    Text(p.sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: txt.withOpacity(.55))),
                  ]),
                ),
              ),
          ],
        ),
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
