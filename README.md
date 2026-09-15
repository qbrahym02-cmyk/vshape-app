# نظام V · V-System

تطبيق Flutter (أندرويد) مبني خصيصاً لخطة الـ ٦ أشهر: **قائمة مهام محددة مسبقاً + قسم ماء + قسم أكل + تمارين البيت (حقيبة وطاولة) + سجل تقدم** — وكل المحتوى قابل للتحديث **عن بُعد** بدون إعادة تثبيت التطبيق، والتطبيق نفسه يقدر **يحدّث نفسه** من داخل التطبيق.

---

## 1) التحميل والتركيب

1. خذ ملف `V-System-universal.apk` من صف [Releases](../../releases) (أو من مجلد `release/` لو بنيته بنفسك).
2. انقله للجوال وافتحه → **تثبيت**.
3. أول مرة: Android بيطلب إذن «التثبيت من مصادر غير معروفة» — اقبله.

> لو كان عندك نسخة قديمة موقّعة بمفتاح مختلف، احذفها أول ثم ثبّت الجديدة.

---

## 2) الأقسام

| التبويب | الوظيفة |
|---|---|
| **اليوم** | ٣ حلقات (مهام/ماء/بروتين) + روتين الساعة البيولوجية + تمرين اليوم |
| **الماء** | هدف ٣.٥–٤ لتر، عداد زجاجات، وجدول ٥ محطات (استيقاظ/مدرسة/غداء/تمرين/ليل) |
| **الطعام** | ٥ وجبات بمحتوياتها، عدّاد بروتين تلقائي (١٥٠ جم)، ملوك البروتين الرخيص، قائمة الممنوعات |
| **التمرين** | جدول الأسبوع كامل مع مربعات لكل مجموعة، شرح تنفيذ خطوة بخطوة، وقواعد Tempo والراحة |
| **المزيد** | التقدم (سجل قوة + قياسات + رسوم بيانية)، القواعد والتحذيرات، الإعدادات |

---

## 3) التحديث عن بُعد للمحتوى (بدون إعادة تثبيت) ⭐

كل النصوص والوجبات والتمارين وأهداف الماء وأوقات التنبيهات موجودة في ملف واحد:

```
content.json   (في جذر هذا المستودع)
```

**الخطوات:**

1. افتح <https://github.com/qbrahym02-cmyk/vshape-app/blob/main/content.json>
2. اضغط أيقونة القلم ✏️ (Edit this file).
3. عدّل ما تريد:
   - غيّر عدد مجموعات تمرين، أو أضف تمرين جديد.
   - بدّل وجبة أو أضف صنف.
   - غيّر `goal_ml` للماء أو أوقات التنبيهات في `reminders`.
   - **مهم:** ارفع `"version"` في أول الملف (مثلاً من `3` إلى `4`).
4. اضغط **Commit changes**.
5. في التطبيق: **الإعدادات ← مزامنة الآن**. انتهى ✅

التطبيق يزامن تلقائياً كل ٦ ساعات أيضاً، ويعمل **أوفلاين** على آخر نسخة محفوظة. لو صار خطأ في الـ JSON، التطبيق لا ينهار — يكمل على آخر نسخة سليمة.

### تغيير مصدر المحتوى
من **الإعدادات ← رابط ملف المحتوى** تقدر تحط أي رابط JSON:
- GitHub raw (الافتراضي)
- GitHub Pages: `https://qbrahym02-cmyk.github.io/vshape-app/content.json`
- Gist
- Google Drive (رابط المشاركة العادي — التطبيق يحوّله تلقائياً)
- أي سيرفر يرجّع JSON

### بنية `content.json` (ملخص)
```jsonc
{
  "version": 3,                  // ارفعه مع كل تعديل
  "updated_at": "2026-09-15",
  "app":     { "name": {"ar": "...", "en": "..."}, "profile": {...} },
  "water":   { "goal_ml": 3750, "glass_ml": 500, "slots": [ {id,time,glasses,title,why,remind} ] },
  "food":    { "protein_g_target": 150, "meals": [ {id,time,title,protein_g,kcal,items[],tip} ],
               "protein_sources": [...], "avoid": [...] },
  "workout": { "tempo_rule": {...}, "rest_rule": {...},
               "days": [ {id, day(1=Mon..7=Sun), emoji, title, focus, is_rest,
                          exercises:[{id,name,target,sets,reps,rest_s,tempo,steps[],note}],
                          rest_plan:[...] } ] },
  "routine": [ {id,time,emoji,title,detail,category} ],
  "backpack":{ "title": {...}, "rules": [...] },
  "progress":{ "kpis": [...], "strength_log": {"exercises":[...]}, "measurements": [...] },
  "rules":   [ {id,emoji,severity,title,text} ],
  "philosophy": [...],
  "reminders": { "water": ["06:32", ...], "workout": "17:25", "sleep": "22:30", "enabled": true }
}
```
كل نص يقبل الشكل `{"ar": "...", "en": "..."}` — عشان التطبيق ثنائي اللغة.

---

## 4) تحديث التطبيق نفسه (APK جديد) من داخل التطبيق ⭐

1. عدّل الكود وارفع `version:` في `pubspec.yaml` — مثال: `1.0.3+4`
   (الرقم بعد `+` هو **versionCode** وهو اللي يقارنه التطبيق).
2. `git commit -am "v1.0.3" && git tag v1.0.3+4 && git push origin main --tags`
3. GitHub Actions يبني APK موقّع وينشره في **Releases** تلقائياً (يشغّل التحليل والاختبارات أولاً).
   تُنشر أربعة ملفات: `universal` + نسخة لكل معالج (`arm64-v8a` ← الأصغر والأنسب لأغلب الجوالات).
4. التطبيق يفحص مرة كل ~٢٠ ساعة، ويظهر شريط أخضر «فيه نسخة جديدة» →
   **تنزيل وتثبيت** → يفتح مثبّت Android مباشرة. **بدون كمبيوتر وبدون حذف بياناتك.**

> أول مرة بيطلب Android إذن «تثبيت تطبيقات غير معروفة» — التطبيق يفتح لك الشاشة بنفسه.

### البناء اليدوي (بدون Actions)
في GitHub: **Actions ← Build & publish APK ← Run workflow**.
أو على جهازك: انظر `BUILD.md`.

---

## 5) البناء على جهازك

```bash
flutter pub get
flutter build apk --release
# الناتج: build/app/outputs/flutter-apk/app-release.apk
```

**المتطلبات:** Flutter 3.47+ · JDK 17 · Android SDK 35 · ذاكرة 4 جيجا أو أكثر.
`local.properties` يُنشأ تلقائياً، أو أنشئه يدوياً:
```
sdk.dir=/path/to/android-sdk
flutter.sdk=/path/to/flutter
```

### التوقيع
المفتاح موجود في `android/keystore/vsystem-release.jks` وكلمة المرور في `android/key.properties`
(مرفوعان عمداً حتى تقدر تبني من أي مكان). **احتفظ بنسخة منهما**: لو ضاع المفتاح، ما تقدر تحدّث التطبيق فوق النسخة المثبتة — المستخدم سيضطر للحذف وإعادة التثبيت.

لإخفاء المفتاح عن العام: احذف الملفين من المستودع وضف بدلاً منهما Secrets في GitHub:
`ANDROID_KEYSTORE_BASE64` (ملف jks بترميز base64) · `KEYSTORE_PASSWORD` · `KEY_ALIAS` · `KEY_PASSWORD`.

---

## 6) بنية المشروع

```
lib/
  main.dart                     الإقلاع + المزامنة الخلفية
  app.dart                      MaterialApp + الثيم + الاتجاه RTL
  core/
    models.dart                 نماذج محتوى content.json (تتحمل الحقول الناقصة)
    app_state.dart              الحالة + التخزين المحلي (shared_preferences)
    native_bridge.dart          جسر Kotlin: التنبيهات، التثبيت، معلومات النسخة
    l10n.dart                   نصوص الواجهة (عربي/إنجليزي)
    theme.dart                  الألوان والخطوط
  services/
    content_service.dart        جلب المحتوى + قراءة إصدارات GitHub
    update_controller.dart      منطق فحص/تنزيل/تثبيت التحديث
  screens/                      اليوم · الماء · الطعام · التمرين · المزيد · التقدم · القواعد · الإعدادات
  widgets/                      بطاقات وحلقات تقدم ورسوم بيانية
android/app/src/main/kotlin/    MainActivity · Alarms · AlarmReceiver · BootReceiver
assets/content/content.json     النسخة المدمجة (تعمل بدون إنترنت)
```

**لا توجد إضافات ثقيلة:** `dio` · `shared_preferences` · `path_provider` · `url_launcher` فقط.
التنبيهات اليومية مكتوبة يدوياً بـ `AlarmManager` (بدون `flutter_local_notifications`) حتى يبقى البناء خفيفاً.

---

## 7) ملاحظة طبية سريعة
الخطة مبنية لشاب عمره ١٥ وطوله ١٨٥–١٩٠ ووزنه ٨٠–٨٥ كغ. أي ألم حاد في المفصل أو الظهر = توقف فوراً.
التقدم الحقيقي يبدأ بصرياً من الشهر الثالث، والنوم قبل ١١ مساءً جزء من التمرين وليس رفاهية.
