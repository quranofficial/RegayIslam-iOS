import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';

/// Dedicated Ayat al-Kursi reader (Al-Baqarah 2:255).
class AyatulKursiScreen extends StatelessWidget {
  const AyatulKursiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('ئایەتی کورسی',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: Db.I.ayat(2, AppPrefs.I.tafsir),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return Center(child: Text('خوێندنەوەی ئایەتەکە سەرکەوتوو نەبوو',
                  style: TextStyle(color: txt)));
            }
            final rows = snap.data!
                .where((r) => (r['ayah'] as num?)?.toInt() == 255)
                .toList();
            if (rows.isEmpty) {
              return Center(child: Text('ئایەتی کورسی لە داتابەیسدا نەدۆزرایەوە',
                  style: TextStyle(color: txt)));
            }
            final row = rows.first;
            final arabic = '${row['text'] ?? ''}';
            final tafsir = '${row[AppPrefs.I.tafsir] ?? ''}';
            return ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: dark ? AppColors.nightCard : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: dark ? Colors.white12 : Colors.black12),
                ),
                child: Column(children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.gold, size: 34),
                  const SizedBox(height: 8),
                  const Text('سوورەتی البقرة • ئایەتی ٢٥٥',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 18),
                  SelectableText(arabic,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AppPrefs.I.fontQuran,
                      fontFamilyFallback: const ['Quran', 'Quran1', 'Quran3'],
                      fontSize: AppPrefs.I.quranFontSize.toDouble(),
                      height: 2.1, color: txt)),
                  if (tafsir.trim().isNotEmpty) ...[
                    const Divider(height: 28),
                    Align(alignment: Alignment.centerRight,
                      child: Text('تەفسیر',
                        style: TextStyle(fontWeight: FontWeight.bold,
                          color: dark ? AppColors.gold : AppColors.primaryDark))),
                    const SizedBox(height: 8),
                    SelectableText(tafsir,
                      style: TextStyle(fontSize: 15, height: 1.9, color: txt)),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text:
                        'ئایەتی کورسی — البقرة ٢٥٥\n\n$arabic\n\n$tafsir'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ئایەتەکە کۆپی کرا')));
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('کۆپی ئایەت'),
                  ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
