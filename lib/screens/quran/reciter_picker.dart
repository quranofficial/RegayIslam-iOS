import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../data/reciters.dart';

/// Shared bottom-sheet reciter picker — used by the Quran reader, the
/// Mushaf and the Quran-audio screen. Lists ONLY the dangakan doxx=true
/// reciters (audio + timings db assets/db/<id>.db ready), with a live
/// search filter, bundled avatars and the current choice highlighted.
/// Popping with a map means "switch to this reciter".
class ReciterPickerSheet extends StatefulWidget {
  const ReciterPickerSheet({
    super.key,
    required this.currentId,
    required this.dark,
    this.title = 'هەڵبژاردنی قاری',
  });
  final String currentId;
  final bool dark;
  final String title;

  static Future<Map<String, dynamic>?> show(BuildContext context,
      {required String currentId, required bool dark, String? title}) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReciterPickerSheet(
          currentId: currentId, dark: dark, title: title ?? 'هەڵبژاردنی قاری'),
    );
  }

  @override
  State<ReciterPickerSheet> createState() => _ReciterPickerSheetState();
}

class _ReciterPickerSheetState extends State<ReciterPickerSheet> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _shown = [];
  bool _loading = true;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _all = await Reciters.supportedList();
      _shown = _all;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _filter(String q) {
    q = q.trim().toLowerCase();
    setState(() {
      _shown = q.isEmpty
          ? _all
          : _all.where((r) {
              final name = '${r['name_ar'] ?? ''}'.toLowerCase();
              final id = '${r['id'] ?? ''}';
              return name.contains(q) || id == q;
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final txt = dark ? Colors.white : Colors.black;
    Map<String, dynamic> current = {};
    for (final r in _all) {
      if ('${r['id']}' == widget.currentId) {
        current = r;
        break;
      }
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .78),
        decoration: BoxDecoration(
            color: dark ? AppColors.nightCard : Colors.white,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20))),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 44, height: 4,
              decoration: BoxDecoration(
                  color: txt.withOpacity(.25),
                  borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Icon(Icons.mic_rounded, size: 20,
                  color: dark ? AppColors.gold : AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.title,
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 16, color: txt))),
              if (current.isNotEmpty)
                Flexible(
                  child: Text('${current['name_ar'] ?? ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5,
                          color: dark ? AppColors.gold : AppColors.primaryDark)),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'گەڕان بۆ قاری...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                filled: true,
                fillColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _shown.isEmpty
                    ? Center(child: Text('هیچ قارییەک نەدۆزرایەوە',
                        style: TextStyle(color: txt.withOpacity(.6))))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _shown.length,
                        itemBuilder: (context, i) {
                          final r = _shown[i];
                          final rid = '${r['id'] ?? ''}';
                          final selected = rid == widget.currentId;
                          final asset = int.tryParse(rid) != null &&
                                  int.parse(rid) >= 1 && int.parse(rid) <= 81
                              ? 'assets/images/qari/$rid.png'
                              : null;
                          return ListTile(
                            onTap: () => Navigator.pop(context, r),
                            leading: Container(
                              width: 44, height: 44,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dark ? AppColors.nightBg : Colors.white,
                                border: Border.all(
                                    color: selected
                                        ? AppColors.gold
                                        : (dark ? Colors.white24 : Colors.black12),
                                    width: selected ? 2.2 : 1),
                              ),
                              child: ClipOval(
                                child: asset != null
                                    ? Image.asset(asset, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Icon(Icons.mic_rounded, size: 18,
                                                color: txt.withOpacity(.5)))
                                    : Icon(Icons.mic_rounded, size: 18,
                                        color: txt.withOpacity(.5)),
                              ),
                            ),
                            title: Text('${r['name_ar'] ?? ''}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 14,
                                    color: selected
                                        ? (dark ? AppColors.gold : AppColors.primaryDark)
                                        : txt)),
                            subtitle: const Text('دەنگ و ئایەت بەردەستە',
                                style: TextStyle(fontSize: 10.5)),
                            trailing: selected
                                ? Icon(Icons.check_circle_rounded, size: 22,
                                    color: dark ? AppColors.gold : AppColors.primaryDark)
                                : null,
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}
