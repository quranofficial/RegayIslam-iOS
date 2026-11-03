import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';

/// Original: DasalatakanActivity — supplications during prayer (duha.db).
class DasalatakanScreen extends StatelessWidget {
  const DasalatakanScreen({super.key});

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
          title: const Text('دوعاکانی نوێژ',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: Db.I.du3a(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snap.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = rows[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: dark ? AppColors.nightCard : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r['wata'] ?? ''}',
                            style: TextStyle(fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: dark ? AppColors.gold : AppColors.primaryDark)),
                        const SizedBox(height: 6),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text('${r['du3a'] ?? ''}',
                              style: TextStyle(fontFamily: 'Quran',
                                  fontSize: 18, height: 2, color: txt)),
                        ),
                      ]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
