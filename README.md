# Nex Windows test

نسخهٔ نهایی **1.92.1+4** از Nex برای ویندوز، بر پایهٔ پروژهٔ Flutter Right Panel.

## دریافت نسخهٔ آماده

- [نصاب ویندوز x64 — 1.92.1.4](https://github.com/sanyzrn/Nex_windows_test/releases/download/v1.92.1.4/Nex-Windows-Setup-1.92.1.4-x64.exe)
- [ZIP سورس و گزارش تحویل](releases/1.92.1.4/nex-desktop-2026-10-02.zip)
- [SHA-256 فایل‌ها](releases/1.92.1.4/SHA256SUMS)

فایل نصبی از GitHub Release دریافت می‌شود، شامل تمام وابستگی‌های اجرایی است و برای کاربر جاری نصب می‌شود. برای دریافت ZIP از صفحهٔ فایل GitHub، گزینهٔ **Download raw file** را بزنید. پیش از به‌روزرسانی، Nex را ببندید. داده‌های یادداشت‌ها با به‌روزرسانی حفظ می‌شوند. این نصاب آزمایشی امضای دیجیتال ندارد.

## ساخت از سورس

این مخزن مستقل است: `apps/desktop` و هر چهار پکیج موردنیاز Nex در `packages` قرار دارند. تغییرات مشترک backup/theme از قبل اعمال شده‌اند؛ فایل‌های `patches` صرفاً برای تحویل به مخزن اصلی Nex نگه داشته شده‌اند و **در این مخزن نباید دوباره اعمال شوند**.

نیازمندی‌ها: ویندوز x64، Flutter **3.35.5 / Dart 3.9.2** و Visual Studio با workload توسعهٔ دسکتاپ C++.

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

- پین مستقل پنل برای باز ماندن آن؛ محافظت از تایپ، مطالعه، منو، انتخاب فایل و ضبط در برابر بسته‌شدن خودکار.
- اصلاح دریافت کلیک در پایین پنلِ جابه‌جاشده، انتخابگرهای مجزای تصویر/صوت/فایل و پیام صحیح لغو یا خطا.
- نمایش درون پنل برای خواندن و ویرایش یادداشت، آیکون‌ها و فاصله‌های هماهنگ، سایه‌های ملایم‌تر.
- اصلاح پخش صوت ویندوز، کنترل پایان پخش و ضبط WAV.

اعتبارسنجی تحویل: **32 تست و 10 golden comparison**، analyzer بدون ایراد، ساخت Release و نصاب، باز شدن انتخابگر تصویر با کلیک واقعی، و واردکردن/بازکردن تصویر و پخش WAV دوثانیه‌ای تا پایان در برنامهٔ native ویندوز. ضبط میکروفون، مانیتورهای mixed-DPI و اهداف کارایی هنوز تست واقعی کامل ندارند. [گزارش تست](TEST_RESULTS.md) حدود دقیق بررسی‌ها و نتایج تاریخی را ثبت می‌کند.

## ساختار و منشأ

| مسیر | محتوا |
| --- | --- |
| `apps/desktop` | سورس Flutter، کد native ویندوز، تست‌ها، فونت‌ها و ابزار ساخت نصاب |
| `packages/core`, `data`, `ui`, `ai` | پکیج‌های لازم Nex با تغییرات مشترک نهایی |
| `patches` | دو patch برای اعمال تغییرات مشترک به checkout اصلی Nex |
| `HANDOFF.md`, `TEST_RESULTS.md` | گزارش تحویل و اعتبارسنجی نسخهٔ 1.92.1.4 |
| `releases/1.92.1.4` | ZIP نهایی سورس و checksum هر دو فایل تحویلی؛ نصاب در GitHub Release قرار می‌گیرد |

Nex packages originate from [sanyzrn/DbsNex](https://github.com/sanyzrn/DbsNex), base `4861feac41530c951cb9e637ff921c6472d7de58`. Desktop shell uses the owner's extracted `right_panel_flutter.zip`; the original [raminturne/right-panel](https://github.com/raminturne/right-panel) at `90dcdbde8e33816f08b681c65cd341aa796f81e4` was a read-only reference. No changes were pushed to either upstream repository.

Nex notes/schema/repositories and shared design tokens remain the source of domain behaviour. AI is a removable stub; Windows reminders, backup restore UI, assistant/Vault and sync/OCR/on-device AI are absent or out of scope. See [desktop architecture and limitations](apps/desktop/README.md). Third-party attribution is in [THIRD_PARTY_NOTICES.md](apps/desktop/THIRD_PARTY_NOTICES.md); Nex uses the root MIT [LICENSE](LICENSE).
