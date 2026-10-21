#include <windows.h>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include "../windows/runner/native_private.h"

namespace {
void Check(bool value, const char* stage) {
  if (!value) throw std::runtime_error(stage);
}
DWORD ClipboardDword(const wchar_t* name) {
  const HANDLE memory = GetClipboardData(RegisterClipboardFormatW(name));
  Check(memory && GlobalSize(memory) >= sizeof(DWORD), "clipboard flag missing");
  const void* data = GlobalLock(memory);
  Check(data != nullptr, "clipboard flag unreadable");
  DWORD value;
  std::memcpy(&value, data, sizeof(value));
  GlobalUnlock(memory);
  return value;
}
}

int main() {
  HWND owner = CreateWindowExW(0, L"STATIC", L"Nex synthetic clipboard test",
      WS_OVERLAPPED, 0, 0, 1, 1, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  if (!owner) return 2;
  int result = 0;
  try {
    DWORD first = 0, second = 0;
    Check(SetPrivateClipboard(owner, L"Synthetic secret", &first), "private write");
    Check(ClipboardIsPrivate(), "Nex history exclusion");
    Check(OpenClipboard(owner), "open flags");
    Check(ClipboardDword(L"ExcludeClipboardContentFromMonitorProcessing") == 1,
          "monitor exclusion flag");
    Check(ClipboardDword(L"CanIncludeInClipboardHistory") == 0, "history flag");
    Check(ClipboardDword(L"CanUploadToCloudClipboard") == 0, "cloud flag");
    Check(GetClipboardData(CF_TEXT) != nullptr, "synthesize ANSI text");
    CloseClipboard();
    Check(ClearPrivateClipboard(owner, first), "clear after text conversion");
    Check(!ClipboardIsPrivate(), "cleared item absent");

    Check(SetPrivateClipboard(owner, L"Synthetic first", &first), "first write");
    Check(SetPrivateClipboard(owner, L"Synthetic second", &second), "replacement write");
    Check(first != second, "distinct copy identities");
    Check(!ClearPrivateClipboard(owner, first), "old cleanup preserves replacement");
    Check(ClipboardIsPrivate(), "replacement retained");
    Check(ClearPrivateClipboard(owner, second), "current cleanup succeeds");
    Check(!ClearPrivateClipboard(owner, second), "cleanup cannot repeat");
    std::cout << "Native private clipboard: conversion, exclusion and replacement checks passed.\n";
  } catch (const std::exception& error) {
    std::cerr << "Native private clipboard failed: " << error.what()
              << " (Win32 " << GetLastError() << ")\n";
    result = 1;
  }
  CloseClipboard();
  if (OpenClipboard(owner)) { EmptyClipboard(); CloseClipboard(); }
  DestroyWindow(owner);
  return result;
}
