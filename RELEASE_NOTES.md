# 🆕 وش الجديد في 1.2.0

هذا التحديث **يصل لكل المستخدمين القدامى** — حتى اللي على إصدارات 1.0.2 و1.0.3 اللي ما كان يظهر عندهم شريط التحديث أبداً. تركّب فوق نسختك الحالية وبياناتك محفوظة.

## 🔄 المُحدِّث نفسه انصلح
- **كل الأجهزة تشوف التحديثات الآن**: النسخ القديمة كانت تحسب رقم الإصدار غلط، فمستخدمو 1.0.2/1.0.3 ما كان يوصلهم إشعار أبداً، ومستخدمو النسخة الشاملة (universal) كان يشوفون «فيه نسخة جديدة» حتى وهم على آخر إصدار. الاتنين انصلحوا من الجذر.
- **التحميل يتحقق بالبصمة (SHA-256)**: لو انقطع النت أو صار خلل في التنزيل، التطبيق يحذف الملف المعطوب ويعيد المحاولة — بدل ما يفشل المثبّت برسالة غامضة.
- **ما يركّب ملف قديم بالغلط**: لو نزّلت نسخة وما ثبّتها، ثم طلعت نسخة أحدث، التطبيق يتخلص من الملف القديم تلقائياً.
- **الشريط الأخضر يفتح بطاقة التحديث مباشرة** في الإعدادات — ما عاد تحتاج تدوّر عليها.

## 🧩 تحسينات الودجت
- الودجت اللي تضيفه بعد فتح التطبيق يتحدث فوراً مع أول تفاعل (كان يعرض أرقام قديمة حتى تعيد تشغيل التطبيق).
- وحدة البروتين «جم» ورا الرقم، و«راحة» في يوم الراحة — كانوا يطلعون فاضيين.
- تحديث دوري كل ٣٠ دقيقة حتى لو التطبيق مقفول.

## 🛠️ إصلاحات دقيقة
- رسالة «تم تسجيل الإنجاز» صارت صح (كانت تنعكس: تسجيل يظهر كإلغاء والإلغاء كتسجيل).
- تنبيه «خلصت الراحة» صار بلغة التطبيق (كان عربي دائماً حتى للواجهة الإنجليزية).
- محتوى `content.json` فيه عنصر غلط؟ التطبيق يتجاهل العنصر المعطوب ويكمل — بدل ما يرفق الملف كله.
- سهم بطاقة التمرين يشاور الاتجاه الصحيح في الواجهتين.

## 🧪 تحت الغطاء
- قناة `buildFlavor` الجديدة تقرأ نوع الملف المثبّت (شامل أو لمعالج واحد) من داخل الـ APK نفسه — فمقارنة الإصدارات صارت قطعية بلا تخمين.
- رقم الإصدار قفز إلى **5000** عمداً: النسخ القديمة (1.0.2–1.1.0) تطرح إزاحة المعالج من الرقم، فأي رقم صغير ما كان يبين لها أبداً — 5000 يتجاوز هذا العائق لكل المعالجات.
- المجموع **120** اختباراً، منها 16 اختبار انحدار يثبتون أن كل نسخة منشورة سابقاً (1.0.2 → 1.1.0، على كل المعالجات) تشوف هذا التحديث.

> بياناتك محفوظة — التحديث يركّب فوق النسخة الحالية.

---

# 🆕 What's new in 1.2.0

This update **reaches every legacy install** - including 1.0.2/1.0.3 users who never saw the update strip. It installs over your current build and keeps your data.

## 🔄 The updater itself is fixed
- **Every device now sees updates**: old versions mis-computed the version code, so 1.0.2/1.0.3 users were never offered anything, and universal-APK users saw "new version" even when up to date. Both are fixed at the root.
- **Downloads are SHA-256 verified**: a truncated or corrupted file is deleted and reported instead of failing later inside the installer with a cryptic message.
- **No stale installs**: if you downloaded an update but never installed it and a newer one shipped, the old file is dropped automatically.
- **The green strip opens the update card directly** in Settings - no more hunting for it.

## 🧩 Widget improvements
- A widget added after launching the app now updates on the very next tap (it used to show stale numbers until an app restart).
- The protein unit "g" and the rest-day "rest" label no longer render blank.
- The widget refreshes at least every 30 minutes even with the app closed.

## 🛠️ Small fixes
- The "session marked complete" message is no longer inverted.
- The "rest is over" notification follows the app language instead of always Arabic.
- A malformed element in `content.json` is skipped instead of rejecting the whole file.
- The workout card chevron points the right way in both layouts.

## 🧪 Under the hood
- A new `buildFlavor` channel reads the installed APK's own `lib/` folders (universal vs single-ABI), making version comparison deterministic.
- The version code deliberately jumps to **5000**: legacy builds subtract the ABI offset from it, so a small number could never look newer to them - 5000 clears that bar on every ABI.
- **120 tests** total, including 16 regression tests proving every previously published build (1.0.2 -> 1.1.0, every ABI) is offered this update.

> Your data is kept - the update installs over the current build.
