# 🆕 وش الجديد في 1.1.0

نفس خطتك بالظبط — نفس الطعام والتمارين والمواعيد — لكن بأدوات تخلّي الالتزام أسهل، والميزانية أذكى، والسلامة مضمونة.

## 📅 تقرير الأسبوع
رقم واحد صريح: نسبة التزامك في آخر ٧ أيام عبر ٥ خانات (ماء · بروتين · روتين · تمرين · نوم)، ومقارنتها بالأسبوع اللي قبله، وتحديد **أضعف خانة** تركّز عليها الأسبوع الجاي. من «المزيد ← تقرير الأسبوع».

## 🎓 وضع الامتحانات
الدراسة أولاً. مفتاح واحد في الإعدادات يخفض الأسبوع إلى **٣ جلسات** (السبت دفع · الأحد سحب · الاثنين أرجل) — وهي أهم ٣ جلسات لبناء الـ V. بقية الأيام تبهت في الجدول ولا تُحسب ضدك في التقرير، ومعاها ٥ قواعد للأسبوع المخفّف.

## 😴 نوم النمو
٨٠٪ من هرمون النمو يُفرز بين ١١ مساءً و٢ فجراً. سجّل ساعة نومك كل صباح بضغطة واحدة (٢٢:١٥ / ٢٢:٤٥ / ٢٣:٠٠ / ٢٣:٣٠ / ٠٠:٣٠ أو وقت حر) — والتطبيق يحسب **سلسلة النوم** 🔥 ويقول لك بكم دقيقة تأخرت. النوم بعد منتصف الليل يُحسب متأخراً.

## 🌡️ تقييم اليوم
٣٠ ثانية قبل التمرين: من «🚀 جاهز تماماً» إلى «🤒 مرهق/مريض». التطبيق يقول لك بالضبط كم مجموعة تحذف اليوم، ولو نزل تقييمك يومين ورا بعض يقترح **أسبوع تخفيف (Deload)** بدل ما تتصاب.

## 💰 حاسبة سعر البروتين
اكتب سعر كل مصدر في منطقتك مرة واحدة (بيضة، ١٠٠ جم عدس، لتر حليب…). التطبيق:
- يرتّب المصادر من **الأرخص للأغلى** حسب ثمن كل **٢٠ جم بروتين**؛
- يبني **أرخص سلة** تصل لهدف ١٥٠ جم بحدود يومية واقعية (٦ بيضات، ٢ لتر حليب، ٣٠٠ جم قريش)؛
- يقول لك بصراحة لو أسعارك ما توصلش للهدف.
رمز العملة يتغيّر من نفس البطاقة (ج.م، ر.س، €…).

## ⚖️ حاسبة وزن الحقيبة
كم قارورة؟ ماء ولا رمل؟ الحاسبة تعطيك الوزن الكلي فوراً (الرمل ١.٦ كجم/لتر مقابل ١.٠ للماء)، و**المدى الآمن لجسمك** (١٠–٢٠٪ من وزنك)، وحكم: خفيف / مناسب / ثقيل — مع خطوات التعبئة الخمسة.

## 🛡️ بوابة أمان طاولة السفرة
قبل أول تجديف طاولة تظهر **٩ خطوات لتأمين الطاولة ١٠٠٪**: نوع الطاولة، اختبار الوزن الكامل ٣ مرات، الحائط، الأرض، القبضة، تثبيت إضافي، وضعية الجسم، مساعد في أول أسبوع، و٣ تكرارات اختبار. إقرار واحد يُحفظ، والبطاقة تفضل خضراء للمراجعة.

## 📸 صورة يوم ١٥ + فحوصات الشهر
تذكير بالصورة الشهرية من يوم ١٥ مع checklist (نفس الإضاءة، نفس الوقت، ٣ لقطات، نفس الملابس، بلا شفط بطن)، و٤ فحوصات شهرية تُعلَّم لكل شهر على حدة: صورة · ملابس · قياسات · أقصى تكرارات.

## 🏆 لحظة الرقم القياسي
أي رقم أفضل في سجل القوة يفتح احتفالاً حقيقياً — لأنه الدليل الوحيد على البناء العضلي بلا ميزان ولا مقاس خصر.

## 🧪 تحت الغطاء
- كل الحسابات في `lib/core/plan_math.dart` (بلا أي اعتماد على Flutter) + **٤٢ اختباراً جديداً** — المجموع **١٠٤** اختبارات.
- المحتوى **v5**: كل الأقسام الجديدة تُقرأ من `content.json`، ومحتوى v4 القديم يخفي الميزات بدل ما يكسر التطبيق.
- CI: `flutter test --concurrency=2` — ما فيش اختبارات تتسابق بعد كدا.

> بياناتك محفوظة — التحديث يركّب فوق النسخة الحالية.

---

# 🆕 What's new in 1.1.0

Same plan - same food, same exercises, same clock - with new tools that make adherence easier, the budget smarter and the setup safer.

## 📅 Weekly report
One honest number: your adherence over the last 7 days across 5 columns (water · protein · routine · training · sleep), compared with the previous week, plus the **weakest column** to fix next.

## 🎓 Exam mode
Study first. One switch cuts the week to **3 sessions** (Sat push · Sun pull · Mon legs) - the three that build the V. Dropped days fade out and are never counted against you.

## 😴 Growth sleep
80% of growth hormone is released between 11 PM and 2 AM. Log your bedtime in one tap; the app keeps a **sleep streak** 🔥 and tells you how many minutes late you were. After midnight counts as late.

## 🌡️ Daily check-in
From "🚀 fully ready" to "🤒 ill". The app tells you exactly how many sets to drop, and two low days in a row trigger a **deload** suggestion instead of an injury.

## 💰 Protein price calculator
Price each source once. The app ranks them by the **cost of 20 g of protein**, builds the **cheapest basket** that reaches 150 g within realistic daily caps, and tells you honestly if your prices cannot get there. The currency symbol is editable.

## ⚖️ Backpack load calculator
Bottles + sand or water -> total kilos (sand is 1.6 kg/L versus 1.0 for water), your **safe window** (10-20% of bodyweight) and a verdict: light / good / heavy.

## 🛡️ Table-row safety gate
Before your first table row: a **9-step checklist** to secure the table 100%, acknowledged once and kept green for review.

## 📸 Photo on the 15th + monthly checks
A monthly photo reminder from the 15th with the same-light checklist, plus 4 monthly ticks stored per month.

## 🏆 Personal-record moment
A better number in the strength log now gets a celebration - the only proof of growth that needs no scale.

## 🧪 Under the hood
All the maths lives in `lib/core/plan_math.dart` (no Flutter dependency) with **42 new tests** (104 total). Content is **v5**; old v4 content hides the new features instead of breaking. CI now runs `flutter test --concurrency=2`.

> Your data is kept - the update installs over the current build.
