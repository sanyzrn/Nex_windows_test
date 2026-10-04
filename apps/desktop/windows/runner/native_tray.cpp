// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "native_tray.h"
#include "native_bridge.h"
#include "resource.h"

#include <shellapi.h>
#include <algorithm>
#include <cmath>

std::vector<uint8_t> TrayIconRgba() {
  // black liquid drop with a white ring, 32x32 — port of util::tray_rgba().
  std::vector<uint8_t> px(32 * 32 * 4, 0);
  for (int y = 0; y < 32; y++) {
    for (int x = 0; x < 32; x++) {
      const float dx = static_cast<float>(x) - 15.5f;
      const float dy = static_cast<float>(y) - 15.5f;
      const float d = std::sqrt(dx * dx + dy * dy);
      const size_t i = (static_cast<size_t>(y) * 32 + x) * 4;
      const float edge = std::min(std::max(15.5f - d, 0.0f), 1.0f);
      if (edge > 0.0f) {
        const float ringRaw = 1.0f - (std::abs(d - 8.0f) - 1.4f);
        const float ring = std::min(std::max(ringRaw, 0.0f), 1.0f);
        const uint8_t v = static_cast<uint8_t>(ring * 255);
        px[i] = v;
        px[i + 1] = v;
        px[i + 2] = v;
        px[i + 3] = static_cast<uint8_t>(edge * 255);
      }
    }
  }
  return px;
}

bool CreateTrayIcon(HWND window, HICON& tray_icon, HMENU& tray_menu, bool startup_enabled) {
  if (tray_icon != nullptr) DestroyIcon(tray_icon);
  if (tray_menu != nullptr) DestroyMenu(tray_menu);
  tray_menu = nullptr;
  tray_icon = CopyIcon(LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON)));
  if (tray_icon == nullptr) {
    tray_icon = LoadIconW(nullptr, IDI_APPLICATION);
  }
  if (tray_icon == nullptr) return false;

  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = window;
  nid.uID = 1;
  nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  nid.uCallbackMessage = WM_APP_TRAY;
  nid.hIcon = tray_icon;
  wcscpy_s(nid.szTip, L"Nex");
  bool added = Shell_NotifyIconW(NIM_ADD, &nid) != FALSE;
  if (!added) {
    Shell_NotifyIconW(NIM_DELETE, &nid);
    added = Shell_NotifyIconW(NIM_ADD, &nid) != FALSE;
  }
  if (!added) {
    added = (tray_icon != nullptr);
  }

  tray_menu = CreatePopupMenu();
  AppendMenuW(tray_menu, MF_STRING, IDM_TRAY_OPEN, L"Nex");
  AppendMenuW(tray_menu, MF_STRING, IDM_TRAY_SETTINGS, L"Nex");
  AppendMenuW(tray_menu, MF_STRING, IDM_TRAY_ADDAPP, L"Nex");
  AppendMenuW(tray_menu, MF_SEPARATOR, 0, nullptr);
  UINT flag = MF_STRING | (startup_enabled ? MF_CHECKED : 0);
  AppendMenuW(tray_menu, flag, IDM_TRAY_STARTUP, L"Nex");
  AppendMenuW(tray_menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(tray_menu, MF_STRING, IDM_TRAY_QUIT, L"Nex");
  return added;
}

void RemoveTrayIcon(HWND window, HICON& tray_icon, HMENU& tray_menu, bool& tray_added) {
  if (tray_added) {
    NOTIFYICONDATAW nid = {};
    nid.cbSize = sizeof(nid);
    nid.hWnd = window;
    nid.uID = 1;
    Shell_NotifyIconW(NIM_DELETE, &nid);
    tray_added = false;
  }
  if (tray_icon != nullptr) {
    DestroyIcon(tray_icon);
    tray_icon = nullptr;
  }
  if (tray_menu != nullptr) {
    DestroyMenu(tray_menu);
    tray_menu = nullptr;
  }
}

void ShowTrayContextMenu(HWND window, HMENU tray_menu, bool startup_enabled) {
  if (tray_menu == nullptr) return;
  CheckMenuItem(tray_menu, IDM_TRAY_STARTUP,
                startup_enabled ? MF_CHECKED : MF_UNCHECKED);
  POINT p{};
  GetCursorPos(&p);
  SetForegroundWindow(window);
  TrackPopupMenu(tray_menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN, p.x, p.y, 0,
                 window, nullptr);
  PostMessage(window, WM_NULL, 0, 0);
}
