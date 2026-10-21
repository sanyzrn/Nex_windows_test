#include "native_private.h"
#include <userconsentverifierinterop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Security.Credentials.UI.h>
#include <cstring>

bool VerifyPrivateTools(HWND owner, const std::wstring& reason,
                        const std::function<bool(int)>& wait_or_stop) {
  using namespace winrt::Windows::Security::Credentials::UI;
  using winrt::Windows::Foundation::AsyncStatus;
  using winrt::Windows::Foundation::IAsyncOperation;
  winrt::init_apartment(winrt::apartment_type::multi_threaded);
  bool verified = false;
  try {
    if (UserConsentVerifier::CheckAvailabilityAsync().get() ==
        UserConsentVerifierAvailability::Available) {
      auto interop = winrt::get_activation_factory<UserConsentVerifier,
                                                  IUserConsentVerifierInterop>();
      IAsyncOperation<UserConsentVerificationResult> operation{nullptr};
      const winrt::hstring message(reason);
      winrt::check_hresult(interop->RequestVerificationForWindowAsync(
          owner, winrt::get_abi(message), winrt::guid_of<decltype(operation)>(),
          winrt::put_abi(operation)));
      while (operation.Status() == AsyncStatus::Started) {
        if (wait_or_stop(100)) { operation.Cancel(); break; }
      }
      if (operation.Status() == AsyncStatus::Completed) {
        verified = operation.GetResults() == UserConsentVerificationResult::Verified;
      }
    }
  } catch (...) { /* Unavailable or cancelled: fail closed, never unlock. */ }
  winrt::uninit_apartment();
  return verified;
}

namespace {
UINT PrivateFormat() {
  return RegisterClipboardFormatW(L"ExcludeClipboardContentFromMonitorProcessing");
}
bool WriteDword(UINT format, DWORD value) {
  if (format == 0) return false;
  HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, sizeof(DWORD));
  if (!memory) return false;
  void* data = GlobalLock(memory);
  if (!data) { GlobalFree(memory); return false; }
  memcpy(data, &value, sizeof(value));
  GlobalUnlock(memory);
  if (!SetClipboardData(format, memory)) { GlobalFree(memory); return false; }
  return true;
}
}

bool SetPrivateClipboard(HWND owner, const std::wstring& text, DWORD* sequence) {
  if (text.empty() || text.size() > 10000 || !OpenClipboard(owner)) return false;
  EmptyClipboard();
  // Write the exclusion formats BEFORE the text, within the same clipboard lock.
  // A partial failure removes everything, rather than publishing a naked secret.
  bool ok = WriteDword(PrivateFormat(), 1) &&
      WriteDword(RegisterClipboardFormatW(L"CanIncludeInClipboardHistory"), 0) &&
      WriteDword(RegisterClipboardFormatW(L"CanUploadToCloudClipboard"), 0);
  if (ok) {
    const size_t bytes = (text.size() + 1) * sizeof(wchar_t);
    HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, bytes);
    void* data = memory ? GlobalLock(memory) : nullptr;
    if (data) {
      memcpy(data, text.c_str(), bytes);
      GlobalUnlock(memory);
      ok = SetClipboardData(CF_UNICODETEXT, memory) != nullptr;
      if (!ok) GlobalFree(memory);
    } else { if (memory) GlobalFree(memory); ok = false; }
  }
  if (!ok) EmptyClipboard();
  *sequence = GetClipboardSequenceNumber();
  CloseClipboard();
  return ok;
}

bool ClipboardIsPrivate() {
  // IsClipboardFormatAvailable does not require opening the clipboard.
  const UINT format = PrivateFormat();
  return format != 0 && IsClipboardFormatAvailable(format);
}

bool ClearPrivateClipboard(HWND owner, DWORD sequence) {
  if (!OpenClipboard(owner)) return false;
  const bool matches = GetClipboardSequenceNumber() == sequence && ClipboardIsPrivate();
  if (matches) EmptyClipboard();
  CloseClipboard();
  return matches;
}
