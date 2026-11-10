import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/favorites.dart';
import '../../main.dart' show LastRoute;

/// Original: KrdnawaActivity — renders a zikr/detail whose content was put
/// into the prefs by the caller (name / zkr / vip keys in the original).
class ZikrDetailScreen extends StatefulWidget {
  const ZikrDetailScreen({super.key});
  @override
  State<ZikrDetailScreen> createState() => _ZikrDetailScreenState();
}

class _ZikrDetailScreenState extends State<ZikrDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Item 5-d: record this zikr as the last place ("continue where I left
    // off") — the zikr content itself lives in AppPrefs, so the next start
    // can reopen exactly this screen.
    LastRoute.set('zikr::${AppPrefs.I.zikrName}');
  }

  @override
  void dispose() {
    // Popped normally → fall back to the home tab, so closing the app
    // afterwards reopens the top (and not this zikr again).
    LastRoute.set('tab::0');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPrefs.I;
    final dark = !p.day;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: Text(p.zikrName.isEmpty ? 'زیکر' : p.zikrName,
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.bold)),
          actions: [
            FavoriteButton(id: 'zikr::${p.zikrName}',
              title: p.zikrName.isEmpty ? 'زیکر' : p.zikrName,
              content: p.zikrBody, color: Colors.white),
            IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () => Share.share(
                    '${p.zikrName}\n\n${p.zikrBody}\n\n#ڕێگای ئیسلام')),
            IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                      text: '${p.zikrName}\n\n${p.zikrBody}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('کۆپی کرا')));
                }),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          if (p.zikrVip.isNotEmpty)
            Text(p.zikrVip,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: dark ? AppColors.gold : AppColors.primaryDark)),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.rtl,
            child: SelectableText(
                p.zikrBody.isEmpty ? 'ناوەڕۆک نییە' : p.zikrBody,
                style: TextStyle(fontSize: p.fontSize.toDouble() + 2,
                    height: 2, color: txt)),
          ),
        ]),
      ),
    );
  }
}
