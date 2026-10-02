#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include "flutter_window.h"
#include "native_bridge.h"
#include "utils.h"

// Nex: a liquid side panel that lives on the edge of the screen.
// The window is created borderless, always-on-top, transparent and
// click-through (the bridge toggles that), positioned on the right edge of
// the primary monitor; Dart corrects the placement from saved settings
// before the first frame is shown.
int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Only one copy runs at a time (same as the original).
  HANDLE mutex =
      ::CreateMutexW(nullptr, TRUE, L"Local\\NexDesktopSingleton");
  if (mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    if (wcsstr(GetCommandLineW(), L"--native-smoke") == nullptr) {
      const HWND existing = FindWindowW(L"RIGHT_PANEL_WIN32_WINDOW", L"Nex");
      if (existing != nullptr) {
        DWORD owner = 0;
        GetWindowThreadProcessId(existing, &owner);
        AllowSetForegroundWindow(owner);
        PostMessageW(existing, WM_APP_SHOW, 0, 0);
      }
    }
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Initial placement: right edge, vertically centered, on the primary
  // monitor (physical pixels; saved settings may move it right after).
  const POINT zero{0, 0};
  HMONITOR monitor =
      ::MonitorFromPoint(zero, MONITOR_DEFAULTTOPRIMARY);
  MONITORINFO info;
  info.cbSize = sizeof(MONITORINFO);
  ::GetMonitorInfo(monitor, &info);
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const double scale = dpi == 0 ? 1.0 : dpi / 96.0;
  const int panel_w = static_cast<int>(480 * scale);
  int panel_h = static_cast<int>(680 * scale);
  const int mon_h = info.rcMonitor.bottom - info.rcMonitor.top;
  if (panel_h > mon_h) panel_h = mon_h;
  const int x = info.rcMonitor.right - panel_w;
  const int y = info.rcMonitor.top + (mon_h - panel_h) / 2;

  FlutterWindow window(project);
  Win32Window::Point origin(x, y);
  Win32Window::Size size(panel_w, panel_h);
  if (!window.Create(L"Nex", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
