import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../core/prefs.dart';
import '../../data/db.dart';
import '../../data/favorites.dart';

/// Original: NameActivity — the 99 names of Allah (name.db) with
/// Sorani/Badini/English/Farsi meanings.
class NameScreen extends StatefulWidget {
  const NameScreen({super.key});
  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  List<Map<String, Object?>> _rows = [];
  List<Map<String, Object?>> _filtered = [];
  int? _open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await Db.I.names();
    if (!mounted) return;
    setState(() { _rows = rows; _filtered = rows; });
  }

  void _filter(String q) {
    q = q.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _rows
          : _rows.where((r) {
              return '${r['arabic']}'.contains(q) ||
                  '${r['sorani']}'.toLowerCase().contains(q) ||
                  '${r['english']}'.toLowerCase().contains(q);
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
          title: const Text('ناوەکانی خودای گەورە',
              style: TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'گەڕان...',
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
                final r = _filtered[i];
                final open = _open == i;
                return Card(
                  color: dark ? AppColors.nightCard : Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _open = open ? null : i),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              CircleAvatar(
                                  radius: 20,
                                  backgroundColor: dark
                                      ? AppColors.gold.withOpacity(.15)
                                      : AppColors.primaryDark.withOpacity(.08),
                                  child: Text('${(r['_id'] as num?)?.toInt() ?? i + 1}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: dark ? AppColors.gold : AppColors.primaryDark))),
                              const SizedBox(width: 10),
                              Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text('${r['arabic']}',
                                    style: TextStyle(
                                        fontFamily: 'Quran', fontSize: 22, color: txt)),
                              ),
                              const Spacer(),
                              Icon(open
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                                  color: txt.withOpacity(.4)),
                            ]),
                            if (open) ...[
                              const SizedBox(height: 10),
                              _m('کوردی', '${r['sorani']}', txt, dark),
                              if ('${r['badini'] ?? ''}'.trim().isNotEmpty)
                                _m('بادینی', '${r['badini']}', txt, dark),
                              _m('English', '${r['english'] ?? ''}', txt, dark),
                              if ('${r['farsi'] ?? ''}'.trim().isNotEmpty)
                                _m('فارسی', '${r['farsi']}', txt, dark),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                FavoriteButton(id: 'allahname::${r['_id'] ?? i}',
                                  title: '${r['arabic']}', content: '${r['sorani']}'),
                                TextButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(
                                          text: '${r['arabic']}\n${r['sorani']}'));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('کۆپی کرا')));
                                    },
                                    icon: const Icon(Icons.copy_rounded, size: 16),
                                    label: const Text('کۆپی', style: TextStyle(fontSize: 12))),
                                TextButton.icon(
                                    onPressed: () => Share.share(
                                        '${r['arabic']}\n${r['sorani']}\n\n#ڕێگای ئیسلام'),
                                    icon: const Icon(Icons.share_rounded, size: 16),
                                    label: const Text('هاوبەشی', style: TextStyle(fontSize: 12))),
                              ]),
                            ],
                          ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _m(String label, String value, Color txt, bool dark) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
          Text(value, style: TextStyle(fontSize: 13.5, height: 1.6, color: txt)),
        ]),
      );
}
