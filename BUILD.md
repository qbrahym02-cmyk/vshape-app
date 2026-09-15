# بناء الـ APK

## الطريقة الأسهل: GitHub Actions (سحابي، بدون تثبيت أي شيء)

1. افتح مستودع `vshape-app` على GitHub.
2. تبويب **Actions** ← **Build & publish APK** ← **Run workflow** ← **Run**.
3. انتظر ٥–٨ دقائق (أول مرة أطول).
4. حمّل `V-System-universal.apk` من:
   - قسم **Artifacts** في نفس التشغيل، أو
   - **Releases** (لو فعّلت `publish_release`) — وهذا ما يقرأه محدّث التطبيق.

> لو ظهر تحذير «Workflows aren't being run»، اضغط **I understand my workflows, go ahead and run them**.

---

## الطريقة الثانية: على جهازك

### المتطلبات
| الأداة | النسخة |
|---|---|
| Flutter SDK | 3.47 أو أحدث (Dart 3.13+) |
| JDK | 17 |
| Android SDK | platform 35 + build-tools 35.0.0 |
| الذاكرة | 4 جيجا أو أكثر |

### الخطوات
```bash
git clone https://github.com/qbrahym02-cmyk/vshape-app.git
cd vshape_app

flutter doctor          # تأكد أن Android toolchain ✓
flutter pub get
flutter test            # اختبارات سريعة على ملف المحتوى
flutter build apk --release
```

الناتج:
```
build/app/outputs/flutter-apk/app-release.apk
```

### APK أصغر لكل معالج (اختياري)
```bash
flutter build apk --release --split-per-abi
# app-arm64-v8a-release.apk  ← للجوالات الحديثة (الأغلب)
# app-armeabi-v7a-release.apk ← للجوالات القديمة
```

### سكريبت جاهز
```bash
./tool/build_apk.sh          # يبني release وينسخه إلى release/V-System-universal.apk
```

---

## إصدار جديد (تحديث يصل للجوال من داخل التطبيق)

```bash
# 1) عدّل pubspec.yaml
version: 1.0.3+4          # الاسم 1.0.3 ورقم النسخة 4 (لازم يزيد)

# 2) ارفع ونشر
git commit -am "release 1.0.3"
git tag v1.0.3+4
git push origin main --tags
```

Actions يبني وينشر Release فيه:
- `V-System-universal.apk`
- `version.json` → `{"versionName":"1.0.3","versionCode":4,...}`
- `checksums.sha256`

التطبيق يفحص `releases/latest` كل ~٢٠ ساعة، ويقارن `versionCode`، ويعرض
**تنزيل وتثبيت** إذا فيه نسخة أحدث. ويختار تلقائياً الـ APK المطابق لمعالج الجوال
(`arm64-v8a` مثلاً) بدلاً من النسخة العامة الأكبر.

> **تنبيه versionCode:** عند استخدام `--split-per-abi` تضيف Flutter إزاحة للمعالج
> (armeabi-v7a +1000، arm64-v8a +2000، x86_64 +3000). لذلك نسخة arm64 من `1.0.2+3`
> تحمل versionCode = 2003. التطبيق يطبّع الرقم (يطرح الإزاحة) قبل المقارنة.

> **مهم:** `versionCode` لازم يزيد في كل إصدار، وإلا التطبيق ما يشوف التحديث.

---

## التوقيع

المفتاح مرفوع في `android/keystore/vsystem-release.jks` مع `android/key.properties`:

```
storePassword=Vshape2026System
keyPassword=Vshape2026System
keyAlias=vsystem
storeFile=keystore/vsystem-release.jks
```

- **احفظ نسخة احتياطية من الملفين.** بدون نفس المفتاح لا يمكن التحديث فوق النسخة المثبتة.
- لو `key.properties` غير موجود، البناء يستخدم مفتاح debug تلقائياً (لن يفشل البناء).
- لإخفاء المفتاف: احذف الملفين من المستودع وأضف Secrets:
  `ANDROID_KEYSTORE_BASE64` · `KEYSTORE_PASSWORD` · `KEY_ALIAS` · `KEY_PASSWORD`.

---

## البناء على جهاز ضعيف (١–٢ جيجا رام)

الملف `android/gradle.properties` مضبوط على قيم عادية (٢.٥ جيجا) لأن CI يحتاجها.
على جهاز ضعيف استبدل القسم الأول بهذا:

```properties
org.gradle.jvmargs=-Xmx512m -XX:MaxMetaspaceSize=256m -XX:ReservedCodeCacheSize=64m -XX:+UseSerialGC -Dfile.encoding=UTF-8
org.gradle.parallel=false
org.gradle.caching=false
org.gradle.workers.max=1
kotlin.compiler.execution.strategy=in-process
kotlin.daemon.useFallbackStrategy=true
```

> جرّبت البناء داخل مساحة عمل بذاكرة ١ جيجا فقط: نظام التشغيل يقتل Gradle (OOM).
> لذلك **GitHub Actions هو الخيار المضمون** — ٧ جيجا رام، مجاني، ويبني في ~٦ دقائق.

---

## استكشاف الأخطاء

| المشكلة | الحل |
|---|---|
| `Gradle build daemon disappeared` | ذاكرة غير كافية → استخدم Actions، أو أغلق البرامج وزد `org.gradle.jvmargs` |
| `SDK location not found` | أنشئ `android/local.properties` فيه `sdk.dir=` و `flutter.sdk=` |
| `Member not found: 'arm64e'` | موجود `dependency_overrides: objective_c: 9.3.0` في pubspec — لا تحذفه |
| التطبيق لا يثبّت التحديث | فعّل «مصادر غير معروفة» للتطبيق، وتأكد أن التوقيع نفس المفتاح |
| المحتوى لا يتحدث | تأكد أنك رفعت `version` في `content.json`، وأن الرابط يرجّع JSON صحيح (`Settings → Sync now` يعرض الخطأ) |
