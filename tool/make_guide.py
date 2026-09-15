# -*- coding: utf-8 -*-
"""Generates the full user guide (دليل نظام V) straight from content.json."""
import json, io

c = json.load(io.open('content.json', encoding='utf-8'))
w, f, wk = c['water'], c['food'], c['workout']
days = sorted(wk['days'], key=lambda d: d['day'])
names = {1: 'الاثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس',
         5: 'الجمعة', 6: 'السبت', 7: 'الأحد'}

L = []
A = L.append

A("# 📖 دليل نظام V الكامل")
A("")
A("> مولّد مباشرة من `content.json` (نسخة المحتوى **v%s** · %s) — أي تعديل ترفعه على"
  % (c['version'], c['updated_at']))
A("> GitHub ينعكس هنا وفي التطبيق بدون إعادة تثبيت.")
A("")
A("**%s** — %s" % (c['app']['name']['ar'], c['app']['tagline']['ar']))
p = c['app'].get('profile', {})
if p:
    A("")
    A("| الملف | |")
    A("|---|---|")
    A("| العمر | %s |" % p.get('age'))
    A("| الطول | %s–%s سم |" % (p.get('height_cm', [0, 0])[0], p.get('height_cm', [0, 0])[1]))
    A("| الوزن | %s–%s كغ |" % (p.get('weight_kg', [0, 0])[0], p.get('weight_kg', [0, 0])[1]))
    A("| الهدف | %s |" % p.get('goal', {}).get('ar', ''))
A("")
A("---")
A("")
A("## 🕐 الروتين اليومي (الساعة البيولوجية)")
A("")
A("| الوقت | | البند | التفصيل |")
A("|---|---|---|---|")
for r in c['routine']:
    A("| `%s` | %s | **%s** | %s |" % (r['time'], r['emoji'], r['title']['ar'], r['detail']['ar']))
A("")
A("---")
A("")
A("## 💧 الماء")
A("")
A("**الهدف: %.2f لتر يومياً** (%d مل) · الكوب = %d مل · المدى المقبول %d–%d مل"
  % (w['goal_ml'] / 1000, w['goal_ml'], w['glass_ml'], w.get('min_ml', 0), w.get('max_ml', 0)))
A("")
A("> %s" % w.get('note', {}).get('ar', ''))
A("")
A("| # | الوقت | المحطة | أكواب | المللي | لماذا |")
A("|---|---|---|---|---|---|")
for i, s in enumerate(w['slots'], 1):
    A("| %d | `%s` | **%s** | %d | %d | %s |"
      % (i, s['time'], s['title']['ar'], s['glasses'], s['glasses'] * w['glass_ml'], s['why']['ar']))
tot = sum(s['glasses'] for s in w['slots'])
A("| | | **المجموع** | **%d** | **%d مل** | |" % (tot, tot * w['glass_ml']))
A("")
A("**تنبيهات الماء:** %s" % ' · '.join('`%s`' % t for t in c['reminders']['water']))
A("")
A("---")
A("")
A("## 🍽️ الطعام")
A("")
A("**الهدف: %d جم بروتين · %d–%d سعرة**" % (f['protein_g_target'], f['kcal_target'][0], f['kcal_target'][1]))
A("")
A("> 💡 %s" % f['budget_rule']['ar'])
A("")
for m in f['meals']:
    A("### %s · %s" % (m['time'], m['title']['ar']))
    if m.get('subtitle', {}).get('ar'):
        A("*%s*" % m['subtitle']['ar'])
    A("")
    A("**%d جم بروتين · %d سعرة**" % (m['protein_g'], m['kcal']))
    A("")
    A("| ✓ | الصنف | الكمية | بروتين | سعرات |")
    A("|---|---|---|---|---|")
    for it in m['items']:
        pg = it.get('protein_g')
        kc = it.get('kcal')
        A("| ☐ | %s | %s | %s | %s |"
          % (it['name']['ar'], it.get('qty', '1'),
             ('%d جم' % pg) if pg is not None else '—',
             ('%d' % kc) if kc is not None else '—'))
    if m.get('tip', {}).get('ar'):
        A("")
        A("> 💡 %s" % m['tip']['ar'])
    A("")
tp = sum(m['protein_g'] for m in f['meals'])
tk = sum(m['kcal'] for m in f['meals'])
A("**مجموع اليوم المخطط: %d جم بروتين · %d سعرة** (هامش %+d جم فوق هدف البروتين)"
  % (tp, tk, tp - f['protein_g_target']))
A("")
A("### 🏆 ملوك البروتين الرخيص")
A("")
A("| # | المصدر | البروتين | ملاحظة |")
A("|---|---|---|---|")
for s in sorted(f['protein_sources'], key=lambda x: x['rank']):
    A("| %d | **%s** | %s | %s |" % (s['rank'], s['name']['ar'], s['protein']['ar'], s['note']['ar']))
A("")
A("### ➕ إضافات سريعة (أكل خارج الخطة)")
A("")
A("> %s" % f['extras']['note']['ar'])
A("")
A("| | الصنف | بروتين | سعرات |")
A("|---|---|---|---|")
for x in f['extras']['items']:
    A("| %s | %s | %d جم | %d |" % (x['emoji'], x['name']['ar'], x['protein_g'], x['kcal']))
A("")
A("### 🚫 ابتعد عن")
A("")
for s in f['avoid']:
    A("- %s" % (s['ar'] if isinstance(s, dict) else s))
A("")
A("---")
A("")
A("## 🏋️ التمرين (٧ أيام · بدون صالة رياضية)")
A("")
A("**⏱️ %s**" % wk['tempo_rule']['ar'])
A("")
A("**😮‍💨 %s**" % wk['rest_rule']['ar'])
A("")
if wk.get('equipment_note', {}).get('ar'):
    A("> 🎒 %s" % wk['equipment_note']['ar'])
    A("")
A("### نظرة أسبوعية")
A("")
A("| اليوم | الجلسة | التركيز | حركات | مجموعات |")
A("|---|---|---|---|---|")
for d in days:
    ex = d.get('exercises', [])
    A("| %s %s | **%s** | %s | %d | %s |"
      % (names[d['day']], d['emoji'], d['title']['ar'], d['focus']['ar'], len(ex),
         sum(e['sets'] for e in ex) or '—'))
A("")
for d in days:
    A("---")
    A("")
    A("### %s %s — %s" % (names[d['day']], d['emoji'], d['title']['ar']))
    A("")
    A("**%s**" % d['focus']['ar'])
    A("")
    if d.get('is_rest'):
        A("🦴 يوم راحة:")
        A("")
        for s in d['rest_plan']:
            A("- %s" % (s['ar'] if isinstance(s, dict) else s))
        A("")
        continue
    for n, e in enumerate(d.get('exercises', []), 1):
        A("#### %d. %s" % (n, e['name']['ar']))
        A("")
        A("`%s` · **الهدف:** %s · **%d مجموعات × %s** · راحة %d ث · الإيقاع %s"
          % (e['name']['en'], e['target']['ar'], e['sets'], e['reps']['ar'], e['rest_s'], e['tempo']))
        A("")
        for i, st in enumerate(e['steps']['ar'], 1):
            A("%d. %s" % (i, st))
        if e.get('note', {}).get('ar'):
            A("")
            A("> 💡 %s" % e['note']['ar'])
        A("")
A("---")
A("")
A("## 🎒 %s" % c['backpack']['title']['ar'])
A("")
for s in c['backpack']['rules']:
    A("- %s" % (s['ar'] if isinstance(s, dict) else s))
A("")
A("---")
A("")
A("## 🛡️ القواعد والتحذيرات")
A("")
for r in c['rules']:
    A("### %s %s %s" % (r['emoji'], r['title']['ar'], '(خطورة عالية)' if r.get('severity') == 'high' else ''))
    A("")
    A("%s" % r['text']['ar'])
    A("")
A("---")
A("")
A("## 📈 التقدم")
A("")
A("%s" % c['progress']['title']['ar'])
A("")
A("**مؤشرات الأداء:**")
A("")
for k in c['progress']['kpis']:
    A("- %s **%s** — %s" % (k['emoji'], k['title']['ar'], k['detail']['ar']))
A("")
A("**سجل القوة (%s):** " % c['progress']['strength_log'].get('title', {}).get('ar', '') +
  " · ".join(x['name']['ar'] for x in c['progress']['strength_log']['exercises']))
A("")
A("**القياسات:** " + " · ".join(x['name']['ar'] for x in c['progress']['measurements']))
A("")
A("---")
A("")
A("## 🧠 لماذا ستنجح")
A("")
for p in c['philosophy']:
    A("### %s %s" % (p['emoji'], p['title']['ar']))
    A("")
    A("%s" % p['text']['ar'])
    A("")
A("---")
A("")
A("## 📲 استخدام التطبيق")
A("")
A("| التبويب | الوظيفة |")
A("|---|---|")
A("| **اليوم** | ٣ حلقات تقدم (مهام/ماء/بروتين) + روتين الساعة + تمرين اليوم + عدّاد الأيام المتتالية 🔥 |")
A("| **الماء** | الهدف والمحطات بأزرار +/− وإضافة سريعة ٢٥٠/٥٠٠/٧٥٠/١٠٠٠ مل |")
A("| **الطعام** | الوجبات وأصنافها بأرقامها الدقيقة · عدّاد بروتين/سعرات · رسم ٧ أيام · إضافات سريعة · ملوك البروتين · الممنوعات |")
A("| **التمرين** | ٧ أيام · مربع لكل مجموعة · رسم توضيحي · شرح مرقّم · **مؤقّت راحة** بضغطة على «٩٠ ث» |")
A("| **المزيد** | التقدم (سجل قوة + قياسات + رسوم) · القواعد · الإعدادات |")
A("")
A("**الإعدادات فيها:** اللغة (عربي/English) · المظهر (فاتح/داكن/النظام) · التحديث عن بُعد")
A("(مزامنة الآن + تغيير رابط المحتوى) · تحديث التطبيق (APK) · التنبيهات · **الودجت**")
A("(معاينة حيّة + تحديث يدوي + شرح الإضافة) · حذف البيانات.")
A("")
A("### 🧩 ودجت الشاشة الرئيسية (جديد 1.0.5)")
A("")
A("1. اضغط مطولاً على مكان فاضي في الشاشة الرئيسية.")
A("2. اختر **«ودجت» / Widgets**.")
A("3. ابحث عن **V-System** واسحبه للشاشة (يحتاج عرض ٤ خانات).")
A("4. يعرض: ماء + شريط تقدم · بروتين · سعرات · سلسلة الأيام 🔥 · تمرين اليوم + المجموعات.")
A("5. يتحدّث تلقائياً مع كل ضغطة في التطبيق، ويرجع بعد إعادة تشغيل الجوال.")
A("")
A("### 🛰️ تحديث المحتوى بدون إعادة تثبيت")
A("")
A("`content.json` على GitHub ← 🖊️ Edit ← عدّل ← ارفع `\"version\"` ← Commit ← في التطبيق")
A("**الإعدادات ← مزامنة الآن**. التطبيق يزامن تلقائياً كل ٦ ساعات ويعمل أوفلاين.")
A("")
A("### 📦 تحديث التطبيق نفسه")
A("")
A("لما ينزل إصدار جديد يظهر **شريط أخضر** في أسفل التطبيق ← «تنزيل وتثبيت» ← يفتح مثبّت")
A("أندرويد مباشرة، وبياناتك تبقى. (أول مرة بيطلب إذن «تثبيت من مصادر غير معروفة».)")
A("")
A("> ⚠️ **لمرة واحدة:** النسخ `1.0.2` و`1.0.3` فيها خلل في حساب رقم النسخة فلا يظهر لها")
A("> الشريط الأخضر. ثبّت **1.0.4 أو أحدث** يدوياً من صفحة Releases، وبعدها كل التحديثات ذاتية.")
A("")
# ---------------------------------------------------------- v1.1.0 (new) ----
em = c.get('exam_mode', {})
sl = c.get('sleep', {})
ci = c.get('checkin', {})
pt = f.get('price_tool', {})
bl = c['backpack'].get('load', {})
gates = wk.get('safety_gates', [])
pc = c['progress'].get('photo_checkpoint', {})
mc = c['progress'].get('monthly_checks', [])
rp = c.get('report', {})


def _ar(d, k='ar'):
    v = d.get(k, {}) if isinstance(d, dict) else {}
    return v.get('ar', '') if isinstance(v, dict) else ''


def _num(v, fallback=0):
    return v if isinstance(v, (int, float)) else fallback


A("---")
A("")
A("## ✨ جديد 1.1.0 — أدوات الالتزام والميزانية والأمان")
A("")
if ci:
    A("### 🌡️ %s" % _ar(ci, 'title'))
    A("")
    A("> %s" % _ar(ci, 'note'))
    A("")
    A("| | التقييم | ماذا يقول لك التطبيق |")
    A("|---|---|---|")
    for lv in ci.get('levels', []):
        A("| %s | **%s** | %s |" % (lv.get('emoji', ''), _ar(lv, 'label'), _ar(lv, 'advice')))
    A("")
    A("تقييم ≤ **%s** يومين ورا بعض = %s" % (_num(ci.get('sore_threshold'), 3), _ar(ci, 'deload_note')))
    A("")
if sl:
    A("### 😴 %s" % _ar(sl, 'title'))
    A("")
    A("> %s" % _ar(sl, 'note'))
    A("")
    A("- **الهدف:** نوم قبل `%s` · إقفال الشاشات `%s` · %s ساعات على الأقل."
      % (sl.get('target', '23:00'), sl.get('screens_off', '22:30'), _num(sl.get('hours_min'), 8)))
    A("- تسجّل ساعة نومك كل صباح بضغطة، والتطبيق يحسب **سلسلة النوم** 🔥 ويقارنها بهدف ١١ مساءً.")
    A("")
if em:
    A("### 🎓 %s" % _ar(em, 'title'))
    A("")
    A("> %s" % _ar(em, 'note'))
    A("")
    _keep = {d['id']: d for d in days}
    _kept = [_keep[i] for i in em.get('keep_days', []) if i in _keep]
    A("**الجلسات الباقية (%d):** %s"
      % (_num(em.get('sessions_per_week'), len(_kept)),
         ' · '.join('%s %s' % (d['emoji'], names[d['day']]) for d in _kept)))
    A("")
    for i, r in enumerate(em.get('rules', {}).get('ar', []), 1):
        A("%d. %s" % (i, r))
    A("")
if pt:
    A("### 💰 %s" % _ar(pt, 'title'))
    A("")
    A("> %s" % _ar(pt, 'note'))
    A("")
    A("| المصدر | الوحدة | بروتين الوحدة | الحد اليومي |")
    A("|---|---|---|---|")
    for s in f.get('protein_sources', []):
        if 'id' not in s:
            continue
        A("| %s | %s | %s جم | %s |"
          % (s['name']['ar'], s.get('unit', {}).get('ar', ''),
             _num(s.get('protein_per_unit_g')), s.get('max_units_label', {}).get('ar', '')))
    A("")
    A("التطبيق يحسب **ثمن كل %d جم بروتين** من كل مصدر ويرتّبها من الأرخص للأغلى،"
      " ثم يبني أرخص سلة تصل لـ**%d جم** مع احترام الحدود اليومية."
      % (_num(pt.get('per_grams'), 20), _num(f.get('protein_g_target'), 150)))
    A("")
if bl:
    A("### ⚖️ %s" % _ar(bl, 'title'))
    A("")
    A("> %s" % _ar(bl, 'note'))
    A("")
    _pct = bl.get('body_pct', [10, 20])
    A("- القارورة = %d مل · الماء %s كجم/لتر · الرمل %s كجم/لتر · الحقيبة نفسها %s كجم."
      % (_num(bl.get('bottle_ml'), 1500), _num(bl.get('water_kg_per_l'), 1),
         _num(bl.get('sand_kg_per_l'), 1.6), _num(bl.get('bag_kg'), 1)))
    A("- المدى الآمن لجسمك: **%s٪ – %s٪** من وزنك." % (_num(_pct[0], 10), _num(_pct[1], 20)))
    A("")
    for i, s in enumerate(bl.get('steps', {}).get('ar', []), 1):
        A("%d. %s" % (i, s))
    A("")
    A("> ⚠️ %s" % _ar(bl, 'warning'))
    A("")
for g in gates:
    A("### %s %s" % (g.get('emoji', '🛡️'), _ar(g, 'title')))
    A("")
    A("> %s" % _ar(g, 'why'))
    A("")
    A("**يمس التمارين:** %s" % ', '.join('`%s`' % x for x in g.get('exercise_ids', [])))
    A("")
    for i, s in enumerate(g.get('checklist', {}).get('ar', []), 1):
        A("%d. %s" % (i, s))
    A("")
    A("> 🚨 %s" % _ar(g, 'danger'))
    A("")
if pc:
    A("### 📸 %s" % _ar(pc, 'title'))
    A("")
    A("> %s" % _ar(pc, 'note'))
    A("")
    A("يظهر في التطبيق من يوم **%s** في كل شهر حتى تعلّم عليه." % _num(pc.get('day_of_month'), 15))
    A("")
    for i, s in enumerate(pc.get('checklist', {}).get('ar', []), 1):
        A("%d. %s" % (i, s))
    A("")
if mc:
    A("### 🗓️ فحوصات الشهر")
    A("")
    A("أربعة مؤشرات تُعلَّم مرة كل شهر (التعليم يُحفظ لكل شهر على حدة):")
    A("")
    for m in mc:
        A("- %s **%s**" % (m.get('emoji', ''), _ar(m, 'title')))
    A("")
if rp:
    A("### 📅 %s" % _ar(rp, 'title'))
    A("")
    A("> %s" % _ar(rp, 'note'))
    A("")
    tg = rp.get('targets', {})
    A("| الخانة | الهدف الأسبوعي |")
    A("|---|---|")
    for k, lab in [('water_pct', '💧 الماء'), ('protein_pct', '🍗 البروتين'),
                   ('routine_pct', '⏰ الروتين'), ('training_pct', '🏋️ التمرين'),
                   ('sleep_pct', '😴 النوم')]:
        if k in tg:
            A("| %s | %d%% |" % (lab, round(tg[k] * 100)))
    A("")
    for _i, _pr in enumerate(rp.get('praise', {}).get('ar', []), 1):
        A("%d. %s" % (_i, _pr))
    A("")

A("---")
A("")
A("## 🩺 ملاحظة طبية")
A("")
A("الخطة مبنية لشاب عمره %s وطوله %s–%s ووزنه %s–%s. أي ألم حاد في مفصل أو ظهر = **توقف فوراً**."
  % (p.get('age', '١٥'), p.get('height_cm', [185, 190])[0], p.get('height_cm', [185, 190])[1],
     p.get('weight_kg', [80, 85])[0], p.get('weight_kg', [80, 85])[1]))
A("التقدم البصري يبدأ فعلياً من الشهر الثالث، والنوم قبل ١١ مساءً جزء من التمرين وليس رفاهية.")
A("")
io.open('دليل-نظام-V.md', 'w', encoding='utf-8').write("\n".join(L) + "\n")
print("guide written: %d lines, %d chars" % (len(L), sum(len(x) for x in L)))
