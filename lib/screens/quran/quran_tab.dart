import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import 'open_quran.dart' show OpenQuranScreen, toArabicDigits;
import 'quran_search_screen.dart';

/// Original: QurannFragmentActivity — surah list with live search filter.
class QuranTab extends StatefulWidget {
  const QuranTab({super.key});
  @override
  State<QuranTab> createState() => _QuranTabState();
}

class _QuranTabState extends State<QuranTab> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, Object?>> _all = [];
  List<Map<String, Object?>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await Db.I.surahs();
    if (!mounted) return;
    setState(() { _all = rows; _filtered = rows; _loading = false; });
  }

  void _filter(String q) {
    q = q.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((r) {
              final name = (r['name'] ?? '').toString().toLowerCase();
              final id = (r['soraid'] ?? '').toString();
              return name.contains(q) || id == q;
            }).toList();
    });
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
          title: const Text('قورئانی پیرۆز',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                tooltip: 'گەڕان لە ناو ئایەتەکان',
                icon: const Icon(Icons.travel_explore_rounded, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const QuranSearchScreen()))),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _search,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'گەڕان بۆ سوورەت...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: dark ? AppColors.nightCard : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final s = _filtered[i];
                      final num = int.tryParse('${s['soraid']}') ?? 0;
                      return Card(
                        color: dark ? AppColors.nightCard : Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: ListTile(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => OpenQuranScreen(
                                  surahId: num,
                                  surahName: '${s['name']}',
                                  ayaCount: int.tryParse('${s['aya']}') ?? 0,
                                  place: '${s['place']}',
                                  juz: '${s['juz']}'))),
                          leading: SizedBox(
                            width: 44, height: 44,
                            child: Stack(alignment: Alignment.center, children: [
                              Image.asset('assets/images/icon/$num.png',
                                  width: 44, height: 44,
                                  errorBuilder: (_, __, ___) => Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                          color: AppColors.primaryDark
                                              .withOpacity(.08),
                                          shape: BoxShape.circle)),
                              ),
                              Text(toArabicDigits(num),
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark)),
                            ]),
                          ),
                          title: Text('${s['name']}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: txt)),
                          subtitle: Text(
                              '${s['aya']} ئایەت • ${s['place']} • ${s['juz']}',
                              style: TextStyle(
                                  fontSize: 12, color: txt.withOpacity(.6))),
                          trailing: Icon(Icons.chevron_left,
                              color: txt.withOpacity(.4)),
                        ),
                      );
                    },
                  ),
                ),
              ]),
      ),
    );
  }
}
