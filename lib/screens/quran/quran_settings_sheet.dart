import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/prefs.dart';

/// Original: quranview2.xml — Quran reader settings (tafsir, fonts, size).
void showQuranSettingsSheet(BuildContext context, VoidCallback onChange) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppPrefs.I.day ? Colors.white : AppColors.nightCard,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return StatefulBuilder(builder: (context, setSheet) {
        final p = AppPrefs.I;
        final txt = p.day ? Colors.black : Colors.white;
        Widget section(String title) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, color: txt)));

        Widget tafsirChip(String key) {
          final sel = p.tafsir == key;
          return ChoiceChip(
              label: Text(kTafsirNames[key] ?? key),
              selected: sel,
              selectedColor: AppColors.primaryDark,
              labelStyle: TextStyle(
                  color: sel ? Colors.white : txt, fontSize: 12),
              onSelected: (_) => setSheet(() { p.tafsir = key; onChange(); }));
        }

        Widget fontChip(List<String> fonts, String current, String group) {
          return ChoiceChip(
              label: Text(group == 'quran' ? 'نمونە' : 'فۆنت',
                  style: TextStyle(fontSize: 12,
                      fontFamily: fonts.first,
                      color: current == fonts.first ? Colors.white : txt)),
              selected: current == fonts.first,
              selectedColor: AppColors.primaryDark,
              onSelected: (_) => setSheet(() {
                    if (group == 'quran') { p.fontQuran = fonts.first; }
                    else { p.fontUi = fonts.first; }
                    onChange();
                  }));
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              Center(child: Container(width: 42, height: 4,
                  decoration: BoxDecoration(color: Colors.grey,
                      borderRadius: BorderRadius.circular(4)))),
              section('تەفسیر'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in kTafsirs) tafsirChip(t),
              ]),
              section('قەبارەی نووسینی قورئان'),
              Row(children: [
                IconButton(
                    onPressed: () => setSheet(() {
                          p.quranFontSize =
                              (p.quranFontSize - 2).clamp(14, 60); onChange();
                        }),
                    icon: const Icon(Icons.remove_circle_outline_rounded)),
                Expanded(child: Slider(
                    value: p.quranFontSize.toDouble(),
                    min: 14, max: 60, divisions: 23,
                    activeColor: AppColors.primaryDark,
                    label: '${p.quranFontSize}',
                    onChanged: (v) =>
                        setSheet(() { p.quranFontSize = v.round(); onChange(); }))),
                IconButton(
                    onPressed: () => setSheet(() {
                          p.quranFontSize =
                              (p.quranFontSize + 2).clamp(14, 60); onChange();
                        }),
                    icon: const Icon(Icons.add_circle_outline_rounded)),
              ]),
              section('فۆنتی قورئان'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final f in kFontsQuran)
                  fontChip([f], p.fontQuran, 'quran'),
              ]),
              section('فۆنتی ئەپ'),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final f in kFontsUi) fontChip([f], p.fontUi, 'ui'),
              ]),
              const SizedBox(height: 12),
            ]),
          ),
        );
      });
    },
  );
}
