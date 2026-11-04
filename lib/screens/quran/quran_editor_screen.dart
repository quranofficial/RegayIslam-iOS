import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';

/// Quran reader appearance editor. It changes presentation settings only;
/// the bundled Quran source text remains unchanged.
class QuranEditorScreen extends StatefulWidget {
  const QuranEditorScreen({super.key});
  @override
  State<QuranEditorScreen> createState() => _QuranEditorScreenState();
}

class _QuranEditorScreenState extends State<QuranEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final p = AppPrefs.I;
    final dark = !p.day;
    final txt = dark ? Colors.white : Colors.black;
    final card = dark ? AppColors.nightCard : Colors.white;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: dark ? AppColors.nightBg : const Color(0xFFF4F5F7),
        appBar: AppBar(
          backgroundColor: dark ? AppColors.nightCard : AppColors.primaryDark,
          title: const Text('ئیدیتی قورئان',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          Card(
            color: card,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Text('نموونەی نووسینی قورئان',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: p.fontQuran,
                    fontSize: p.quranFontSize.toDouble(), height: 2,
                    color: txt)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _heading('فۆنتی قورئان', txt),
          Card(color: card, child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final font in kFontsQuran)
                ChoiceChip(
                  label: Text(font, style: TextStyle(fontFamily: font)),
                  selected: p.fontQuran == font,
                  onSelected: (_) => setState(() => p.fontQuran = font),
                ),
            ]),
          )),
          const SizedBox(height: 12),
          _heading('قەبارەی نووسین', txt),
          Card(color: card, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.text_decrease_rounded),
                Expanded(child: Slider(
                  min: 16, max: 54, divisions: 19,
                  value: p.quranFontSize.toDouble().clamp(16.0, 54.0).toDouble(),
                  label: '${p.quranFontSize}',
                  onChanged: (v) => setState(() => p.quranFontSize = v.round()),
                )),
                const Icon(Icons.text_increase_rounded),
              ]),
              Text('${p.quranFontSize}',
                style: TextStyle(color: txt.withOpacity(.65))),
            ]),
          )),
          const SizedBox(height: 12),
          _heading('تەفسیر', txt),
          Card(color: card, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: kTafsirs.contains(p.tafsir) ? p.tafsir : kTafsirs.first,
                isExpanded: true,
                items: [for (final t in kTafsirs)
                  DropdownMenuItem(value: t,
                    child: Text(kTafsirNames[t] ?? t))],
                onChanged: (v) { if (v != null) setState(() => p.tafsir = v); },
              ),
            ),
          )),
          const SizedBox(height: 12),
          _heading('پیشاندانی قورئان', txt),
          Card(color: card, child: Column(children: [
            SwitchListTile(
              title: Text('پیشاندانی تەفسیر', style: TextStyle(color: txt)),
              value: p.showQuranTafsir,
              onChanged: (v) => setState(() => p.showQuranTafsir = v),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: Text('پیشاندانی ژمارەی ئایەت', style: TextStyle(color: txt)),
              value: p.showQuranAyahNumbers,
              onChanged: (v) => setState(() => p.showQuranAyahNumbers = v),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: Text('پیشاندانی ناوی سوورەت', style: TextStyle(color: txt)),
              value: p.showQuranSurahName,
              onChanged: (v) => setState(() => p.showQuranSurahName = v),
            ),
          ])),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ڕێکخستنەکانی قورئان پاشەکەوت کران')));
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('پاشەکەوتکردنی ڕێکخستنەکان'),
          ),
        ]),
      ),
    );
  }

  Widget _heading(String title, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
    child: Text(title, style: TextStyle(
      color: color, fontWeight: FontWeight.bold, fontSize: 14)),
  );
}
