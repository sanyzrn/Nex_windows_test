#ifndef RUNNER_NATIVE_PRIVATE_H_
#define RUNNER_NATIVE_PRIVATE_H_
#include <windows.h>
#include <functional>
#include <string>

bool VerifyPrivateTools(HWND owner, const std::wstring& reason,
                        const std::function<bool(int)>& wait_or_stop);
bool SetPrivateClipboard(HWND owner, const std::wstring& text, DWORD* token);
bool ClipboardIsPrivate();
bool ClearPrivateClipboard(HWND owner, DWORD token);
#endif
