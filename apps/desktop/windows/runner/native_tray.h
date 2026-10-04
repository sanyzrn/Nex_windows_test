// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef RUNNER_NATIVE_TRAY_H_
#define RUNNER_NATIVE_TRAY_H_

#include <windows.h>
#include <cstdint>
#include <vector>

std::vector<uint8_t> TrayIconRgba();
bool CreateTrayIcon(HWND window, HICON& tray_icon, HMENU& tray_menu, bool startup_enabled);
void RemoveTrayIcon(HWND window, HICON& tray_icon, HMENU& tray_menu, bool& tray_added);
void ShowTrayContextMenu(HWND window, HMENU tray_menu, bool startup_enabled);

#endif  // RUNNER_NATIVE_TRAY_H_
