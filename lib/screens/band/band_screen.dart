import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/rtdb.dart';

/// Original: BandActivity — profile from Firebase "bandaccount"; shows the
/// about card and opens it in-app when data exists.
class BandScreen extends StatelessWidget {
  const BandScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('پرۆفایل',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: Rtdb.I.list('bandaccount'),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data!;
            return ListView(padding: const EdgeInsets.all(16), children: [
              Center(child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.primaryDark.withOpacity(.08),
                  child: Icon(Icons.person_rounded, size: 50,
                      color: dark ? AppColors.gold : AppColors.primaryDark))),
              const SizedBox(height: 12),
              Center(child: Text(AppPrefs.I.cityName == '' ? 'بەکارهێنەر' : 'ئەندامی ڕێگای ئیسلام',
                  style: TextStyle(fontWeight: FontWeight.bold, color: txt))),
              if (items.isEmpty) ...[
                const SizedBox(height: 20),
                Center(child: Text('هیچ زانیارییەک بۆ پرۆفایل بەردەست نییە',
                    style: TextStyle(fontSize: 12.5,
                        color: txt.withOpacity(.5)))),
              ],
              const SizedBox(height: 20),
              for (final b in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: dark ? AppColors.nightCard : const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${b['title'] ?? b['name'] ?? ''}',
                            style: TextStyle(fontWeight: FontWeight.bold,
                                fontSize: 15, color: txt)),
                        const SizedBox(height: 6),
                        SelectableText('${b['about'] ?? b['text'] ?? ''}',
                            style: TextStyle(fontSize: 14, height: 1.8,
                                color: txt.withOpacity(.85))),
                      ]),
                ),
            ]);
          },
        ),
      ),
    );
  }
}
