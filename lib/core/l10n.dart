/// Static UI strings (everything that is *not* part of the remote content file).
class L10n {
  final bool ar;
  const L10n(this.ar);

  String s(String a, String e) => ar ? a : e;

  // navigation
  String get today => s('اليوم', 'Today');
  String get water => s('الماء', 'Water');
  String get food => s('الطعام', 'Food');
  String get training => s('التمرين', 'Training');
  String get more => s('المزيد', 'More');

  // today
  String get dailyRoutine => s('الروتين اليومي (الساعة البيولوجية)', 'Daily routine (body clock)');
  String get todayWorkout => s('تمرين اليوم', "Today's workout");
  String get restDay => s('يوم راحة', 'Rest day');
  String get daySummary => s('ملخص اليوم', 'Day summary');
  String get tasksDone => s('مهام منجزة', 'tasks done');
  String get streak => s('أيام متتالية', 'day streak');
  String get openWorkout => s('افتح التمرين', 'Open workout');
  String get nothingLeft => s('خلصت يومك 💪 كل شيء مكتمل.', 'Day complete 💪 everything ticked.');
  String get keepGoing => s('كمل — باقي القليل.', 'Keep going - almost there.');

  // water
  String get waterGoal => s('الهدف اليومي', 'Daily goal');
  String get glasses => s('زجاجات', 'glasses');
  String get addGlass => s('أضف زجاجة', 'Add glass');
  String get quickAdd => s('إضافة سريعة', 'Quick add');
  String get schedule => s('جدول الماء', 'Water schedule');
  String get reset => s('تصفير', 'Reset');
  String get liters => s('لتر', 'L');
  String get done => s('تم', 'Done');

  // food
  String get proteinToday => s('بروتين اليوم', "Today's protein");
  String get kcalToday => s('سعرات اليوم', "Today's kcal");
  String get target => s('الهدف', 'Target');
  String get meals => s('وجبات اليوم', "Today's meals");
  String get cheapProtein => s('ملوك البروتين الرخيص', 'Kings of cheap protein');
  String get avoidList => s('ابتعد عن', 'Avoid');
  String get budgetRule => s('قاعدة الميزانية', 'Budget rule');
  String get protein => s('بروتين', 'protein');

  // workout
  String get week => s('الأسبوع', 'Week');
  String get exercises => s('التمارين', 'Exercises');
  String get setsWord => s('مجموعات', 'sets');
  String get repsWord => s('تكرار', 'reps');
  String get rest => s('راحة', 'rest');
  String get tempo => s('الإيقاع', 'Tempo');
  String get howTo => s('طريقة التنفيذ', 'How to perform');
  String get markDayDone => s('أنهيت تمرين اليوم', 'Mark session complete');
  String get seconds => s('ث', 's');
  String get perSet => s('لكل مجموعة', 'per set');

  // progress
  String get progress => s('التقدم', 'Progress');
  String get strengthLog => s('سجل القوة', 'Strength log');
  String get measurements => s('القياسات', 'Measurements');
  String get addEntry => s('أضف', 'Add');
  String get value => s('القيمة', 'Value');
  String get noData => s('لا يوجد سجل بعد — أضف أول رقم.', 'No entries yet - add your first number.');
  String get kpis => s('مؤشرات الأداء', 'KPIs');

  // rules
  String get rules => s('القواعد والتحذيرات', 'Rules & warnings');
  String get philosophy => s('لماذا ستنجح؟', 'Why this works');
  String get backpackTitle => s('تجهيز الحقيبة', 'Backpack setup');

  // settings
  String get settings => s('الإعدادات', 'Settings');
  String get language => s('اللغة', 'Language');
  String get arabic => s('العربية', 'Arabic');
  String get english => s('English', 'English');
  String get appearance => s('المظهر', 'Appearance');
  String get themeSystem => s('حسب النظام', 'System');
  String get themeLight => s('فاتح', 'Light');
  String get themeDark => s('داكن', 'Dark');
  String get remoteContent => s('التحديث عن بُعد (المحتوى)', 'Remote content update');
  String get syncNow => s('مزامنة الآن', 'Sync now');
  String get contentUrl => s('رابط ملف المحتوى', 'Content file URL');
  String get contentVersion => s('نسخة المحتوى', 'Content version');
  String get lastSynced => s('آخر مزامنة', 'Last sync');
  String get never => s('أبداً', 'Never');
  String get source => s('المصدر', 'Source');
  String get sourceAsset => s('المدمج في التطبيق', 'bundled with the app');
  String get sourceCache => s('نسخة محفوظة', 'saved copy');
  String get sourceRemote => s('من الإنترنت', 'from the network');
  String get restoreBundled => s('إرجاع المحتوى الأصلي', 'Restore bundled content');
  String get appUpdate => s('تحديث التطبيق (APK)', 'App update (APK)');
  String get checkUpdate => s('فحص التحديث', 'Check for update');
  String get upToDate => s('أنت على آخر نسخة 🎉', 'You are up to date 🎉');
  String get newVersion => s('فيه نسخة جديدة', 'New version available');
  String get downloadInstall => s('تنزيل وتثبيت', 'Download & install');
  String get downloading => s('جاري التنزيل…', 'Downloading…');
  String get installNow => s('تثبيت الآن', 'Install now');
  String get currentVersion => s('النسخة الحالية', 'Current version');
  String get allowUnknown => s('اسمح بالتثبيت من مصادر غير معروفة', 'Allow install from unknown sources');
  String get openSettings => s('فتح الإعدادات', 'Open settings');
  String get reminders => s('التنبيهات', 'Reminders');
  String get remindersOn => s('تنبيهات الماء والتمرين والنوم', 'Water, workout and sleep reminders');
  String get dataSection => s('البيانات', 'Data');
  String get wipeData => s('حذف كل بياناتي', 'Erase all my data');
  String get wipeConfirm => s('سيحذف كل التقدم (ماء، وجبات، تمارين، سجلات). متأكد؟',
      'This erases all progress (water, meals, sets, logs). Are you sure?');
  String get cancel => s('إلغاء', 'Cancel');
  String get ok => s('موافق', 'OK');
  String get save => s('حفظ', 'Save');
  String get howRemoteWorks => s('كيف يشتغل التحديث عن بُعد؟', 'How does remote updating work?');

  // food extras (v4 content) + week chart
  String get extrasTitle => s('إضافات سريعة', 'Quick extras');
  String get extrasHint => s('أكلت شي خارج الخطة؟ اضغط + ليُحسب فوراً', 'Ate something off-plan? Tap + to count it instantly');
  String get weekChart => s('آخر ٧ أيام', 'Last 7 days');
  String get avg => s('المتوسط', 'Average');
  String get best => s('أفضل يوم', 'Best day');
  String get kcalUnit => s('سعرة', 'kcal');
  String get gUnit => s('جم', 'g');
  String get exactCount => s('عدّ دقيق لكل صنف', 'Exact count per item');
  String get perItem => s('لكل صنف', 'per item');

  // home-screen widget
  String get widgetTitle => s('ودجت الشاشة الرئيسية', 'Home-screen widget');
  String get widgetHint => s('ماء + بروتين + تمرين اليوم على شاشتك بدون فتح التطبيق',
      'Water, protein and today\'s session on your home screen - no need to open the app');
  String get widgetRefresh => s('تحديث الودجت الآن', 'Refresh widget now');
  String get widgetHow => s('كيف أضيفه؟', 'How do I add it?');
  String get widgetHowBody => s(
      'اضغط مطولاً على مكان فاضي في الشاشة الرئيسية ← «ودجت» / «Widgets» ← ابحث عن V-System ← اسحبه للشاشة. بعدها يتحدّث تلقائياً مع كل ضغطة في التطبيق.',
      'Long-press an empty spot on your home screen -> Widgets -> find V-System -> drag it onto the screen. It then refreshes automatically with every tap you make in the app.');
  String get widgetUpdated => s('تم تحديث الودجت ✅', 'Widget refreshed ✅');

  // exercise art
  String get showArt => s('رسوم التمارين', 'Exercise illustrations');

  // exam mode (v1.1)
  String get examMode => s('وضع الامتحانات', 'Exam mode');
  String get examModeHint => s('الدراسة أولاً: ٣ جلسات فقط في الأسبوع', 'Study first: only 3 sessions a week');
  String get examModeOn => s('مفعّل — الجدول مخفّف', 'On - lighter week');
  String get examModeOff => s('مطفأ — الجدول الكامل', 'Off - full week');
  String examSessions(int n) => s('$n جلسات في الأسبوع', '$n sessions a week');
  String get examDropped => s('مؤجّل للامتحانات', 'paused for exams');
  String get examKept => s('من جلسات وضع الامتحانات', 'kept in exam mode');

  // growth sleep (v1.1)
  String get sleepTitle => s('نوم النمو', 'Growth sleep');
  String get logBedtime => s('سجّل ساعة نومك', 'Log your bedtime');
  String get bedtimeLastNight => s('نمت الساعة', 'You slept at');
  String get sleepOnTime => s('داخل نافذة هرمون النمو ✅', 'inside the growth-hormone window ✅');
  String sleepLate(int m) => s('متأخر $m دقيقة عن ١١ مساءً', '$m min past the 11 PM cutoff');
  String get sleepStreak => s('سلسلة النوم', 'sleep streak');
  String get sleepNotLogged => s('لم تسجّل نومك اليوم بعد', 'No bedtime logged yet today');
  String get sleepTarget => s('الهدف', 'Target');
  String get clearEntry => s('مسح', 'Clear');
  String get changeEntry => s('تغيير', 'Change');

  // daily check-in (v1.1)
  String get checkinTitle => s('تقييم اليوم', "Today's check-in");
  String get checkinAsk => s('كيف جسمك اليوم؟ اضغط مرة واحدة.', 'How does your body feel? One tap.');
  String get checkinDone => s('تقييمك اليوم', 'Your rating today');
  String get deloadTitle => s('يومان منخفضان — خفّف الأسبوع', 'Two low days - deload this week');

  // protein price tool (v1.1)
  String get priceTool => s('حاسبة سعر البروتين', 'Protein price calculator');
  String get pricePer20 => s('سعر ٢٠ جم بروتين', 'price of 20 g protein');
  String get enterPrice => s('اكتب السعر', 'Enter price');
  String get cheapestBasket => s('أرخص سلة لهدف اليوم', 'Cheapest basket for today');
  String get basketEmpty => s('اكتب سعر مصدرين على الأقل لتظهر أرخص سلة.', 'Price at least two sources to see the cheapest basket.');
  String get notPriced => s('بلا سعر', 'no price');
  String get perDay => s('في اليوم', 'per day');
  String get yourCurrency => s('رمز العملة', 'Currency symbol');
  String get cheapest => s('الأرخص', 'cheapest');
  String get priciest => s('الأغلى', 'priciest');

  // backpack load calculator (v1.1)
  String get backpackCalc => s('حاسبة وزن الحقيبة', 'Backpack load calculator');
  String get bottles => s('قوارير', 'bottles');
  String get fill => s('الحشو', 'Fill');
  String get fillWater => s('ماء', 'Water');
  String get fillHalf => s('نصف رمل', 'Half sand');
  String get fillSand => s('رمل', 'Sand');
  String get totalLoad => s('الوزن الكلي', 'Total load');
  String get safeRange => s('المدى الآمن لجسمك', 'Safe range for you');
  String get loadLight => s('خفيف — تقدر تزيد', 'Light - you can add more');
  String get loadGood => s('مناسب — ابدأ به', 'Good - start here');
  String get loadHeavy => s('ثقيل — خفّف قارورة', 'Heavy - drop a bottle');

  // safety gates (v1.1)
  String get safetyBriefing => s('قبل أن تبدأ: الأمان', 'Before you start: safety');
  String get safetyAcked => s('راجع checklist الأمان', 'Review the safety checklist');
  String get safetyOpen => s('أمان الطاولة', 'Table safety');
  String get safetyDone => s('تم التأمين ✓', 'Secured ✓');

  // weekly report (v1.1)
  String get weeklyReport => s('تقرير الأسبوع', 'Weekly report');
  String get reportHint => s('التزامك الحقيقي في آخر ٧ أيام مقابل الأسبوع الذي قبله', 'Your real adherence over the last 7 days versus the week before');
  String get thisWeek => s('هذا الأسبوع', 'this week');
  String get lastWeek => s('الأسبوع الماضي', 'last week');
  String get adherence => s('الالتزام', 'Adherence');
  String get sessionsDone => s('جلسات مكتملة', 'sessions complete');
  String get recordsSet => s('أرقام قياسية', 'personal records');
  String get nightsOnTime => s('ليالٍ في الموعد', 'nights on time');
  String get weakestRow => s('أضعف خانة — ركّز عليها الأسبوع الجاي', 'Weakest column - focus here next week');
  String get reportNoData => s('لا يوجد ما يكفي من البيانات بعد. سجّل يومين أو ثلاثة وارجع.', 'Not enough data yet. Log two or three days and come back.');

  // monthly checks (v1.1)
  String get monthlyChecks => s('فحوصات الشهر', 'Monthly checks');
  String get thisMonth => s('هذا الشهر', 'this month');
  String get photoDue => s('صورة الشهر حانت — يوم ١٥', 'Photo day is here - the 15th');
  String get photoDone => s('صورة الشهر تمت ✓', 'Monthly photo done ✓');

  // personal records (v1.1)
  String get newRecord => s('رقم قياسي جديد 🎉', 'New personal record 🎉');
  String newRecordBody(String v, String unit) => s('$v $unit — أفضل رقم لك حتى الآن. هذا هو الدليل على أن العضل يكبر.', '$v $unit - your best ever. This is the proof that muscle is being built.');

  // row labels for the report
  String reportRow(String id) {
    switch (id) {
      case 'water':
        return water;
      case 'protein':
        return protein;
      case 'routine':
        return s('الروتين', 'Routine');
      case 'training':
        return training;
      case 'sleep':
        return sleepTitle;
      default:
        return id;
    }
  }

  // misc
  String get retry => s('إعادة المحاولة', 'Retry');
  String get close => s('إغلاق', 'Close');
  String get of => s('من', 'of');
  String get todayLabel => s('اليوم', 'Today');
  String get daysShort => s('يوم', 'd');

  static const _wdAr = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _wdEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _wdArS = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
  static const _wdEnS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  String weekday(int i) => (ar ? _wdAr : _wdEn)[(i - 1).clamp(0, 6)];

  String weekdayShort(int i) => (ar ? _wdArS : _wdEnS)[(i - 1).clamp(0, 6)];

  String monthDay(DateTime d) {
    if (ar) {
      const m = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
      return '${d.day} ${m[d.month - 1]}';
    }
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}';
  }
}
