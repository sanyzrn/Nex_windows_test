# Nex Windows test

نسخهٔ آزمایشی ویندوز **0.10.0** (build 6) از Nex برای ویندوز، بر پایهٔ پروژهٔ Flutter Right Panel.

## حالت نمایش جدید

از این نسخه، **پنجرهٔ کامل دسکتاپ** حالت اصلی برنامه است: یک پنجرهٔ معمولی ویندوز با کپشن، تغییر اندازه، حداکثر/حداقل کردن، نوار ناوبری (ثبت سریع، کتابخانه، ابزارها، تنظیمات) و همان داده‌ها و قابلیت‌های قبلی. **نوار لبه** (اسلاید از لبهٔ صفحه) به‌عنوان حالتی اختیاری حفظ شده و از تنظیمات یا دکمهٔ کنار نوار قابل تعویض است. هر دو حالت از یک پایگاه داده، یک جلسهٔ ثبت و یک تنظیمات مشترک استفاده می‌کنند و جای پنجره و اندازهٔ آن بین اجراها ذخیره می‌شود.

## دریافت نسخهٔ آماده

- [نصاب ویندوز x64 — 0.10.0](https://github.com/sanyzrn/Nex_windows_test/releases/download/v0.10.0/Nex-Windows-Setup-0.10.0-x64.exe)
- [ZIP سورس همگام با این نسخه](https://github.com/sanyzrn/Nex_windows_test/archive/refs/tags/v0.10.0.zip)
- [SHA-256 نصاب](https://github.com/sanyzrn/Nex_windows_test/releases/download/v0.10.0/SHA256SUMS)

فایل نصبی از GitHub Release دریافت می‌شود، شامل تمام وابستگی‌های اجرایی است و برای کاربر جاری نصب می‌شود. پیش از به‌روزرسانی، Nex را ببندید. داده‌های یادداشت‌ها با به‌روزرسانی حفظ می‌شوند. این نصاب آزمایشی امضای دیجیتال ندارد.

## ساخت از سورس

این مخزن مستقل است: `apps/desktop` و هر چهار پکیج موردنیاز Nex در `packages` قرار دارند. تغییرات مشترک backup/theme از قبل اعمال شده‌اند؛ فایل‌های `patches` صرفاً برای تحویل به مخزن اصلی Nex نگه داشته شده‌اند و **در این مخزن نباید دوباره اعمال شوند**.

نیازمندی‌ها: ویندوز x64، Flutter **3.35.0 یا جدیدتر / Dart 3.9.0 یا جدیدتر** و Visual Studio با workload توسعهٔ دسکتاپ C++.

از Flutter نصب‌شده روی سیستم استفاده کنید. قفل FVM حذف شده است؛ SDKها فقط حداقل نسخه دارند و سقف نسخه ندارند. نصب یا downgrade خودکار SDK لازم نیست. اعتبارسنجی تاریخی ریلیز 0.9.0 مربوط به toolchain قبلی است.

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

اعتبارسنجی تحویل: **37 تست (شامل ۵ تست جدید پوستهٔ پنجره) و ۱۰ مقایسهٔ golden**، analyzer بدون ایراد. تست‌ها روی لینوکس اجرا شده‌اند؛ مقایسه‌های golden به دلیل تفاوت فونت‌های سیستم در لینوکس با خطای پیکسلی جزئی شکست می‌خورند که روی کد اصلی هم همین‌طور است و باید روی ویندوز بازبینی شوند. ساخت Release و نصاب و اجرای native روی ویندوز باید توسط مالک تکرار شود. ضبط میکروفون، مانیتورهای mixed-DPI و اهداف کارایی هنوز تست واقعی کامل ندارند. [گزارش تست](TEST_RESULTS.md) حدود دقیق بررسی‌ها و نتایج تاریخی را ثبت می‌کند.

## ساختار و منشأ

| مسیر | محتوا |
| --- | --- |
| `apps/desktop` | سورس Flutter، کد native ویندوز، تست‌ها، فونت‌ها و ابزار ساخت نصاب |
| `packages/core`, `data`, `ui`, `ai` | پکیج‌های لازم Nex با تغییرات مشترک نهایی |
| `patches` | دو patch برای اعمال تغییرات مشترک به checkout اصلی Nex |
| `HANDOFF.md`, `TEST_RESULTS.md` | گزارش تحویل و اعتبارسنجی نسخهٔ 0.10.0 |

Nex packages originate from [sanyzrn/DbsNex](https://github.com/sanyzrn/DbsNex), base `4861feac41530c951cb9e637ff921c6472d7de58`. Desktop shell uses the owner's extracted `right_panel_flutter.zip`; the original [raminturne/right-panel](https://github.com/raminturne/right-panel) at `90dcdbde8e33816f08b681c65cd341aa796f81e4` was a read-only reference. No changes were pushed to either upstream repository.

Nex notes/schema/repositories and shared design tokens remain the source of domain behaviour. AI is a removable stub; Windows reminders, backup restore UI, assistant/Vault and sync/OCR/on-device AI are absent or out of scope. See [desktop architecture and limitations](apps/desktop/README.md). Third-party attribution is in [THIRD_PARTY_NOTICES.md](apps/desktop/THIRD_PARTY_NOTICES.md); Nex uses the root MIT [LICENSE](LICENSE).
