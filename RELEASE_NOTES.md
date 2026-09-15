# 🆕 وش الجديد في 1.0.3

## ⏱️ مؤقّت راحة حقيقي
اضغط على «٩٠ ث راحة» في أي تمرين → يبدأ عدّ تنازلي دائري، يشتغل حتى لو غيّرت التبويب.
فيه **+30 ثانية**، **إيقاف مؤقت**، **تخطي** — وعند النهاية اهتزاز + صوت + تنبيه، عشان تعرف وأنت ممدّد على الأرض أن الراحة خلصت.

## 🔥 عدّاد الأيام المتتالية صار صادقاً
قبل: لو عبّيت ماءك من **محطات الجدول** بدل زر «إضافة سريعة»، اليوم ما كان يُحسب — فينكسر العدّاد رغم أنك شربت ٣.٧٥ لتر.
الحين: أي طريقة تعبئة تُحسب، واليوم ما ينكسر.

## ⚙️ الإعدادات تعرض الحقيقة
قسم التنبيهات صار يعرض الأوقات التي **ستدق فعلاً** (من محطات الجدول + الأوقات الزائدة)، بدل قائمة `reminders.water` وحدها.

## 🔐 أمان
كلمة مرور مفتاح التوقيع كانت مكتوبة نصّاً في `BUILD.md` داخل مستودع عام — انحذفت، والوثائق توضح أن المفتاح في Secrets فقط.

## 🔔 تنبيهات الماء تتبع الملف فعلاً
علامة `"remind": false` لأي محطة في `content.json` صارت تُحترم — قبل كان التطبيق يتجاهلها وينبّهك على كل المحطات.
والتنبيه صار يعيد جدولة نفسه **بنفس الدقة** كل يوم (قبل: من اليوم الثاني يبدأ يتأخر بسبب وضع Doze).

## 📦 التحديث صار يوصلك فعلاً
الشريط الأخضر «فيه نسخة جديدة» يرجع في كل تشغيل حتى تحدّث — قبل كان يظهر **مرة واحدة** في العمر، وإذا ما ضغطت عليه ما رجع.
وصار يفحص أسرع (كل ~٦ ساعات) لما ما يكون فيه تحديث معلّق.

---

# 🆕 What's new in 1.0.3

## ⏱️ A real rest timer
Tap the “90 s rest” chip on any exercise → a circular countdown starts and keeps running across tabs, with **+30 s**, **pause** and **skip**. When it ends you get a vibration, a sound and a notification, so you know the rest is over even lying on the floor.

## 🔥 The streak counter is honest now
Filling your water through the **schedule stations** instead of the quick-add buttons used to break the streak even though you drank all 3.75 L. Both paths count now.

## ⚙️ Settings tell the truth
The reminders row now lists the times that will **actually ring** (schedule stations + extra times) instead of only `reminders.water`.

## 🔐 Security
The keystore password was written in plain text inside `BUILD.md` in a public repo. It is gone, and the docs now state the key lives only in Actions secrets.

## 🔔 Water reminders follow the content file
`"remind": false` on a station in `content.json` is honoured (it used to be ignored), and each reminder re-arms itself **with the same exactness** daily instead of drifting later under Doze.

## 📦 Updates actually reach you
The green “new version available” strip comes back on every launch until you update — it used to appear once and never again. Checks also run sooner (~6 h) when nothing is pending.
