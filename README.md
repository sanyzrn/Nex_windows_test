# Nex Windows

نسخهٔ ویندوز **0.12.0+8** از Nex برای ویندوز، بر پایهٔ پروژهٔ Flutter دسکتاپ و معماری local-first.

## چه چیزهایی در 0.12.0 تازه است

این نسخه یک «دورِ کیفیت» است: تمرکز بر درست بودن، صداقت مستندات و زیبایی واقعی رابط، نه افزودن فهرست بلند قابلیت‌ها.

- **هم‌ترازی با نکس ۱.۹۳.۳:** پکیج‌های مشترک (`core`، `data`، `ui`، `ai`) با کد بالادستی در نشانی ثبت‌شده `b00fcddf50ddee90231f6753b4fed7d8b3a9e250` جایگزین شده‌اند؛ «کپی حفظ خطوط» در متن چندخطی (NexSelectableLines) و رنگ‌های خودکار برچسب‌ها (دوازده رنگ، کم‌استفاده‌ترین) اکنون مثل اندروید کار می‌کنند. دو پچ اشتراکی از نو تولید شده و روی همان نشانی بی‌خطا اعمال می‌شوند.
- **پردهٔ طراحی و بازطراحی رابط:** ماتریس کامل اسکرین‌شات (پنل و پنجره، دو زبان، دو پوسته و بیشتر، مقیاس متن ۱٫۰ و ۱٫۵) پیش و پس از تغییرها تولید و بررسی شده است. عنوان دوبارهٔ «تنظیمات»، پرش کارت پنل بین نماها، چیدمان شکستهٔ خواندن، نامرئی بودن دکمه‌های ثبت در پوستهٔ روشن، ایموجی نیمه‌بریده و ناسازگاری داک از جملهٔ ده‌ها عیب رفع‌شده‌اند.
- **توکن‌های نکس، بدون استثنا:** هیچ رنگ خام `Color(0x…)` و هیچ رشتهٔ انگلیسی هاردکد در `apps/desktop/lib` باقی نمانده؛ هر دو در CI بازرسی می‌شوند. رنگ «سبز زمردی» و رشتهٔ `No store` از جملهٔ حذف‌شده‌هاست.
- **بازسازی کد برای صداقت:** فایل‌های بالای ۵۰۰ خط به واحدهای منسجم تقسیم شده‌اند؛ این بار ادعای «ماژولار، زیر ۵۰۰ خط» واقعاً درست است و یک آزمون آن را نگه می‌دارد.
- **CI پاک:** آینهٔ `pub.flutter-io.cn` حذف شد؛ نسخهٔ Flutter با DbsNex هم‌تراز شده و گام‌های «سازگاری نسخه»، «بدون رشتهٔ هاردکد/رنگ خام» و «بارگذاری ماتریس اسکرین‌شات» به آن اضافه شده است.
- **پایه‌سنجی‌های طلاییِ درست‌تر:** گلدن‌های حالت پنجره (۱۲۰۰ پیکسل، دو زبان، دو پوسته) اضافه شده و مقایسه‌ها با سایهٔ واقعی انجام می‌شود.

## دریافت نسخهٔ آماده

- [نسخه‌های منتشرشده و نصاب ویندوز](https://github.com/sanyzrn/Nex_windows_test/releases)
- [SHA-256 نصاب](SHA256SUMS)

نصاب شامل تمام وابستگی‌های اجرایی است و برای کاربر جاری نصب می‌شود. پیش از به‌روزرسانی، Nex را ببندید. داده‌های یادداشت‌ها، رسانه‌ها، تنظیمات و یادآورهای زمان‌بندی‌شده با به‌روزرسانی حفظ می‌شوند (شناسهٔ نصاب و `Nex.Desktop.App` و مسیر داده‌ها تغییر نکرده‌اند). این نصاب آزمایشی امضای دیجیتال ندارد.

## سه چیز برای شروع

1. **ثبت سریع با کلید میان‌بر:** `Ctrl+Alt+N` را بزنید — پنل ثبت باز می‌شود، تایپ کنید و ببندید؛ همان لحظه ذخیره شده است.
2. **حالت پنجره و کتابخانه:** از نوار کناری «کتابخانه» را باز کنید؛ با `↑`/`↓` بین یادداشت‌ها حرکت کنید، با راست‌کلیک هر یادداشت کپی/سنجاق/یادآور/حذف را ببینید و با `Ctrl+K` هر چیزی را جست‌وجو کنید.
3. **پوسته و زبان:** در «تنظیمات» پوسته‌ای مثل «فیروزهٔ اصفهان» یا «نیمه‌شب» را امتحان کنید و زبان را روی فارسی بگذارید؛ همه‌جا راست‌به‌چپ، با ارقام فارسی و فونت وزیرمتن نمایش داده می‌شود.

## ساخت از سورس

این مخزن مستقل است: `apps/desktop` و هر چهار پکیج موردنیاز Nex در `packages` قرار دارند. تغییرات مشترک backup/theme از قبل اعمال شده‌اند؛ فایل‌های `patches` صرفاً برای تحویل به مخزن اصلی Nex نگه داشته شده‌اند و **در این مخزن نباید دوباره اعمال شوند**.

نیازمندی‌ها: ویندوز x64، Flutter **3.44.8** (همان نسخه‌ای که CI و `DbsNex` استفاده می‌کنند؛ حداقل 3.35.0 / Dart 3.9.0) و Visual Studio با workload توسعهٔ دسکتاپ C++.

```powershell
git clone https://github.com/sanyzrn/Nex_windows_test.git
cd Nex_windows_test/apps/desktop
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --release --no-pub
```

نکته: از نسخهٔ 0.12.0 دیگر نیازی به تنظیم `PUB_HOSTED_URL`/`FLUTTER_STORAGE_BASE_URL` روی آینهٔ چینی نیست؛ `pub.dev` پیش‌فرض استفاده می‌شود. برای اجرا از سورس: `flutter run -d windows`. خروجی `build/windows/x64/runner/Release` باید به‌صورت کامل توزیع شود. ساخت نصاب با Inno Setup در [راهنمای نصاب](apps/desktop/installer/README.md) توضیح داده شده است.

## ساختار و منشأ

| مسیر | محتوا |
| --- | --- |
| `apps/desktop` | سورس Flutter، کد native ویندوز، تست‌ها، فونت‌ها و ابزار ساخت نصاب |
| `packages/core`, `data`, `ui`, `ai` | پکیج‌های Nex از DbsNex در نشانی ثبت‌شدهٔ 0.12.0 با دو تغییر مشترک اعمال‌شده |
| `patches` | دو پچ مشترک، از نو تولیدشده روی نشانی ثبت‌شدهٔ بالادستی |
| `docs` | گزارش تحویل، راهنمای ادغام، نتایج تست و بایگانی |
| `design` | ماتریس اسکرین‌شات پیش/پس، گزارش ممیزی رابط، ایده‌ها و تصمیم‌های طراحی |
| `spec` | داده‌های مشترک آزمون انطباق مدل‌ها |

Nex packages originate from [sanyzrn/DbsNex](https://github.com/sanyzrn/DbsNex), base `b00fcddf50ddee90231f6753b4fed7d8b3a9e250` (Android 1.93.3). The earlier base `cb7b6f5bab5d7c75d256f9abe63b11f078776a34` (1.93.0) is what 0.11.0 actually vendored; 0.12.0 upgraded to `b00fcdd…` and regenerated both shared patches against it. Desktop shell uses the owner's extracted `right_panel_flutter.zip`; the original [raminturne/right-panel](https://github.com/raminturne/right-panel) at `90dcdbde8e33816f08b681c65cd341aa796f81e4` was a read-only reference. No changes were pushed to either upstream repository.

Nex notes/schema/repositories and shared design tokens remain the source of domain behaviour. Windows reminders and backup restore UI are implemented; assistant/Vault and sync/OCR/on-device AI remain absent or out of scope. See [desktop architecture and limitations](apps/desktop/README.md) and the [integration guide](docs/INTEGRATION.md). Third-party attribution is in [THIRD_PARTY_NOTICES.md](apps/desktop/THIRD_PARTY_NOTICES.md); Nex uses the root MIT [LICENSE](LICENSE).
