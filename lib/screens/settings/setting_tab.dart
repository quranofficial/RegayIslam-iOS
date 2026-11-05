import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../main.dart' show toggleDayNight;
import '../quran/quran_settings_sheet.dart';
import '../nwezh/nwezhi_settings.dart';
import '../feedback/feedback_screen.dart';
import '../band/band_screen.dart';
import '../misc/webview_screen.dart';
import 'adhan_offset_screen.dart';
import '../home/home_reorder_screen.dart';
import 'adhan_voice_screen.dart';

/// Original: SettingFragmentActivity — app settings incl. night mode,
/// fonts, prayer notifications, socials and about.
class SettingTab extends StatefulWidget {
  const SettingTab({super.key});
  @override
  State<SettingTab> createState() => _SettingTabState();
}

class _SettingTabState extends State<SettingTab> {

  void _openUrl(BuildContext c, String url) {
    final fixed = url.startsWith('http') ? url : 'https://$url';
    launchUrl(Uri.parse(fixed), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPrefs.I;
    final dark = !p.day;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('ڕێکخستن',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          _section('دۆخی ڕەنگ', dark, txt),
          Card(color: dark ? AppColors.nightCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                SwitchListTile(
                    secondary: Icon(dark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                        color: AppColors.primaryDark),
                    title: Text('دۆخی شەو', style: TextStyle(color: txt)),
                    value: dark,
                    onChanged: (_) => toggleDayNight()),
                const Divider(height: 1),
                SwitchListTile(
                    secondary: const Icon(Icons.format_list_numbered_rounded,
                        color: AppColors.primaryDark),
                    title: Text('ژمارە کوردی', style: TextStyle(color: txt)),
                    subtitle: Text(p.useKurdishDigits ? '١٢٣' : '123',
                        style: TextStyle(color: txt.withOpacity(.55))),
                    value: p.useKurdishDigits,
                    onChanged: (v) => setState(() => p.useKurdishDigits = v)),
              ])),
          _section('قورئان و فۆنت', dark, txt),
          Card(color: dark ? AppColors.nightCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                ListTile(
                    leading: Icon(Icons.tune_rounded,
                        color: dark ? AppColors.gold : AppColors.primaryDark),
                    title: Text('ڕێکخستنی قورئان (تەفسیر و فۆنت)',
                        style: TextStyle(fontSize: 14, color: txt)),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => showQuranSettingsSheet(context, () {})),
                ListTile(
                    leading: Icon(Icons.notifications_active_rounded,
                        color: dark ? AppColors.gold : AppColors.primaryDark),
                    title: Text('ڕێکخستنی بانگی نوێژ',
                        style: TextStyle(fontSize: 14, color: txt)),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const NwezhiSettingsScreen()))),
                ListTile(
                    leading: Icon(Icons.record_voice_over_rounded,
                        color: dark ? AppColors.gold : AppColors.primaryDark),
                    title: Text('دەنگی بانگبێژ',
                        style: TextStyle(fontSize: 14, color: txt)),
                    subtitle: Text('دەنگی هەڵبژێردراو : ${p.adhanVoiceName}',
                        style: TextStyle(fontSize: 11, color: txt.withOpacity(.55))),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const AdhanVoiceScreen()))
                        .then((_) => setState(() {}))),
                ListTile(
                    leading: Icon(Icons.schedule_rounded,
                        color: dark ? AppColors.gold : AppColors.primaryDark),
                    title: Text('دواخستن و پێشخستنی کاتی بانگدان',
                        style: TextStyle(fontSize: 14, color: txt)),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const AdhanOffsetScreen()))),
                ListTile(
                    leading: Icon(Icons.swap_vert_rounded,
                        color: dark ? AppColors.gold : AppColors.primaryDark),
                    title: Text('ڕێکخستنی بەشەکانی پەڕەی سەرەتا',
                        style: TextStyle(fontSize: 14, color: txt)),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const HomeReorderScreen()))),
              ])),
          _section('پەیوەندی', dark, txt),
          Card(color: dark ? AppColors.nightCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                ListTile(
                    leading: const Icon(Icons.facebook_rounded,
                        color: Color(0xFF1877F2)),
                    title: Text('فەیسبووک', style: TextStyle(fontSize: 14, color: txt)),
                    onTap: () => _openUrl(context,
                        'https://www.facebook.com/profile.php?id=100076875589539')),
                ListTile(
                    leading: Icon(Icons.send_rounded, color: Colors.blue.shade400),
                    title: Text('تێلێگرام', style: TextStyle(fontSize: 14, color: txt)),
                    onTap: () => _openUrl(context, 'https://t.me/Regayislam_1')),
                ListTile(
                    leading: const Icon(Icons.music_note_rounded, color: Colors.black),
                    title: Text('تیک تاک', style: TextStyle(fontSize: 14, color: txt)),
                    onTap: () => _openUrl(context,
                        'https://www.tiktok.com/@regayislam55')),
              ])),
          _section('ئێمە', dark, txt),
          Card(color: dark ? AppColors.nightCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                ListTile(
                    leading: Icon(Icons.mail_outline_rounded,
                        color: dark ? AppColors.gold : AppColors.primaryDark),
                    title: Text('پەیام و ڕەخنە', style: TextStyle(fontSize: 14, color: txt)),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const FeedbackScreen()))),
                ListTile(
                    leading: Icon(Icons.person_rounded,
                        color: dark ? AppColors.gold : AppColors.primaryDark),
                    title: Text('پرۆفایل', style: TextStyle(fontSize: 14, color: txt)),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const BandScreen()))),
                ListTile(
                    leading: Icon(Icons.language_rounded,
                        color: dark ? AppColors.gold : AppColors.primaryDark),
                    title: Text('ماڵپەڕ', style: TextStyle(fontSize: 14, color: txt)),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => WebViewScreen(
                            title: 'ڕێگای ئیسلام',
                            url: 'https://regayislam-1-default-rtdb.firebaseio.com')))),
              ])),
          const SizedBox(height: 16),
          Center(child: Text('ڕێگای ئیسلام — v70.1',
              style: TextStyle(fontSize: 12, color: txt.withOpacity(.4)))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _section(String t, bool dark, Color txt) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
      child: Text(t, style: TextStyle(fontWeight: FontWeight.bold,
          fontSize: 13, color: txt.withOpacity(.6))));
}
