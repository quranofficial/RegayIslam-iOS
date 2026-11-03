# ڕێگای ئیسلام — Flutter (RegayIslam v70.1)

ئەمە پرۆژەی **Flutter** ی ئەپە ڕەسەنەکەیە کە بە **Sketchware Pro** دروستکرابوو.
هەموو سکرێن، داتا و ئەرکەکان لە پڕۆژە ڕەسەنەکەوە وەرگیراون (`RegayIslam v70.1 (com.nwezhakanm, 71) 2026-09-20T153444.swb`).

---

## 🚀 چۆن ئەپەکە بنیاد بنێم (Build)؟

### هەنگاوی ١ — Flutter دابمەزرێنە
ئەگەر Flutter ـت نییە: لە [docs.flutter.dev](https://docs.flutter.dev/get-started/install) دایبەزێنە،
پاشان لە تێرمیناڵ:

```bash
flutter doctor
```

### هەنگاوی ٢ — فۆڵدەری پرۆژەکە بکەوە و platform ـەکان دروست بکە

```bash
cd regayislam
flutter create --org com.nwezhakanm --project-name regayislam --platforms android .
```

> ⚠️ ئەم فەرمانە هەموو شتێک دەهێڵێتەوە و تەنها `android/`، `ios/` و پێویستییەکان دروست دەکات.

### هەنگاوی ٣ — دەستپێکی Android Manifest

فایلی `android/app/src/main/AndroidManifest.xml` بکەوە و لەناو `<manifest>` ئەمانە زیاد بکە:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

لەناو `<activity>` ـی سەرەکی (MainActivity) `android:exported="true"` دڵنیابە.

### هەنگاوی ٤ — جێبەجێکردن

```bash
flutter pub get
flutter run
# یان بۆ APK:
flutter build apk --release
```

ئەگەر minSdk کێشەی هەبوو، لە `android/app/build.gradle` بیکە: `minSdk = 21`

---

## 📦 ناوەڕۆکی پاکێجەکە

| فۆڵدەر | ناوەڕۆک |
|---|---|
| `assets/db/` | ٧٥ داتابەیسی SQLite — قورئان + تەفسیرەکان (regayislam.db)، سوورەتەکان، ناوەکانی خودا، کاتەکانی نوێژی ٣٤ شار، کتێبی عەقیدە (mu.db)، ڕەمەزان، دوعاکان + ٦٥ داتابەیسی کاتی خوێندنەوە بۆ هەر قارئێرێک |
| `assets/data/` | ٢٧ فایلی JSON (فەرموودە، زیکرەکان، دوعا، پێغەمبەران...) + generated_static.json |
| `assets/images/` | ٢٩٣ وێنەی UI + ١٠١ ئایکۆنی سوورەتەکان |
| `assets/fonts/` | ٢١ فۆنتی کوردی/عەرەبی (Rabar، NRT، Quran...) |
| `assets/sounds/` | دەنگەکانی ئەپەکە |
| `lib/` | کۆدی Dart — ٣٩ فایل |

## 📱 سکرێنەکان کە جێبەجێ کراون (٦٠ سکرێنی ڕەسەن)

- **Splash** — ئامادەکاری داتابەیس + ئاگادارکردنەوەکان
- **Main** — BottomNav + ٤ تاب: سەرەتا / قورئان / تەسبیح / ڕێکخستن (هەمان ڕیزبەندی ڕەسەن)
- **Home** — بەنەری ڕەمەزان (Firebase)، پەخشی ڕاستەوخۆ، تەسبیح، کاتەکانی بانگی شار، ٣٦ کارتی تایبەتمەندی
- **قورئان**: لیستی سوورەت + گەڕان، خوێندنەوە بە ١٠ تەفسیر، دەنگی قورئان بە قارئەکان، ئایەتی ڕۆژ، ناوەکانی خودا (٤ زمان)
- **نوێژ**: هەب (١٨ کارت)، خشتەی مانگانە، ڕێکخستنی بانگ، دەستنوێژ، دوعاکانی نوێژ + ١٤ سکرێنی خوێندنەوە (فاتیحە، جەژن، بانگ، تەیەمموم...)
- **قیبلەنما** — قەپۆز ڕاستەقینە + بەرنامەسازکردنی گۆشەی قیبلە
- **تەسبیح** — لیست + ژمێرەر لەرینەوەدار
- **میدیا** — ڤیدیۆکان (Firebase)، پەخشی ڕاستەوخۆ
- **پرسیار و وەڵام (Quiz)** — لە Firebase وەردەگیرێت، ڕەنگی سەوز/سوور وەک ڕەسەنەکە
- **ڕەمەزان** — بەشەکان لە rm.db + بەنەری Firebase
- **کتێبخانە** — کتێبەکان (garanawa.db) + خوێنەری PDF
- **ڕێکخستن** — دۆخی شەو/ڕووناکی، فۆنتەکان، پەیوەندییەکان (فەیسبووک/تێلێگرام/تیکتاک)
- **پەیام و ڕەخنە + پرۆفایل** — دەنێردرێت بۆ Firebase

## 🔗 Firebase (بێ google-services.json!)

ئەپەکە ڕاستەوخۆ بە **Firebase REST API** قسە دەکات:
`https://regayislam-1-default-rtdb.firebaseio.com`

ڕێڕەوە بەکارهاتووەکان: `quiz`, `videoNew`, `videoall`, `Live`, `livemuslim`, `dialogg`, `ramadan`, `commentvideo`, `bandaccount`, `feedback`, `Verify`

> 💡 ئەگەر دەتەوێت بەڵام Base ـی خۆت دابنێیت: لە `lib/data/rtdb.dart` بیگۆڕە.

## ⚠️ جیاوازییەکان لەگەڵ ڕەسەنەکە

1. **ویجێتی سەر ماڵەوە (Home Widget)** — لە Flutter ناتوانرێت بە پاکێجی ئاسایی دروست بکرێت؛ پێویستی بە `home_widget` + کۆدی ڕەسەنی Kotlin هەیە. ئەگەر ویستت دەیکەم زیاد بکەم.
2. **FCM (پەیامی ناو ڕاستەوخۆ)** — ڕەسەنەکە Firebase Messaging ی بەکارهێناوە؛ لێرە ئاگادارکردنەوە خۆماڵییەکان بەکاردێن (پێویستی بە هیچ ئاکاونتێک نییە). ئەگەر FCM ـت ویست، `firebase_messaging` زیاد بکە و `google-services.json` دابنێ.
3. **دەنگی نوێژ** — کاتەکان لە داتابەیسی `time2.db` (٣٦٦ ڕۆژ × ٣٤ شار) دێن — هەمان داتای ڕەسەنەکە.

## 📝 مافی چاپ

ناوەڕۆکی ئیسلامی و وێنەکان مافی ئەپە ڕەسەنەکەیە (ڕێگای ئیسلام).

## 🍎 دروستکردنی Unsigned IPA بە GitHub Actions

فایلی `.github/workflows/ios-ipa.yml` لە macOS Runner ـدا ئەپەکە Build دەکات بەبێ Code Signing و ئەنجامەکە وەک Artifact پاشەکەوت دەکات.

### چۆنیەتی بەکارهێنان

1. ئەم فۆڵدەرەی پرۆژەکە Upload بکە بۆ GitHub Repository ـێکی تایبەتی (Private) یان گشتی.
2. لە GitHub → Actions، Workflow ـی **Build RegayIslam Unsigned iOS IPA** هەڵبژێرە.
3. **Run workflow** دابگرە.
4. کاتێک Build تەواو بوو، لە بەشی Artifacts، `RegayIslam-unsigned-IPA` دابەزێنە.

### گرنگ

- ئەم IPA ـە **Unsigned** ـە؛ واتە بێ Certificate و Provisioning Profile دروست دەکرێت.
- IPA ـی Unsigned بە شێوەی ئاسایی ڕاستەوخۆ لە iPhone دامەزرێنرێت نا. بۆ دامەزراندن پێویستە بە شێوەیەکی دروست Sign ـی بکرێتەوە.
- لەم workflow ـەدا هیچ Apple Developer Account یان GitHub Secret ـی Signing پێویست نییە.
- ئەم workflow ـە لە GitHub Actions جێبەجێ دەبێت؛ لەسەر ئەم ژینگەیەی گفتوگۆ Xcode/macOS بەردەست نییە، بۆیە IPA تا Run ـکردنی workflow دروست نابێت.
