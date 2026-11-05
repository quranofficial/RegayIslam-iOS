import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../core/ui.dart' show bottomInset;
import '../../data/db.dart';
import '../../data/favorites.dart';

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
              padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset(context, extra: 14)),
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
                        Row(children: [
                          Expanded(child: Text('${r['wata'] ?? ''}',
                            style: TextStyle(fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: dark ? AppColors.gold : AppColors.primaryDark))),
                          FavoriteButton(id: 'prayer_dua::${r['id'] ?? i}',
                            title: '${r['wata'] ?? 'دوعای نوێژ'}', content: '${r['du3a'] ?? ''}'),
                        ]),
                        const SizedBox(height: 6),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text('${r['du3a'] ?? ''}',
                              style: TextStyle(fontFamily: 'Quran',
                                  fontFamilyFallback: const ['Quran1', 'Quran3'],
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
