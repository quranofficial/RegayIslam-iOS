import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';

/// Original: Hack1Activity — generic article reader over the bundled JSON
/// files (zikrakan, duha, agr, bahasht, xawn, wta, ...), with live search,
/// copy and share of each item.
class JsonArticleScreen extends StatefulWidget {
  const JsonArticleScreen({super.key, required this.file, required this.title});
  final String file;
  final String title;
  @override
  State<JsonArticleScreen> createState() => _JsonArticleScreenState();
}

class _JsonArticleScreenState extends State<JsonArticleScreen> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  int? _open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(widget.file);
      final list = jsonDecode(raw) as List;
      setState(() {
        _all = list.map((e) => Map<String, dynamic>.from(e)).toList();
        _filtered = _all;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _filter(String q) {
    q = q.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((m) {
              return '${m['title'] ?? ''}'.toLowerCase().contains(q) ||
                  '${m['text'] ?? ''}'.toLowerCase().contains(q);
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
          title: Text(widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                  child: _filtered.isEmpty
                      ? Center(child: Text('هیچ نەدۆزرایەوە',
                          style: TextStyle(color: txt.withOpacity(.5))))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) {
                            final m = _filtered[i];
                            final open = _open == i;
                            final title = '${m['title'] ?? ''}';
                            final text = '${m['text'] ?? ''}';
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
                                  child: Column(crossAxisAlignment:
                                      CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Container(width: 4, height: 34,
                                          decoration: BoxDecoration(
                                              color: AppColors.primaryDark,
                                              borderRadius: BorderRadius.circular(4))),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                            title.isEmpty ? text.split('\n').first : title,
                                            maxLines: 2, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontWeight: FontWeight.bold,
                                                fontSize: 14, color: txt)),
                                      ),
                                      Icon(open
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                          color: txt.withOpacity(.4)),
                                    ]),
                                    if (open) ...[
                                      const SizedBox(height: 10),
                                      Directionality(
                                        textDirection: TextDirection.rtl,
                                        child: SelectableText(
                                            m['text2'] != null && '${m['text2']}'.isNotEmpty
                                                ? '$text\n\n${m['text2']}'
                                                : text,
                                            style: TextStyle(fontSize: 15,
                                                height: 1.9, color: txt)),
                                      ),
                                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                        TextButton.icon(
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(
                                                  text: '$title\n$text\n\n#ڕێگای ئیسلام'));
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text('کۆپی کرا')));
                                            },
                                            icon: const Icon(Icons.copy_rounded, size: 16),
                                            label: const Text('کۆپی',
                                                style: TextStyle(fontSize: 12))),
                                        TextButton.icon(
                                            onPressed: () => Share.share(
                                                '$title\n\n$text\n\n#ڕێگای ئیسلام'),
                                            icon: const Icon(Icons.share_rounded, size: 16),
                                            label: const Text('هاوبەشی',
                                                style: TextStyle(fontSize: 12))),
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
}
