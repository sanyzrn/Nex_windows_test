# Nex Windows

نسخهٔ ویندوز **0.11.0+7** از Nex برای ویندوز، بر پایهٔ پروژهٔ Flutter دسکتاپ و معماری local-first.

## حالت نمایش و قابلیت‌های نسخهٔ 0.11.0

- **پنجرهٔ کامل دسکتاپ (حالت دو ستونه):** در عرض‌های بالاتر از ۹۰۰ پیکسل، نمایش دو ستونهٔ فهرست یادداشت‌ها و مطالعه/ویرایشگر با جداکنندهٔ قابل کشیدن (Drag) و ذخیرهٔ موقعیت.
- **یادآورهای پایدار ویندوز:** اتصال به سرویس اعلان‌های ویندوز (C++/WinRT Scheduled Toast Notifications) با شناسهٔ برنامه `Nex.Desktop.App`، عملکرد پایدار حتی پس از بستن برنامه و زمان‌بندی تکرار روزانه/هفتگی.
- **بازیابی کامل نسخهٔ پشتیبان (Backup Restore):** بازیابی فایل‌های `.nexbak` و `.nexfull` (با رمزگشایی کلید خصوصی) با اعتبارسنجی مرحله‌ای و جابه‌جایی اتمیک.
- **ثبت لینک و استخراج متادیتا:** مطالعهٔ مستقیم استریم صفحات وب تا سقف ۲۵۶ کیلوبایت و اولویت عنوان Open Graph.
- **تعهدهای دوره‌ای (Commitments):** مدیریت تعهدهای دوره‌ای با روزهای هفته به تقویم فارسی (آغاز از شنبه).
- **کلیدهای میانبر و منوی راست‌کلیک:** کلیدهای `Ctrl+N`، `Ctrl+Shift+N`، `Ctrl+F`، `Ctrl+L`، `Ctrl+,`، `Ctrl+P`، `Ctrl+C`، حذف با قابلیت Undo (`Ctrl+Z`)، راهنمای کلیدهای میانبر (`F1`) و انتخاب چندگانه (Multi-select).

## دریافت نسخهٔ آماده

- [نسخه‌های منتشرشده و نصاب ویندوز](https://github.com/sanyzrn/Nex_windows_test/releases)
- [SHA-256 نصاب](SHA256SUMS)

فایل‌های نصبی منتشرشده از GitHub Releases دریافت می‌شوند. نصاب ۰.۱۱.۰ فعلاً خروجی محلی ساخت است و در گیت قرار نمی‌گیرد؛ checksum آن در `SHA256SUMS` ثبت شده است. نصاب شامل تمام وابستگی‌های اجرایی است و برای کاربر جاری نصب می‌شود. پیش از به‌روزرسانی، Nex را ببندید. داده‌های یادداشت‌ها با به‌روزرسانی حفظ می‌شوند. این نصاب آزمایشی امضای دیجیتال ندارد.

## ساخت از سورس

این مخزن مستقل است: `apps/desktop` و هر چهار پکیج موردنیاز Nex در `packages` قرار دارند. تغییرات مشترک backup/theme از قبل اعمال شده‌اند؛ فایل‌های `patches` صرفاً برای تحویل به مخزن اصلی Nex نگه داشته شده‌اند و **در این مخزن نباید دوباره اعمال شوند**.

نیازمندی‌ها: ویندوز x64، Flutter **3.35.0 یا جدیدتر / Dart 3.9.0 یا جدیدتر** و Visual Studio با workload توسعهٔ دسکتاپ C++.

از Flutter نصب‌شده روی سیستم استفاده کنید. قفل FVM حذف شده است؛ فایل‌های `pubspec.yaml` محدودهٔ نسخه‌های سازگار SDK را تعیین می‌کنند. بررسی فعلی و CI از Flutter 3.44.8 / Dart 3.12.2 استفاده می‌کنند. نصب یا downgrade خودکار SDK لازم نیست. اعتبارسنجی تاریخی ریلیز 0.9.0 مربوط به toolchain قبلی است.

```powershell
git clone https://github.com/sanyzrn/Nex_windows_test.git
cd Nex_windows_test/apps/desktop
# Mirror hosts match the validated lockfile; use these for tested resolution.
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --release --no-pub
```

برای اجرا از سورس: `flutter run -d windows`. خروجی `build/windows/x64/runner/Release` باید به‌صورت کامل توزیع شود. ساخت نصاب با Inno Setup در [راهنمای نصاب](apps/desktop/installer/README.md) توضیح داده شده است.

## اصلاحات این نسخه

- پنجرهٔ کامل دسکتاپ به‌عنوان حالت اصلی؛ نوار لبهٔ اختیاری با تعویض لحظه‌ای و حفظ جای پنجره.
- در حالت پنجره، برنامه با از دست دادن فوکوس بسته نمی‌شود و ناظر لبه غیرفعال است.
- اصلاح «پاک کردن» کلیپ‌بورد که مقادیر سنجاق‌شده را هم پاک می‌کرد؛ بازیابی متن‌های سنجاق‌شده هنگام اجرا.
- حذف فایل موقت ضبط فقط پس از ذخیرهٔ موفق؛ در خطا فایل صوتی برای بازیابی باقی می‌ماند.
- پیام خطا در اشغال بودن کلید میان‌بر، ترجمهٔ «واحد ناشناخته»/«ایموجی پیدا نشد» و متن‌های جدید حالت نمایش.
- اسکرول خودکار نوار به ابزار فعال؛ پایه‌بندی ساختارها برای ارتفاع‌های متغیر.

اصلاحات نگه‌داشته‌شده از 0.9.0:

- پین مستقل پنل برای باز ماندن آن؛ محافظت از تایپ، مطالعه، منو، انتخاب فایل و ضبط در برابر بسته‌شدن خودکار.
- اصلاح دریافت کلیک در پایین پنلِ جابه‌جاشده، انتخابگرهای مجزای تصویر/صوت/فایل و پیام صحیح لغو یا خطا.
- نمایش درون پنل برای خواندن و ویرایش یادداشت، آیکون‌ها و فاصله‌های هماهنگ، سایه‌های ملایم‌تر.
- اصلاح پخش صوت ویندوز، کنترل پایان پخش و ضبط WAV.

نتایج تست‌های نسخهٔ 0.11.0، بررسی‌های فعلی و محدودیت‌های اعتبارسنجی در [گزارش تست](docs/TEST_RESULTS.md) ثبت می‌شود. آزمون‌های واحد یادآور از زمان‌بند شبیه‌سازی‌شده استفاده می‌کنند؛ بررسی اعلان واقعی ویندوز و نمایش روی چند مانیتور همچنان به تست دستی نیاز دارد.

## ساختار و منشأ

| مسیر | محتوا |
| --- | --- |
| `apps/desktop` | سورس Flutter، کد native ویندوز، تست‌ها، فونت‌ها و ابزار ساخت نصاب |
| `packages/core`, `data`, `ui`, `ai` | پکیج‌های لازم Nex با تغییرات مشترک نهایی |
| `patches` | یک نسخه از دو patch برای تحویل تغییرات مشترک به checkout اصلی Nex |
| `docs` | گزارش تحویل، اعتبارسنجی، خلاصهٔ وضعیت و راهنمای ادغام |
| `docs/archive` | شرح کار تاریخی نسخهٔ ۰.۱۱ |
| `spec` | داده‌های مشترک آزمون انطباق مدل‌ها |

Nex packages originate from [sanyzrn/DbsNex](https://github.com/sanyzrn/DbsNex), base `4861feac41530c951cb9e637ff921c6472d7de58`. Desktop shell uses the owner's extracted `right_panel_flutter.zip`; the original [raminturne/right-panel](https://github.com/raminturne/right-panel) at `90dcdbde8e33816f08b681c65cd341aa796f81e4` was a read-only reference. No changes were pushed to either upstream repository.

Nex notes/schema/repositories and shared design tokens remain the source of domain behaviour. Windows reminders and backup restore UI are implemented; assistant/Vault and sync/OCR/on-device AI remain absent or out of scope. See [desktop architecture and limitations](apps/desktop/README.md) and the [integration guide](docs/INTEGRATION.md). Third-party attribution is in [THIRD_PARTY_NOTICES.md](apps/desktop/THIRD_PARTY_NOTICES.md); Nex uses the root MIT [LICENSE](LICENSE).
