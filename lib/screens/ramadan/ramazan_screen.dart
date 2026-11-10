import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/rtdb.dart';
import '../../data/favorites.dart';

/// Original: RamazanActivity + Ramazan1Activity — Ramadan content from rm.db
/// (sections: پێشوازی، ڕۆژوو، شەوی قەدر...) and the live Ramadan banner from
/// Firebase "ramadan". Items 5 + 11: the sections list is searchable.
class RamazanScreen extends StatefulWidget {
  const RamazanScreen({super.key});
  @override
  State<RamazanScreen> createState() => _RamazanScreenState();
}

class _RamazanScreenState extends State<RamazanScreen> {
  String _q = '';

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
            final allTitles = snap.data!;
            final q = _q.trim().toLowerCase();
            final titles = q.isEmpty
                ? allTitles
                : allTitles
                    .where((t) => '${t['titles'] ?? ''}'
                        .toLowerCase()
                        .contains(q))
                    .toList();
            return ListView(padding: const EdgeInsets.all(12), children: [
              // Items 5 + 11: search inside the section.
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'گەڕان لە بەشەکانی ڕەمەزان...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withOpacity(.12),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              if (titles.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Text('هیچ بەشێک نەدۆزرایەوە',
                        style: TextStyle(color: Colors.white.withOpacity(.7))),
                  ),
                ),
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
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      FavoriteButton(id: 'ramadan_section::${t['tableName']}',
                        title: '${t['titles'] ?? 'ڕەمەزان'}', content: 'بەشی مانگی ڕەمەزان'),
                      Icon(Icons.chevron_left, color: txt.withOpacity(.4)),
                    ]),
                  ),
                ),
              const SizedBox(height: 8),
              // Firebase day banner (original _ramadan_onChildAdded)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: Rtdb.I.ramadan(),
                builder: (context, fs) {
                  if (!fs.hasData || fs.data!.isEmpty) return const SizedBox();
                  final last = fs.data!.last;
                  final state = '${last['state'] ?? ''}'.toLowerCase();
                  if (state == 'false') return const SizedBox();
                  final day = '${last['day'] ?? ''}'.trim();
                  final month = '${last['month'] ?? ''}'.trim();
                  final when = day.isNotEmpty
                      ? 'ئێمە ئێستا لە ڕۆژی $day'
                          '${month.isNotEmpty ? 'ی مانگی $month' : ''} دابوون'
                      : '';
                  final extra = '${last['text'] ?? ''}'.trim();
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.12),
                        borderRadius: BorderRadius.circular(14)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${last['title'] ?? 'ڕەمەزانتان پیرۆز بێت'}',
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          if (when.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(when,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(.85),
                                    fontSize: 12.5, height: 1.6)),
                          ],
                          if (extra.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(extra,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(.85),
                                    fontSize: 12.5, height: 1.6)),
                          ],
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
                        Row(children: [
                          Expanded(child: Text('${r['title'] ?? ''}',
                            style: TextStyle(fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: dark ? AppColors.gold : const Color(0xFF1B5E20)))),
                          FavoriteButton(id: 'ramadan_content::${table}::${r['_id'] ?? i}',
                            title: '${r['title'] ?? title}', content: '${r['desc'] ?? ''}'),
                        ]),
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
