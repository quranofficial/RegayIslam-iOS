import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';

/// Quran reader appearance editor — font, size, text color, reader
/// background color, tafsir and display toggles, with a live preview.
/// (The image/video creator lives in QuranStudioScreen.)
class QuranEditorScreen extends StatefulWidget {
  const QuranEditorScreen({super.key});
  @override
  State<QuranEditorScreen> createState() => _QuranEditorScreenState();
}

class _QuranEditorScreenState extends State<QuranEditorScreen> {
  static const _textColors = [
    0x00000000, // follow theme
    0xFF000000, 0xFF004D7B, 0xFF1B5E20, 0xFF4A148C, 0xFFB71C1C,
  ];
  static const _bgColors = [
    0x00000000, // follow theme
    0xFFFDF6E3, 0xFFF7F1E3, 0xFFE8F0FE, 0xFFE8F5E9, 0xFF1A1A1A,
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPrefs.I;
    final dark = !p.day;
    final txt = dark ? Colors.white : Colors.black;
    final card = dark ? AppColors.nightCard : Colors.white;
    final previewTextColor = p.quranTextColor != 0
        ? Color(p.quranTextColor)
        : txt;
    final previewBg = p.quranBgColor != 0 ? Color(p.quranBgColor) : card;
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
          // ---- live preview -------------------------------------------------
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: previewBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: dark ? Colors.white10 : Colors.black12),
            ),
            child: Column(children: [
              const Text('نموونەی نووسینی قورئان',
                style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text('وَمَا آتَاكُمْ إِلَّا زَلْفًا ۗ وَمَا آتَى الرَّسُولُ فَخُذُوهُ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: p.fontQuran,
                    fontFamilyFallback: const ['Quran', 'Quran1', 'Quran3'],
                    fontSize: p.quranFontSize.toDouble(), height: 2,
                    color: previewTextColor)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _heading('ڕەنگی دەقی ئایەت', txt),
          Card(color: card, child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 10, children: [
              for (final c in _textColors)
                _colorDot(
                  c == 0x00000000 ? null : Color(c),
                  selected: p.quranTextColor == c,
                  dark: dark,
                  label: c == 0x00000000 ? 'ئۆتۆ' : null,
                  onTap: () => setState(() => p.quranTextColor = c)),
            ]),
          )),
          const SizedBox(height: 12),
          _heading('ڕەنگی پاشبنەمای خوێندنەوە', txt),
          Card(color: card, child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 10, children: [
              for (final c in _bgColors)
                _colorDot(
                  c == 0x00000000 ? null : Color(c),
                  selected: p.quranBgColor == c,
                  dark: dark,
                  label: c == 0x00000000 ? 'ئۆتۆ' : null,
                  onTap: () => setState(() => p.quranBgColor = c)),
            ]),
          )),
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
                  activeColor: dark ? AppColors.gold : AppColors.primaryDark,
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

  Widget _colorDot(Color? color,
      {required bool selected, required bool dark, String? label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected
                      ? AppColors.gold
                      : (dark ? Colors.white24 : Colors.black26),
                  width: selected ? 3 : 1)),
          child: color == null
              ? Icon(Icons.auto_awesome_rounded, size: 16,
                  color: dark ? Colors.white70 : Colors.black45)
              : null,
        ),
        if (label != null)
          Text(label, style: const TextStyle(fontSize: 9)),
      ]),
    );
  }
}
