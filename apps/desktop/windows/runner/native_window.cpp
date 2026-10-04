// Copyright (c) 2026 Nex contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "native_window.h"
#include "native_common.h"

#include <flutter_windows.h>
#include <algorithm>

using flutter::EncodableMap;
using flutter::EncodableValue;

namespace {

typedef enum _ACCENT_STATE_BRIDGE {
  ACCENT_DISABLED_BRIDGE = 0,
  ACCENT_ENABLE_GRADIENT_BRIDGE = 1,
  ACCENT_ENABLE_TRANSPARENTGRADIENT_BRIDGE = 2,
} ACCENT_STATE_BRIDGE;

typedef struct _ACCENT_POLICY_BRIDGE {
  int nAccentState;
  int nFlags;
  int nColor;
  int nAnimationId;
} ACCENT_POLICY_BRIDGE;

typedef struct _WINCOMPATTRDATA_BRIDGE {
  int nAttribute;
  PVOID pData;
  ULONG ulDataSize;
} WINCOMPATTRDATA_BRIDGE;

}  // namespace

void SetWindowAccentTransparent(HWND hwnd, bool transparent) {
  const HINSTANCE user32 = LoadLibrary(TEXT("user32.dll"));
  if (user32 == nullptr) return;
  const auto set_window_composition_attribute =
      reinterpret_cast<BOOL(WINAPI*)(HWND, WINCOMPATTRDATA_BRIDGE*)>(
          GetProcAddress(user32, "SetWindowCompositionAttribute"));
  if (set_window_composition_attribute != nullptr) {
    ACCENT_POLICY_BRIDGE policy = {transparent
                                       ? ACCENT_ENABLE_TRANSPARENTGRADIENT_BRIDGE
                                       : ACCENT_DISABLED_BRIDGE,
                                   2, 0, 0};
    WINCOMPATTRDATA_BRIDGE data = {19, &policy, sizeof(policy)};
    set_window_composition_attribute(hwnd, &data);
  }
  FreeLibrary(user32);
}

std::vector<MonitorItem> CollectMonitors() {
  std::vector<MonitorItem> out;
  EnumDisplayMonitors(
      nullptr, nullptr,
      [](HMONITOR mon, HDC, LPRECT, LPARAM lparam) -> BOOL {
        auto* list = reinterpret_cast<std::vector<MonitorItem>*>(lparam);
        MONITORINFOEXW mi = {};
        mi.cbSize = sizeof(mi);
        if (GetMonitorInfoW(mon, &mi)) {
          list->push_back(MonitorItem{mon,
              mi.rcMonitor.left, mi.rcMonitor.top,
              mi.rcMonitor.right - mi.rcMonitor.left,
              mi.rcMonitor.bottom - mi.rcMonitor.top, std::wstring(mi.szDevice)});
        }
        return TRUE;
      },
      reinterpret_cast<LPARAM>(&out));
  return out;
}

void FocusWindowTarget(HWND window) {
  if (window == nullptr) return;
  if (IsIconic(window)) {
    ShowWindow(window, SW_RESTORE);
  } else if (!IsWindowVisible(window)) {
    ShowWindow(window, SW_SHOW);
  }
  SetForegroundWindow(window);
}

flutter::EncodableMap ComputePlacement(HWND window, const std::string& edge,
                                       int monitor, std::string& out_edge,
                                       std::wstring& out_display) {
  const auto monitors = CollectMonitors();
  EncodableMap out;
  if (monitors.empty()) return out;
  const size_t idx = monitor >= 0 && static_cast<size_t>(monitor) < monitors.size()
                         ? static_cast<size_t>(monitor)
                         : 0;
  const auto& m = monitors[idx];
  const UINT dpi = FlutterDesktopGetDpiForMonitor(m.handle);
  const double scale = dpi == 0 ? 1.0 : dpi / 96.0;
  const int w = static_cast<int>(480 * scale);
  const int h = static_cast<int>(680 * scale);
  const int hClamped = h < m.h ? h : m.h;
  const bool left = (edge == "left");
  out_edge = left ? "left" : "right";
  out_display = m.name;
  const int x = left ? m.x : (m.x + m.w - w);
  const int y = m.y + (m.h - hClamped) / 2;
  SetWindowPos(window, nullptr, x, y, w, hClamped,
               SWP_NOZORDER | SWP_NOACTIVATE);
  out[EncodableValue("x")] = EncodableValue(x);
  out[EncodableValue("y")] = EncodableValue(y);
  out[EncodableValue("w")] = EncodableValue(w);
  out[EncodableValue("h")] = EncodableValue(hClamped);
  out[EncodableValue("edgeX")] = EncodableValue(left ? m.x : m.x + m.w);
  out[EncodableValue("scale")] = EncodableValue(scale);
  out[EncodableValue("onLeft")] = EncodableValue(left);
  out[EncodableValue("monitor")] = EncodableValue(static_cast<int32_t>(idx));
  return out;
}

std::vector<flutter::EncodableMap> EnumerateScreens() {
  std::vector<flutter::EncodableMap> out;
  for (const auto& m : CollectMonitors()) {
    EncodableMap item;
    item[EncodableValue("name")] =
        EncodableValue(Utf8FromUtf16Inner(m.name.c_str()));
    item[EncodableValue("w")] = EncodableValue(m.w);
    item[EncodableValue("h")] = EncodableValue(m.h);
    out.push_back(std::move(item));
  }
  return out;
}
