import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/rtdb.dart';

/// Original: RamazanActivity + Ramazan1Activity — Ramadan content from rm.db
/// (sections: پێشوازی، ڕۆژوو، شەوی قەدر...) and the live Ramadan banner from
/// Firebase "ramadan".
class RamazanScreen extends StatelessWidget {
  const RamazanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFF1B5E20),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('مانگی ڕەمەزان',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: Db.I.ramadanTitles(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            final titles = snap.data!;
            return ListView(padding: const EdgeInsets.all(12), children: [
              for (final t in titles)
                Card(
                  color: dark ? AppColors.nightCard : Colors.white,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => RamadanDetailScreen(
                            table: '${t['tableName']}',
                            title: '${t['titles']}'))),
                    leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1B5E20),
                        child: Text('${t['idku'] ?? ''}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13))),
                    title: Text('${t['titles']}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
                    trailing: Icon(Icons.chevron_left, color: txt.withOpacity(.4)),
                  ),
                ),
              const SizedBox(height: 8),
              // Firebase day banner (original _ramadan_onChildAdded)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: Rtdb.I.ramadan(),
                builder: (context, fs) {
                  if (!fs.hasData || fs.data!.isEmpty) return const SizedBox();
                  final last = fs.data!.last;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.12),
                        borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${last['title'] ?? 'ڕەمەزانتان پیرۆز'}',
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('${last['text'] ?? ''}',
                              style: TextStyle(color: Colors.white.withOpacity(.85),
                                  fontSize: 12.5, height: 1.6)),
                        ]),
                  );
                },
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class RamadanDetailScreen extends StatelessWidget {
  const RamadanDetailScreen({super.key, required this.table, required this.title});
  final String table;
  final String title;

  @override
  Widget build(BuildContext context) {
    final dark = !AppPrefs.I.day;
    final txt = dark ? Colors.white : Colors.black;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : Colors.white,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : const Color(0xFF1B5E20),
          title: Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: Db.I.ramadanRows(table),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snap.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = rows[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: dark ? AppColors.nightCard : const Color(0xFFF4FAF4),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r['title'] ?? ''}',
                            style: TextStyle(fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: dark ? AppColors.gold : const Color(0xFF1B5E20))),
                        const SizedBox(height: 6),
                        SelectableText('${r['desc'] ?? ''}',
                            style: TextStyle(fontSize: 14, height: 1.9, color: txt)),
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
