// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef RUNNER_NATIVE_WINDOW_H_
#define RUNNER_NATIVE_WINDOW_H_

#include <windows.h>
#include <string>
#include <vector>

#include <flutter/encodable_value.h>

struct MonitorItem {
  HMONITOR handle;
  int x, y, w, h;
  std::wstring name;
};

// The compact window: a tall portrait card that always opens at the same
// size, in the bottom-right corner of the work area (logical px).
constexpr int kCompactWindowWidth = 460;
constexpr int kCompactWindowHeight = 760;
constexpr int kCompactWindowMargin = 12;

std::vector<MonitorItem> CollectMonitors();
// Physical-px frame of the compact window on [monitor]'s work area.
RECT CompactWindowFrame(HMONITOR monitor);
void SetWindowAccentTransparent(HWND hwnd, bool transparent);
void FocusWindowTarget(HWND window);
flutter::EncodableMap ComputePlacement(HWND window, const std::string& edge,
                                       int monitor, std::string& out_edge,
                                       std::wstring& out_display);
std::vector<flutter::EncodableMap> EnumerateScreens();

#endif  // RUNNER_NATIVE_WINDOW_H_
