# GitHub Actions فایلەکان (Workflow)

تۆکنی ئێستا ڕێگە بە نوێکردنەوەی فایلی `.github/workflows/` نادات، بۆیە ئەم دوو فایلە لێرە دانراون:

- `android-apk.yml.txt` — دروستکردنی **APK** بە خۆکاری لەگەڵ هەر push ـێک (بۆیە APK هەمیشە ٢٤/٧ بەردەستە بە خۆڕایی).
- `web-site.yml.txt` — **وێبسایت** (Flutter Web) هەر push ـێک دووبارە دروست دەکات و ناو `docs/` نوێ دەکاتەوە بۆ GitHub Pages.

## چۆن چالاکی بکەیت (٢ خولەک)

1. لە GitHub بە وێبگەڕەکەت بکەوە ناو ئەم ریپۆکە.
2. فایلی `_workflows/android-apk.yml.txt` بکەرەوە → دەقەکە کۆپی بکە.
3. بڕۆ بۆ `.github/workflows/` → **Add file → Create new file** → ناوی فایل بنووسە `android-apk.yml` → دەقەکە پەیست بکە → **Commit**.
4. هەمان شت بۆ `web-site.yml` بکە (ناوەکەی `web-site.yml` بێت).
5. بۆ وێبسایت: **Settings → Pages → Source: Deploy from a branch → Branch: main، فۆڵدەر: /docs → Save**.
6. بۆ iOS: فایلی ئێستای `ios-ipa.yml` بە دستی لە Actions ـەوە Run بکە (IPA ـی Unsigned دەدات).

پاشان هەر push ـێک APK و وێبسایت بە خۆکاری نوێ دەکاتەوە.
