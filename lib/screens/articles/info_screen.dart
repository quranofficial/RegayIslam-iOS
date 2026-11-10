import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import '../../data/favorites.dart';

/// Renders the static screens ported 1:1 from the original activities
/// (Hwhe, Whw, Gss, Hwuw, Vsbs, Cheshtan, Estyxara, Islam, Fate7a, Error,
/// Manaynwezh, Page123, Seetine, Brdnapesh, ...). Content comes from
/// assets/data/generated_static.json which was extracted from the original
/// view definitions.
class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key, required this.screenKey, required this.title});
  final String screenKey;
  final String title;
  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  Map<String, double> _sizes = {};

  Future<List<Map<String, dynamic>>> _loadStatic() async {
    final raw = await rootBundle.loadString('assets/data/generated_static.json');
    final all = jsonDecode(raw) as Map<String, dynamic>;
    return (all[widget.screenKey] as List?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[];
  }

  @override
  void initState() {
    super.initState();
    _loadStatic().then((items) {
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    });
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
          title: Text(widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white),
                onPressed: () {
                  final sb = StringBuffer('${widget.title}\n\n');
                  for (final i in _items) {
                    sb.writeln(i['text']); sb.writeln();
                  }
                  Share.share('${sb}\n#ڕێگای ئیسلام');
                }),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final item in _items)
                    _block(item, txt, dark),
                ]),
      ),
    );
  }

  Widget _block(Map<String, dynamic> item, Color txt, bool dark) {
    final id = '${item['id'] ?? ''}';
    final isTitle = id == 'title';
    final text = '${item['text'] ?? ''}';
    final size = (_sizes[id] ?? ((item['size'] as num?)?.toDouble() ??
        (isTitle ? 20 : (item['w'] == 'EditText' ? 15 : 15))));
    final bold = isTitle || item['bold'] == true;
    final arabic = RegExp(r'[\u0600-\u06FF\u0750-\u077F]').hasMatch(text) &&
        !text.contains('ک') && !text.contains('ێ') && !text.contains('ە');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isTitle)
          Text(text,
              style: TextStyle(
                  fontSize: size, fontWeight: FontWeight.bold,
                  color: dark ? AppColors.gold : AppColors.primaryDark))
        else
          Directionality(
            textDirection: TextDirection.rtl,
            child: SelectableText(text,
                style: TextStyle(
                    fontSize: size,
                    height: 1.9,
                    fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                    fontFamily: arabic ? 'Quran' : null,
                    color: txt))),
        if (!isTitle)
          Align(alignment: Alignment.centerLeft,
            child: FavoriteButton(id: 'info::${widget.screenKey}::$id',
              title: widget.title, content: text)),
      ]),
    );
  }
}
