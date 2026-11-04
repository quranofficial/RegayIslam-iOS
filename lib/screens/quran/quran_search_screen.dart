import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/favorites.dart';

/// Original: QuransearchActivity — full-quran search over text + tafsir.
class QuranSearchScreen extends StatefulWidget {
  const QuranSearchScreen({super.key});
  @override
  State<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends State<QuranSearchScreen> {
  final TextEditingController _c = TextEditingController();
  List<Map<String, Object?>> _results = [];
  bool _searched = false;
  bool _busy = false;

  Future<void> _do() async {
    final q = _c.text.trim();
    if (q.isEmpty) return;
    setState(() => _busy = true);
    final rows = await Db.I.searchQuran(q, AppPrefs.I.tafsir);
    if (!mounted) return;
    setState(() { _results = rows; _searched = true; _busy = false; });
  }

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
          title: const Text('گەڕان لە قورئان',
              style: TextStyle(color: Colors.white, fontSize: 17)),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  onSubmitted: (_) => _do(),
                  decoration: InputDecoration(
                    hintText: 'وشەیەک بنووسە (ئایەت یان تەفسیر)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: dark ? AppColors.nightCard : const Color(0xFFF4F5F7),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _busy ? null : _do,
                  child: _busy
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('گەڕان')),
            ]),
          ),
          Expanded(
            child: !_searched
                ? Center(child: Text('گەڕان بکە بۆ دۆزینەوەی ئایەتەکان',
                    style: TextStyle(color: txt.withOpacity(.5))))
                : _results.isEmpty
                    ? Center(child: Text('هیچ ئەنجامێک نەدۆزرایەوە',
                        style: TextStyle(color: txt.withOpacity(.5))))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: dark ? AppColors.nightCard : const Color(0xFFF4F5F7),
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(child: Text('${r['sura_name_ar']} • ئایەتی ${r['ayah']}',
                                      style: TextStyle(fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDark))),
                                    FavoriteButton(id: 'quran_search::${r['suraId']}::${r['ayah']}',
                                      title: '${r['sura_name_ar']} • ئایەتی ${r['ayah']}',
                                      content: '${r['text'] ?? ''}'),
                                  ]),
                                  const SizedBox(height: 6),
                                  Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Text('${r['text']}',
                                        style: TextStyle(
                                            fontFamily: AppPrefs.I.fontQuran,
                                            fontSize: 18, height: 1.9, color: txt)),
                                  ),
                                ]),
                          );
                        }),
          ),
        ]),
      ),
    );
  }
}
