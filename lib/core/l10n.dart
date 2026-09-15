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
