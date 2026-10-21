import 'package:flutter/widgets.dart';

class DesktopStrings {
  const DesktopStrings(this.fa);
  final bool fa;
  static DesktopStrings of(BuildContext context) =>
      DesktopStrings(Localizations.localeOf(context).languageCode == 'fa');
  String t(String key) => (_copy[key] ?? [key, key])[fa ? 1 : 0];
  static const _copy = <String, List<String>>{
    'panelSize': ['Panel size', 'اندازهٔ نوار پنل'],
    'panelSizeHint': [
      'Only the dock and its icons change size; open cards keep their size.',
      'فقط نوار و آیکون‌ها تغییر اندازه می‌دهند؛ کارت‌های باز ثابت می‌مانند.',
    ],
    'edgeArea': ['Reveal area', 'محدودهٔ بازشدن پنل'],
    'edgeAreaHint': [
      'Only this area on the chosen screen edge reveals the panel.',
      'پنل فقط با رفتن نشانگر به این محدوده از لبهٔ انتخابی باز می‌شود.',
    ],
    'edgeWidth': ['Area width', 'عرض محدوده'],
    'edgeHeight': ['Area height', 'ارتفاع محدوده'],
    'edgePosition': ['Position from top', 'موقعیت از بالا'],
    'resetPanel': ['Reset panel controls', 'بازنشانی تنظیمات پنل'],

    'writingMode': ['Focus on writing', 'تمرکز روی نوشتن'],
    'leaveWriting': ['Leave writing mode (Esc)', 'خروج از حالت نوشتن (Esc)'],
    'wordCount': ['Words', 'واژه‌ها'],
    'writingSaving': ['Saving…', 'در حال ذخیره…'],
    'writingFailed': [
      'Could not save — check the error message',
      'ذخیره نشد؛ پیام خطا را بررسی کن',
    ],
    'writingReady': ['Ready to write', 'آمادهٔ نوشتن'],
    'writingSaved': ['Saved locally', 'روی دستگاه ذخیره شد'],
    'welcomeTitle': ['Make Nex yours', 'نکس را برای خودت تنظیم کن'],
    'welcomeHint': [
      'Your notes stay on this device. AI stays off until you choose it in settings. You can change these choices later.',
      'یادداشت‌ها روی همین دستگاه می‌مانند. هوش تا وقتی در تنظیمات فعالش نکنی خاموش است. این گزینه‌ها را بعداً هم می‌توانی تغییر بدهی.',
    ],
    'welcomeSkip': ['Skip setup', 'رد کردن راه‌اندازی'],
    'welcomeStart': ['Start writing', 'شروع نوشتن'],
    'welcomeImport': [
      'Import a backup (optional)',
      'ورود نسخهٔ پشتیبان (اختیاری)',
    ],
    'welcomeKeys': [
      'Ctrl+N: new note · Ctrl+L: library · Ctrl+K: search · F1: all shortcuts',
      'Ctrl+N: یادداشت تازه · Ctrl+L: کتابخانه · Ctrl+K: جست‌وجو · F1: همهٔ میان‌برها',
    ],
    'whatsNew': ["What's new", 'تازه‌های نکس'],
    'releaseNotesError': [
      'Release notes could not be loaded.',
      'یادداشت‌های انتشار بارگذاری نشد.',
    ],
    'searchSettings': ['Search settings', 'جست‌وجوی تنظیمات'],
    'settingsIntro': ['Make Nex feel like you.', 'نکس را به سلیقهٔ خودت بساز.'],
    'settingsHint': [
      'Your space, your pace. Everything stays within reach.',
      'فضای تو، با سلیقهٔ تو. همه‌چیز در دسترس است.',
    ],
    'back': ['Back to settings', 'بازگشت به تنظیمات'],
    'personal': ['Personalize', 'شخصی‌سازی'],
    'data': ['Your data & tools', 'داده‌ها و ابزارهای تو'],
    'displayHint': [
      'Window, edge panel and startup',
      'پنجره، پنل کناری و اجرای خودکار',
    ],
    'appearanceHint': [
      'Theme, colors and comfortable reading',
      'تم، رنگ‌ها و اندازهٔ مناسب خواندن',
    ],
    'shortcutsHint': [
      'Keyboard shortcuts and interaction',
      'میان‌برهای صفحه‌کلید و تعامل',
    ],
    'backupHint': [
      'Portable backups and safe restore',
      'پشتیبان مشترک و بازیابی مطمئن',
    ],
    'toolsHint': ['Arrange your everyday toolkit', 'چیدمان ابزارهای روزمره'],
    'aboutHint': [
      'Version, updates and licenses',
      'نسخه، به‌روزرسانی و مجوزها',
    ],
    'aiHint': [
      'Provider, abilities and privacy',
      'ارائه‌دهنده، قابلیت‌ها و حریم خصوصی',
    ],
    'updates': ['App updates', 'به‌روزرسانی برنامه'],
    'automatic': ['Automatic updates', 'به‌روزرسانی خودکار'],
    'automaticHint': [
      'Check GitHub and download new releases in the background. You choose when to install.',
      'نسخهٔ جدید از GitHub در پس‌زمینه دریافت می‌شود؛ زمان نصب را خودت انتخاب می‌کنی.',
    ],
    'check': ['Check for updates', 'بررسی نسخهٔ جدید'],
    'checking': ['Checking GitHub…', 'در حال بررسی GitHub…'],
    'upToDate': ['You’re up to date', 'آخرین نسخه را داری'],
    'available': ['A new Nex is available', 'نسخهٔ جدید نکس آماده است'],
    'download': ['Download update', 'دانلود به‌روزرسانی'],
    'downloading': ['Downloading update', 'در حال دریافت نسخهٔ جدید'],
    'ready': ['Your update is ready', 'به‌روزرسانی آمادهٔ نصب است'],
    'install': ['Install & restart', 'نصب و راه‌اندازی مجدد'],
    'installing': [
      'Saving your work and restarting…',
      'ذخیرهٔ کارها و راه‌اندازی مجدد…',
    ],
    'updateCheckError': [
      'Couldn’t reach GitHub. Try again when you’re connected.',
      'ارتباط با GitHub برقرار نشد؛ پس از اتصال دوباره تلاش کن.',
    ],
    'updateDownloadError': [
      'Download couldn’t be verified. Retry to get a complete, checked installer.',
      'دانلود کامل و تأیید نشد؛ برای دریافت فایل معتبر دوباره تلاش کن.',
    ],
    'updateInstallError': [
      'Nex couldn’t finish the update. Close any other Nex windows and retry.',
      'نصب کامل نشد؛ پنجره‌های دیگر نکس را ببند و دوباره تلاش کن.',
    ],
    'updatePrivacy': [
      'Downloads come from the latest stable GitHub release and are checked against SHA256SUMS. Notes and AI keys aren’t sent.',
      'دانلود از آخرین نسخهٔ منتشرشدهٔ پایدار GitHub است و با SHA256SUMS بررسی می‌شود. یادداشت‌ها و کلیدهای هوش ارسال نمی‌شوند.',
    ],
    'retry': ['Try again', 'تلاش دوباره'],
    'installed': ['Installed version', 'نسخهٔ نصب‌شده'],
    'verified': [
      'Verified download · ready when you are',
      'دانلود تأییدشده؛ هر وقت آماده بودی نصب کن',
    ],
    'later': ['Later', 'بعداً'],
    'aiStatusOn': ['Intelligence is on', 'هوش نکس روشن است'],
    'aiStatusOff': [
      'A little intelligence, on your terms.',
      'کمی هوش، با انتخاب خودت.',
    ],
    'aiStatusHint': [
      'Your provider, your notes, your choice.',
      'ارائه‌دهندهٔ تو، یادداشت‌های تو، انتخاب تو.',
    ],
    'abilities': ['What Nex can help with', 'نکس کجا می‌تواند کمک کند'],
    'transcriptionHint': [
      'Turn recordings into searchable words when you ask.',
      'وقتی بخواهی، صدا را به متن قابل جست‌وجو تبدیل کن.',
    ],
    'imageHint': [
      'Read useful text and describe your images.',
      'متن مفید تصویر را بخوان و محتوایش را توصیف کن.',
    ],
    'summaryHint': [
      'Find the essentials in a longer note.',
      'اصل مطلب را از یک یادداشت بلند بیرون بکش.',
    ],
    'tagsHint': [
      'Suggest a place for each thought. You decide what to keep.',
      'برای هر فکر برچسب پیشنهاد بده؛ انتخاب نهایی با توست.',
    ],
    'semanticHint': [
      'Find notes by meaning, beyond matching words.',
      'یادداشت را از روی معنا پیدا کن، فراتر از واژه‌ها.',
    ],
    'related': ['Related notes', 'یادداشت‌های مرتبط'],
    'paused': ['Temporarily paused', 'موقتاً غیرفعال'],
    'notSupported': [
      'This provider doesn’t support this ability.',
      'این ارائه‌دهنده از این قابلیت پشتیبانی نمی‌کند.',
    ],
    'providerHint': [
      'Choose where requests go. Test your exact configuration before saving.',
      'مقصد درخواست‌ها را انتخاب کن. پیش از ذخیره، همین تنظیمات را آزمایش کن.',
    ],
    'response': ['Make it sound like you', 'پاسخ‌ها به سبک تو'],
    'access': ['You’re in control', 'اختیار دست توست'],
    'accessHint': [
      'Choose what the assistant can read and propose.',
      'انتخاب کن دستیار چه چیزی را بخواند و چه تغییری پیشنهاد کند.',
    ],
    'askHint': [
      'A calm space to think with your notes.',
      'فضایی آرام برای فکر کردن با یادداشت‌هایت.',
    ],
    'noteAi': ['Nex AI', 'هوش نکس'],
  };
}
