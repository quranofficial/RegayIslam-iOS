import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';
import 'tasbih_counter.dart';

/// Original: TasbihFragmentActivity — saved tasbih list with counts.
class TasbihListScreen extends StatefulWidget {
  const TasbihListScreen({super.key});
  @override
  State<TasbihListScreen> createState() => _TasbihListScreenState();
}

class _TasbihListScreenState extends State<TasbihListScreen> {
  late List<String> _items;
  final TextEditingController _add = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = [...AppPrefs.I.tasbihList];
  }

  void _persist() {
    AppPrefs.I.tasbihList = _items;
  }

  Future<void> _addItem() async {
    final v = _add.text.trim();
    if (v.isEmpty) return;
    setState(() { _items.add('$v|33'); _add.clear(); });
    _persist();
  }

  @override
  void dispose() { _add.dispose(); super.dispose(); }

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
          title: const Text('تەسبیح',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _add,
                  onSubmitted: (_) => _addItem(),
                  decoration: InputDecoration(
                    hintText: 'زیکرێکی نوێ زیاد بکە...',
                    prefixIcon: const Icon(Icons.add_rounded),
                    filled: true,
                    fillColor: dark ? AppColors.nightCard : Colors.white,
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
                      padding: const EdgeInsets.all(14)),
                  onPressed: _addItem,
                  child: const Icon(Icons.check_rounded)),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final parts = _items[i].split('|');
                final name = parts.first;
                final target = int.tryParse(parts.length > 1 ? parts[1] : '33') ?? 33;
                return Card(
                  color: dark ? AppColors.nightCard : Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => TasbihCounterScreen())),
                    title: Text(name,
                        style: TextStyle(fontWeight: FontWeight.bold, color: txt)),
                    subtitle: Text('ئامانج: $target',
                        style: TextStyle(fontSize: 12, color: txt.withOpacity(.55))),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent),
                        onPressed: () =>
                            setState(() { _items.removeAt(i); _persist(); })),
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
