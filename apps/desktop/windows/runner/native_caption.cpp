#include "native_bridge.h"
#include <windowsx.h>

std::optional<LRESULT> NativeBridge::FrameMessage(HWND hwnd, UINT message,
                                                WPARAM wparam, LPARAM lparam) {
  if (!window_mode_) return std::nullopt;
  if (message == WM_GETMINMAXINFO && hwnd == window_) {
    // This must run before Flutter/plugins can consume the sizing message.
    if (OnMessage(hwnd, message, wparam, lparam)) return 0;
  }
  if (message == WM_NCCALCSIZE && hwnd == window_) {
    if (wparam && IsZoomed(window_)) {
      auto* size = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
      MONITORINFO monitor{};
      monitor.cbSize = sizeof(monitor);
      if (GetMonitorInfo(MonitorFromRect(&size->rgrc[0], MONITOR_DEFAULTTONEAREST), &monitor)) {
        size->rgrc[0] = monitor.rcWork;
      }
    }
    return 0;
  }
  if (message == WM_NCHITTEST && !IsZoomed(window_)) {
    RECT rect{};
    GetWindowRect(window_, &rect);
    const UINT dpi = GetDpiForWindow(window_);
    const int border = GetSystemMetricsForDpi(SM_CXSIZEFRAME, dpi) +
                       GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
    const int x = GET_X_LPARAM(lparam), y = GET_Y_LPARAM(lparam);
    const bool left = x < rect.left + border, right = x >= rect.right - border;
    const bool top = y < rect.top + border, bottom = y >= rect.bottom - border;
    LRESULT hit = HTCLIENT;
    if (top) hit = left ? HTTOPLEFT : right ? HTTOPRIGHT : HTTOP;
    else if (bottom) hit = left ? HTBOTTOMLEFT : right ? HTBOTTOMRIGHT : HTBOTTOM;
    else if (left) hit = HTLEFT;
    else if (right) hit = HTRIGHT;
    if (hit != HTCLIENT) return hwnd == window_ ? hit : HTTRANSPARENT;
  }
  if (message == WM_SIZE && hwnd == window_ && wparam != SIZE_MINIMIZED) {
    PostEvent("windowState", flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("maximized"), flutter::EncodableValue(IsZoomed(window_) != FALSE)}}));
  }
  return std::nullopt;
}

void NativeBridge::WindowCommand(const std::string& command) {
  if (!window_mode_) return;
  if (command == "drag") {
    ReleaseCapture();
    SendMessage(window_, WM_NCLBUTTONDOWN, HTCAPTION, 0);
  } else if (command == "minimize") {
    ShowWindow(window_, SW_MINIMIZE);
  } else if (command == "maximize") {
    ShowWindow(window_, IsZoomed(window_) ? SW_RESTORE : SW_MAXIMIZE);
  } else if (command == "close") {
    PostMessage(window_, WM_CLOSE, 0, 0);
  } else if (command == "menu") {
    POINT point{};
    GetCursorPos(&point);
    const UINT selected = TrackPopupMenu(GetSystemMenu(window_, FALSE), TPM_RETURNCMD | TPM_RIGHTBUTTON, point.x, point.y, 0, window_, nullptr);
    if (selected) PostMessage(window_, WM_SYSCOMMAND, selected, 0);
  }
}
