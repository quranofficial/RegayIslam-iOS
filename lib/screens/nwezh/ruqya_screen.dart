import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/favorites.dart';
import '../quran/open_quran.dart' show toArabicDigits;

/// Selected Quran passages commonly included in ruqyah recitation.
class RuqyaScreen extends StatefulWidget {
  const RuqyaScreen({super.key});
  @override
  State<RuqyaScreen> createState() => _RuqyaScreenState();
}

class _RuqyaScreenState extends State<RuqyaScreen> {
  late final Future<List<Map<String, Object?>>> _verses;

  static const _ranges = <(int, int, int, String)>[
    (1, 1, 7, 'سوورەتی الفاتحة'),
    (2, 255, 255, 'ئایەتی کورسی'),
    (2, 285, 286, 'کۆتایی سوورەتی البقرة'),
    (7, 117, 122, 'سوورەتی الأعراف'),
    (10, 81, 82, 'سوورەتی يونس'),
    (20, 69, 69, 'سوورەتی طه'),
    (112, 1, 4, 'سوورەتی الإخلاص'),
    (113, 1, 5, 'سوورەتی الفلق'),
    (114, 1, 6, 'سوورەتی الناس'),
  ];

  @override
  void initState() {
    super.initState();
    _verses = _loadVerses();
  }

  Future<List<Map<String, Object?>>> _loadVerses() async {
    final out = <Map<String, Object?>>[];
    for (final r in _ranges) {
      final rows = await Db.I.ayat(r.$1, 'rebar');
      for (final row in rows) {
        final n = (row['ayah'] as num?)?.toInt() ?? 0;
        if (n >= r.$2 && n <= r.$3) {
          out.add({...row, '_surahId': r.$1, '_surahLabel': r.$4});
        }
      }
    }
    return out;
  }

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
          title: const Text('ڕوقیەی شەرعی',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: _verses,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError || !snap.hasData) {
              return Center(child: Text('ئایەتەکان نەخوێندرانەوە',
                style: TextStyle(color: txt)));
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: dark ? AppColors.nightCard : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'ئەم بەشە کۆمەڵێک ئایەتی قورئانی پیرۆز پیشان دەدات کە لە خوێندنەوەی ڕوقیەدا بەکاردێن. ناوەڕۆکەکە لە داتابەیسی قورئانی ئەپەکەوە وەردەگیرێت.',
                      style: TextStyle(height: 1.7, color: txt)),
                  ),
                ),
                const SizedBox(height: 8),
                for (final v in snap.data!)
                  Card(
                    color: dark ? AppColors.nightCard : Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(child: Text(
                              '${v['_surahLabel']} • ئایەتی ${toArabicDigits((v['ayah'] as num).toInt())}',
                              style: TextStyle(fontWeight: FontWeight.bold,
                                color: dark ? AppColors.gold : AppColors.primaryDark))),
                            FavoriteButton(
                              id: 'ruqya::${v['_surahId']}::${v['ayah']}',
                              title: '${v['_surahLabel']} • ئایەتی ${toArabicDigits((v['ayah'] as num).toInt())}',
                              content: '${v['text'] ?? ''}',
                            ),
                          ]),
                          const SizedBox(height: 8),
                          SelectableText('${v['text'] ?? ''}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: AppPrefs.I.fontQuran,
                              fontSize: AppPrefs.I.quranFontSize.toDouble(),
                              height: 2, color: txt)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
