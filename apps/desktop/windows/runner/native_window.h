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

std::vector<MonitorItem> CollectMonitors();
void SetWindowAccentTransparent(HWND hwnd, bool transparent);
void FocusWindowTarget(HWND window);
flutter::EncodableMap ComputePlacement(HWND window, const std::string& edge,
                                       int monitor, std::string& out_edge,
                                       std::wstring& out_display);
std::vector<flutter::EncodableMap> EnumerateScreens();

#endif  // RUNNER_NATIVE_WINDOW_H_
