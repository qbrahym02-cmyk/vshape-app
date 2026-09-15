# 🚨 1.0.4 — إصلاح مهم: التحديث من داخل التطبيق

## 📦 التحديث صار يوصل فعلاً
في النسخ السابقة كان التطبيق يقرأ رقم النسخة من `version.json` (مثلاً `4`) ثم **يطرح منه إزاحة المعالج** (٢٠٠٠ لـ arm64) فيصبح `-1996` — والنتيجة: **الشريط الأخضر لا يظهر أبداً**، وما يصلك أي تحديث مستقبلي من داخل التطبيق.
الحين الرقم القادم من `version.json` (أو من التاج) يُعتبر رقم أساس ولا تُطرح منه الإزاحة. الإزاحة تُطرح فقط من الرقم المثبّت على الجوال.

> ⚠️ **لمرة واحدة فقط:** النسخة المثبتة عندك (1.0.2) فيها هذا الخلل، لذلك **ثبّت 1.0.4 يدوياً** من رابط التنزيل. بعدها كل التحديثات توصلك من داخل التطبيق بضغطة.

---

# ⏱️ وهذه مزايا 1.0.3 (مضمّنة هنا)

## مؤقّت راحة حقيقي
اضغط على «٩٠ ث راحة» في أي تمرين → عدّ تنازلي دائري فوق شريط التنقّل، يشتغل حتى لو غيّرت التبويب.
`+30 ثانية` · إيقاف مؤقت · تخطي — وعند النهاية اهتزاز + صوت + تنبيه.

## 🔥 عدّاد الأيام المتتالية صار صادقاً
لو عبّيت ماءك من **محطات الجدول** بدل زر «إضافة سريعة»، اليوم ما كان يُحسب — فينكسر العدّاد رغم أنك شربت ٣.٧٥ لتر. الحين أي طريقة تُحسب.

## 🔔 التنبيهات تتبع ملف المحتوى فعلاً
`"remind": false` لأي محطة في `content.json` صارت تُحترم (كانت تُتجاهل)، والتنبيه يعيد جدولة نفسه **بنفس الدقة** كل يوم بدل أن يتأخر تدريجياً مع وضع Doze.
وشاشة الإعدادات صارت تعرض الأوقات التي **ستدق فعلاً**.

## 🔐 أمان
كلمة مرور مفتاح التوقيع كانت مكتوبة نصّاً في `BUILD.md` داخل مستودع عام — انحذفت، والوثائق توضح أن المفتاح في أسرار Actions فقط. وCI صار **يفشل عمداً** لو ما لقى مادة توقيع، بدل نشر APK بمفتاح debug.

---

# 🚨 1.0.4 — the important one: in-app updates

## 📦 Updates actually arrive now
Previous builds read the version number from `version.json` (e.g. `4`) and then **subtracted the ABI offset** (2000 for arm64), producing `-1996` — so the green strip never appeared and no future update could ever be offered in-app.
A code that comes from `version.json` (or from a tag) is now treated as the base code; the offset is only stripped from the code installed on the device.

> ⚠️ **One time only:** the build on your phone (1.0.2) has this bug, so **install 1.0.4 manually** from the download link. Every update after that arrives from inside the app.

---

# ⏱️ Plus everything from 1.0.3

**A real rest timer** — tap the “90 s rest” chip for a circular countdown parked above the nav bar (survives tab switches), with +30 s / pause / skip and vibration + sound + notification when it ends.

**Honest streaks** — water logged through the schedule stations used not to count, breaking the streak even at a full 3.75 L. Both paths count now.

**Reminders follow the content file** — `"remind": false` on a station is honoured, each reminder re-arms with the same exactness daily instead of drifting under Doze, and Settings lists the times that really ring.

**Security** — the keystore password was in plain text in `BUILD.md` in a public repo; it is removed, and CI now fails instead of shipping a debug-signed APK.
