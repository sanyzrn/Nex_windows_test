// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "native_startup.h"

#include <string>

namespace {
const wchar_t kRunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
const wchar_t kRunName[] = L"NexDesktop";
}

bool RegistryRunEnabled() {
  return RegGetValueW(HKEY_CURRENT_USER, kRunKey, kRunName, RRF_RT_REG_SZ,
                      nullptr, nullptr, nullptr) == ERROR_SUCCESS;
}

void RegistryRunSet(bool on) {
  if (!on) {
    RegDeleteKeyValueW(HKEY_CURRENT_USER, kRunKey, kRunName);
    return;
  }
  wchar_t exe[MAX_PATH * 2] = {};
  GetModuleFileNameW(nullptr, exe, ARRAYSIZE(exe));
  std::wstring value = L"\"";
  value += exe;
  value += L"\" --background";
  RegSetKeyValueW(HKEY_CURRENT_USER, kRunKey, kRunName, REG_SZ,
                  value.c_str(),
                  static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
}
