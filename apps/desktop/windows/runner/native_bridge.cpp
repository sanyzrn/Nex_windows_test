// Native bridge: the central dispatcher of the Windows runner.
// Ports the original src/sys/windows.rs platform layer.
// Specific subsystems are factored into:
// - native_common: UTF conversions, encodables, and crypto/compression helpers
// - native_startup: Windows Registry Run autorun registration
// - native_hotkeys: Input simulation and global hotkey combinations
// - native_tray: System tray icon and context menu
// - native_window: Multi-monitor enumeration, placement, DPI, and window styling
// - native_clipboard: Clipboard text, DIB/PNG image read/write, and downscaling
// - native_pickers: Windows Shell file open dialogs and shell icon extraction

#include "native_bridge.h"
#include "native_common.h"
#include "native_startup.h"
#include "native_hotkeys.h"
#include "native_tray.h"
#include "native_window.h"
#include "native_clipboard.h"
#include "native_pickers.h"
#include "native_notifications.h"
#include "resource.h"

#include <windows.h>
#include <commctrl.h>
#include <commdlg.h>
#include <shellapi.h>
#include <shlobj.h>
#include <shobjidl_core.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cmath>
#include <thread>
#include <flutter_windows.h>

namespace {
using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

std::atomic<uint64_t> g_last_image_id{0};
}  // namespace

// ================= bridge lifecycle =================

NativeBridge::NativeBridge(HWND window, flutter::FlutterViewController* controller)
    : window_(window),
      channel_(controller->engine()->messenger(), "rp/native",
               &flutter::StandardMethodCodec::GetInstance()) {
  channel_.SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
  taskbar_created_msg_ = RegisterWindowMessageW(L"TaskbarCreated");
}

NativeBridge::~NativeBridge() {
  // Disable callbacks first, then cancel, close worker dialogs and join.
  channel_.SetMethodCallHandler(nullptr);
  stopping_.store(true);
  stop_cv_.notify_all();
  UnregisterHotKey(window_, 1);
  for (auto& worker : workers_) {
    EnumThreadWindows(GetThreadId(worker.thread.native_handle()),
      [](HWND dialog, LPARAM) -> BOOL {
        PostMessage(dialog, WM_CLOSE, 0, 0); return TRUE;
      }, 0);
  }
  for (auto& worker : workers_) if (worker.thread.joinable()) worker.thread.join();
  { std::lock_guard<std::mutex> lock(events_mutex_); pending_events_.clear(); }
  RemoveTray();
}

bool NativeBridge::WaitOrStop(int milliseconds) {
  std::unique_lock<std::mutex> lock(stop_mutex_);
  return stop_cv_.wait_for(lock, std::chrono::milliseconds(milliseconds),
    [this] { return stopping_.load(); });
}

void NativeBridge::RunWorker(std::function<void()> work) {
  if (stopping_) return;
  // Called on the platform thread only. Reap completed tasks to bound handles.
  for (auto it = workers_.begin(); it != workers_.end();) {
    if (it->done->load()) { it->thread.join(); it = workers_.erase(it); }
    else ++it;
  }
  auto done = std::make_shared<std::atomic<bool>>(false);
  workers_.push_back({std::thread([work = std::move(work), done]() {
    try { work(); } catch (...) { /* Native task must not unwind a thread. */ }
    done->store(true);
  }), done});
}

void NativeBridge::Start() {
  SetPassthrough(true);
  CreateTray();
  hotkey_registered_ = RegisterHotKey(window_, 1, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, 'N') != FALSE;
}

void NativeBridge::NotifyBlur() {
  if (!picking_) PostEvent("blur", EncodableValue());
}

void NativeBridge::PostEvent(const std::string& method, EncodableValue args) {
  {
    std::lock_guard<std::mutex> lock(events_mutex_);
    if (stopping_) return;
    pending_events_.emplace_back(method, std::move(args));
  }
  PostMessage(window_, WM_APP_EVENT, 0, 0);
}

void NativeBridge::DrainEvents() {
  std::lock_guard<std::mutex> lock(events_mutex_);
  while (!pending_events_.empty()) {
    auto [method, args] = std::move(pending_events_.front());
    pending_events_.pop_front();
    channel_.InvokeMethod(method, std::make_unique<EncodableValue>(std::move(args)));
  }
}

// ================= method calls =================

void NativeBridge::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto* raw_args = call.arguments();
  const auto* args = raw_args ? std::get_if<EncodableMap>(raw_args) : nullptr;
  const std::string& name = call.method_name();

  if (name == "readClipboardImage") {
    ReadClipboardImage(ArgInt(args, "request"));
    result->Success();
  } else if (name == "labels") {
    add_app_title_ = Utf16FromUtf8(ArgString(args, "addApp"));
    folder_title_ = Utf16FromUtf8(ArgString(args, "addFolder"));
    apps_label_ = Utf16FromUtf8(ArgString(args, "apps"));
    files_label_ = Utf16FromUtf8(ArgString(args, "files"));
    const std::pair<UINT, const char*> entries[] = {
      {IDM_TRAY_OPEN, "open"}, {IDM_TRAY_SETTINGS, "settings"},
      {IDM_TRAY_ADDAPP, "addApp"}, {IDM_TRAY_STARTUP, "startup"}, {IDM_TRAY_QUIT, "quit"}};
    for (const auto& entry : entries) {
      const auto label = Utf16FromUtf8(ArgString(args, entry.second));
      ModifyMenuW(tray_menu_, entry.first, MF_BYCOMMAND | MF_STRING, entry.first, label.c_str());
    }
    result->Success();
  } else if (name == "diagnostics") {
    result->Success(EncodableValue(EncodableMap{
      {EncodableValue("tray"), EncodableValue(tray_added_)},
      {EncodableValue("hotkey"), EncodableValue(hotkey_registered_)},
      {EncodableValue("workers"), EncodableValue(static_cast<int32_t>(workers_.size()))},
      {EncodableValue("monitors"), EncodableValue(static_cast<int32_t>(CollectMonitors().size()))}}));
  } else if (name == "probeDisplayChange") {
    PostMessage(window_, WM_DISPLAYCHANGE, 0, 0);
    result->Success();
  } else if (name == "probeCursor") {
    SetCursorPos(ArgInt(args, "x"), ArgInt(args, "y"));
    result->Success();
  } else if (name == "probeHotkey") {
    if (hotkey_registered_) {
      SendCombo({VK_CONTROL, VK_MENU, static_cast<WORD>(hotkey_vk_)});
      PostMessage(window_, WM_HOTKEY, 1, 0);
    }
    result->Success(EncodableValue(hotkey_registered_));
  } else if (name == "hotkey") {
    const auto key = ArgString(args, "key");
    const UINT vk = key == "Space" ? VK_SPACE : (key.size() == 1 ? static_cast<UINT>(key[0]) : 0);
    if (vk == 0) { result->Success(EncodableValue(false)); return; }
    if (vk == hotkey_vk_ && hotkey_registered_) { result->Success(EncodableValue(true)); return; }
    // Register the candidate first. An occupied combination keeps the old hotkey.
    if (!RegisterHotKey(window_, 2, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, vk)) {
      result->Success(EncodableValue(false)); return;
    }
    UnregisterHotKey(window_, 1);
    UnregisterHotKey(window_, 2);
    hotkey_registered_ = RegisterHotKey(window_, 1, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, vk) != FALSE;
    if (hotkey_registered_) hotkey_vk_ = vk;
    result->Success(EncodableValue(hotkey_registered_));
  } else if (name == "setPassthrough") {
    SetPassthrough(ArgBool(args, "on"));
    result->Success();
  } else if (name == "rememberForeground") {
    RememberForeground();
    result->Success();
  } else if (name == "pasteIntoPrevious") {
    PasteIntoPrevious(ArgString(args, "text"));
    result->Success();
  } else if (name == "pressKey") {
    PressKey(ArgString(args, "name"));
    result->Success();
  } else if (name == "pinWindow") {
    result->Success(EncodableValue(PinWindow()));
  } else if (name == "lock") {
    LockWorkStation();
    result->Success();
  } else if (name == "screenOff") {
    RunWorker([this]() {
      if (WaitOrStop(600)) return;
      PostMessage(window_, WM_SYSCOMMAND, SC_MONITORPOWER, 2);
    });
    result->Success();
  } else if (name == "beep") {
    MessageBeep(MB_ICONASTERISK);
    result->Success();
  } else if (name == "keepAwake") {
    const bool on = ArgBool(args, "on");
    SetThreadExecutionState(on ? ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
                               : ES_CONTINUOUS);
    result->Success();
  } else if (name == "screenshot") {
    RunWorker([this]() {
      if (WaitOrStop(350)) return;
      ShellExecuteW(nullptr, L"open", L"explorer.exe", L"ms-screenclip:",
                    nullptr, SW_SHOWNORMAL);
    });
    result->Success();
  } else if (name == "launch") {
    Launch(ArgString(args, "target"));
    result->Success();
  } else if (name == "pickColor") {
    PickColor();
    result->Success();
  } else if (name == "pickCustomColor") {
    PickCustomColor(ArgString(args, "current"));
    result->Success();
  } else if (name == "pickApp") {
    PickApp(ArgBool(args, "folder"));
    result->Success();
  } else if (name == "appIcon") {
    AppIconFor(ArgString(args, "id"), ArgString(args, "path"));
    result->Success();
  } else if (name == "startupEnabled") {
    result->Success(EncodableValue(StartupRegistryEnabled()));
  } else if (name == "setStartup") {
    SetStartupRegistry(ArgBool(args, "on"));
    result->Success();
  } else if (name == "quit") {
    quit_requested_ = true;
    PostMessage(window_, WM_CLOSE, 0, 0);
    result->Success();
  } else if (name == "setClipboardImage") {
    SetClipboardImage(ArgInt(args, "w"), ArgInt(args, "h"), ArgBytes(args, "rgba"));
    result->Success();
  } else if (name == "applyPlacement") {
    result->Success(EncodableValue(ApplyPlacement(ArgString(args, "edge"),
                                                  ArgInt(args, "monitor"))));
  } else if (name == "setWindowMode") {
    const auto mode = ArgString(args, "mode");
    SetWindowMode(mode, ArgInt(args, "x"), ArgInt(args, "y"),
                  ArgInt(args, "w"), ArgInt(args, "h"),
                  ArgBool(args, "maximized"), ArgBool(args, "show"));
    result->Success();
  } else if (name == "windowFrame") {
    result->Success(EncodableValue(WindowFrame()));
  } else if (name == "focusWindow") {
    FocusWindow();
    result->Success();
  } else if (name == "screens") {
    EncodableList list;
    for (auto& m : Screens()) list.push_back(EncodableValue(m));
    result->Success(EncodableValue(list));
  } else if (name == "ready") {
    StartClipboardWatch();
    result->Success();
  } else if (name == "scheduleReminder") {
    const bool ok = ScheduleToastNotification(
        ArgString(args, "id"),
        ArgString(args, "noteId"),
        ArgString(args, "title"),
        ArgString(args, "body"),
        ArgInt64(args, "fireAt"));
    result->Success(EncodableValue(ok));
  } else if (name == "cancelReminder") {
    const bool ok = CancelScheduledToastNotification(ArgString(args, "id"));
    result->Success(EncodableValue(ok));
  } else if (name == "showOverdueReminder") {
    const bool ok = ShowImmediateToast(
        ArgString(args, "id"),
        ArgString(args, "noteId"),
        ArgString(args, "title"),
        ArgString(args, "body"));
    result->Success(EncodableValue(ok));
  } else if (name == "listScheduledReminders") {
    const auto ids = ListScheduledToastIds();
    EncodableList list;
    for (const auto& id : ids) {
      list.push_back(EncodableValue(id));
    }
    result->Success(EncodableValue(list));
  } else {
    result->NotImplemented();
  }
}

// ================= window plumbing =================

void NativeBridge::SetPassthrough(bool on) {
  passthrough_ = !window_mode_ && on;
  if (window_mode_) {
    if (!on) FocusWindow();
    return;
  }
  LONG ex = GetWindowLong(window_, GWL_EXSTYLE);
  ex &= ~(WS_EX_TRANSPARENT | WS_EX_LAYERED | WS_EX_TOOLWINDOW);
  ex |= WS_EX_APPWINDOW;
  SetWindowLong(window_, GWL_EXSTYLE, ex);
  SetWindowPos(window_, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
  ShowWindow(window_, on ? SW_HIDE : SW_SHOWNOACTIVATE);
}

void NativeBridge::SetWindowMode(const std::string& mode, int x, int y, int w,
                                  int h, bool maximized, bool show) {
  const bool to_window = (mode == "window");
  window_mode_ = to_window;
  if (!to_window) {
    passthrough_ = true;
    SetWindowAccentTransparent(window_, true);
    SetWindowLong(window_, GWL_STYLE, WS_POPUP);
    LONG ex = GetWindowLong(window_, GWL_EXSTYLE);
    ex |= WS_EX_TOOLWINDOW | WS_EX_TOPMOST;
    ex &= ~WS_EX_APPWINDOW;
    SetWindowLong(window_, GWL_EXSTYLE, ex);
    SetWindowPos(window_, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
    ShowWindow(window_, SW_HIDE);
    return;
  }

  passthrough_ = false;
  SetWindowAccentTransparent(window_, false);
  SetWindowLong(window_, GWL_STYLE, WS_OVERLAPPEDWINDOW);
  LONG ex = GetWindowLong(window_, GWL_EXSTYLE);
  ex &= ~(WS_EX_TOOLWINDOW | WS_EX_TOPMOST | WS_EX_TRANSPARENT | WS_EX_LAYERED);
  ex |= WS_EX_APPWINDOW;
  SetWindowLong(window_, GWL_EXSTYLE, ex);

  const auto monitors = CollectMonitors();
  const bool saved = w >= 320 && h >= 320 && x > -32000 && y > -32000;
  bool placed = false;
  if (saved && !monitors.empty()) {
    const RECT frame{x, y, x + w, y + h};
    for (const auto& m : monitors) {
      const RECT area{m.x, m.y, m.x + m.w, m.y + m.h};
      RECT hit{};
      if (IntersectRect(&hit, &frame, &area) &&
          hit.right - hit.left >= 100 && hit.bottom - hit.top >= 100) {
        placed = true;
        w = std::min(w, m.w);
        h = std::min(h, m.h);
        x = std::max(m.x, std::min(x, m.x + m.w - w));
        y = std::max(m.y, std::min(y, m.y + m.h - 60));
        break;
      }
    }
  }
  if (!placed) {
    HMONITOR primary = MonitorFromWindow(window_, MONITOR_DEFAULTTOPRIMARY);
    MONITORINFO mi = {};
    mi.cbSize = sizeof(mi);
    if (GetMonitorInfo(primary, &mi)) {
      const UINT dpi = FlutterDesktopGetDpiForMonitor(primary);
      const double scale = dpi == 0 ? 1.0 : dpi / 96.0;
      const RECT& work = mi.rcWork;
      w = static_cast<int>(1180 * scale);
      h = static_cast<int>(780 * scale);
      w = std::min<int>(w, (work.right - work.left) * 9 / 10);
      h = std::min<int>(h, (work.bottom - work.top) * 9 / 10);
      x = work.left + ((work.right - work.left) - w) / 2;
      y = work.top + ((work.bottom - work.top) - h) / 2;
    } else {
      w = std::max(w, 1180);
      h = std::max(h, 780);
      x = 60;
      y = 60;
    }
  }

  SetWindowPos(window_, HWND_NOTOPMOST, x, y, w, h,
               SWP_NOACTIVATE | SWP_FRAMECHANGED);
  if (maximized) {
    if (first_frame_done_) {
      ShowWindow(window_, SW_MAXIMIZE);
      SetForegroundWindow(window_);
    } else {
      pending_show_ = true;
      pending_show_maximized_ = true;
    }
  } else if (show) {
    if (first_frame_done_) {
      ShowWindow(window_, SW_SHOW);
      SetForegroundWindow(window_);
    } else {
      pending_show_ = true;
      pending_show_maximized_ = false;
    }
  } else {
    ShowWindow(window_, SW_HIDE);
  }
}

void NativeBridge::OnFirstFrame() {
  first_frame_done_ = true;
  if (window_mode_ && pending_show_) {
    pending_show_ = false;
    ShowWindow(window_, pending_show_maximized_ ? SW_MAXIMIZE : SW_SHOW);
    SetForegroundWindow(window_);
  }
}

flutter::EncodableMap NativeBridge::WindowFrame() const {
  const bool zoomed = IsZoomed(window_) != FALSE;
  RECT r{};
  if (zoomed) {
    WINDOWPLACEMENT wp = {};
    wp.length = sizeof(wp);
    GetWindowPlacement(window_, &wp);
    HMONITOR mon = MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi = {};
    mi.cbSize = sizeof(mi);
    POINT offset{0, 0};
    if (GetMonitorInfo(mon, &mi)) {
      offset.x = mi.rcWork.left - mi.rcMonitor.left;
      offset.y = mi.rcWork.top - mi.rcMonitor.top;
    }
    r = RECT{wp.rcNormalPosition.left + offset.x,
             wp.rcNormalPosition.top + offset.y,
             wp.rcNormalPosition.right + offset.x,
             wp.rcNormalPosition.bottom + offset.y};
  } else {
    GetWindowRect(window_, &r);
  }
  return EncodableMap{
      {EncodableValue("x"), EncodableValue(static_cast<int32_t>(r.left))},
      {EncodableValue("y"), EncodableValue(static_cast<int32_t>(r.top))},
      {EncodableValue("w"), EncodableValue(static_cast<int32_t>(r.right - r.left))},
      {EncodableValue("h"), EncodableValue(static_cast<int32_t>(r.bottom - r.top))},
      {EncodableValue("maximized"), EncodableValue(zoomed)},
  };
}

void NativeBridge::FocusWindow() {
  FocusWindowTarget(window_);
}

void NativeBridge::RememberForeground() {
  const HWND fg = GetForegroundWindow();
  if (fg != nullptr && fg != window_) {
    previous_foreground_ = fg;
  }
}

void NativeBridge::PasteIntoPrevious(const std::string& text) {
  SetClipboardText(Utf16FromUtf8(text));
  const HWND prev = previous_foreground_;
  RunWorker([this, prev]() {
    if (prev != nullptr) {
      SetForegroundWindow(prev);
    }
    if (WaitOrStop(90)) return;
    SendCombo({VK_CONTROL, 'V'});
  });
}

void NativeBridge::PressKey(const std::string& name) {
  const auto combo = ComboFor(name);
  if (!combo.empty()) {
    SendCombo(combo);
  }
}

std::string NativeBridge::PinWindow() {
  const HWND hwnd = previous_foreground_;
  if (hwnd == nullptr || !IsWindow(hwnd)) {
    return "No window to pin";
  }
  wchar_t buf[120] = {};
  const int n = GetWindowTextW(hwnd, buf, 120);
  std::string title = PanelUtf8FromUtf16(n > 0 ? buf : L"");
  if (title.size() > 40) title = title.substr(0, 40) + "…";
  const bool on_top =
      (GetWindowLongPtrW(hwnd, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0;
  SetWindowPos(hwnd, on_top ? HWND_NOTOPMOST : HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  return (on_top ? "unpinned\n" : "pinned\n") + title;
}

void NativeBridge::Launch(const std::string& target) {
  const std::wstring wide = Utf16FromUtf8(target);
  ShellExecuteW(nullptr, L"open", wide.c_str(), nullptr, nullptr,
                SW_SHOWNORMAL);
}

flutter::EncodableMap NativeBridge::ApplyPlacement(const std::string& edge,
                                                   int monitor) {
  return ComputePlacement(window_, edge, monitor, placement_edge_, placement_display_);
}

std::vector<flutter::EncodableMap> NativeBridge::Screens() {
  return EnumerateScreens();
}

// ================= eyedropper =================

void NativeBridge::PickColor() {
  if (picking_) return;
  picking_ = true;
  RunWorker([this]() {
    while (!stopping_ && GetAsyncKeyState(VK_LBUTTON) < 0) {
      if (WaitOrStop(10)) return;
    }
    std::string hex;
    for (;;) {
      if (WaitOrStop(10)) return;
      if (GetAsyncKeyState(VK_ESCAPE) < 0) break;
      if (GetAsyncKeyState(VK_LBUTTON) < 0) {
        POINT p{};
        GetCursorPos(&p);
        HDC dc = GetDC(nullptr);
        const COLORREF c = GetPixel(dc, p.x, p.y);
        ReleaseDC(nullptr, dc);
        char buf[16];
        snprintf(buf, sizeof(buf), "#%02x%02x%02x", (int)(c & 0xff),
                 (int)((c >> 8) & 0xff), (int)((c >> 16) & 0xff));
        hex = buf;
        break;
      }
    }
    picking_ = false;
    EncodableMap args;
    args[EncodableValue("hex")] = EncodableValue(hex);
    PostEvent("pickedColor", EncodableValue(args));
  });
}

// ================= native color dialog =================

void NativeBridge::PickCustomColor(const std::string& currentHex) {
  RunWorker([this, currentHex]() {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    static COLORREF custom[16] = {};
    COLORREF initial = 0x000000;
    if (currentHex.size() >= 7 && currentHex[0] == '#') {
      initial = (COLORREF)strtoul(currentHex.substr(1).c_str(), nullptr, 16);
      initial = ((initial & 0xFF) << 16) | (initial & 0xFF00) | ((initial >> 16) & 0xFF);
    }
    CHOOSECOLORW cc = {};
    cc.lStructSize = sizeof(cc);
    cc.lpCustColors = custom;
    cc.rgbResult = initial;
    cc.Flags = CC_FULLOPEN | CC_RGBINIT;
    cc.Flags |= CC_ENABLEHOOK;
    cc.lCustData = reinterpret_cast<LPARAM>(this);
    cc.lpfnHook = [](HWND dialog, UINT msg, WPARAM, LPARAM value) -> UINT_PTR {
      if (msg == WM_INITDIALOG) {
        auto* config = reinterpret_cast<CHOOSECOLORW*>(value);
        auto* bridge = reinterpret_cast<NativeBridge*>(config->lCustData);
        if (bridge->stopping_) PostMessage(dialog, WM_CLOSE, 0, 0);
      }
      return 0;
    };
    if (stopping_) { CoUninitialize(); return; }
    const BOOL ok = ChooseColorW(&cc);
    EncodableMap args;
    if (ok) {
      const COLORREF c = cc.rgbResult;
      char buf[16];
      snprintf(buf, sizeof(buf), "#%02x%02x%02x", (int)(c & 0xff),
               (int)((c >> 8) & 0xff), (int)((c >> 16) & 0xff));
      args[EncodableValue("hex")] = EncodableValue(std::string(buf));
    } else {
      args[EncodableValue("hex")] = EncodableValue();
    }
    PostEvent("pickedCustomColor", EncodableValue(args));
    CoUninitialize();
  });
}

// ================= file / folder pickers =================

void NativeBridge::PickApp(bool folder) {
  if (picking_.exchange(true)) return;
  PostEvent("pickerState", EncodableValue(EncodableMap{
    {EncodableValue("active"), EncodableValue(true)}}));
  const auto title = folder ? folder_title_ : add_app_title_;
  const auto apps = apps_label_, files = files_label_;
  RunWorker([this, folder, title, apps, files]() {
    const HRESULT init = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    IFileOpenDialog* dialog = nullptr;
    if (SUCCEEDED(init) && !stopping_ && SUCCEEDED(CoCreateInstance(CLSID_FileOpenDialog, nullptr,
        CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog)))) {
      DWORD options = 0;
      dialog->GetOptions(&options);
      options |= FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST | FOS_NOCHANGEDIR;
      options |= folder ? FOS_PICKFOLDERS : (FOS_FILEMUSTEXIST | FOS_NODEREFERENCELINKS);
      dialog->SetOptions(options);
      dialog->SetTitle(title.c_str());
      if (!folder) {
        COMDLG_FILTERSPEC filters[] = {
          {apps.c_str(), L"*.exe;*.lnk;*.url;*.bat;*.cmd"},
          {files.c_str(), L"*.*"}};
        dialog->SetFileTypes(2, filters);
      }
      const HRESULT shown = stopping_ ? E_ABORT : dialog->Show(window_);
      if (SUCCEEDED(shown) && !stopping_) {
        IShellItem* item = nullptr;
        if (SUCCEEDED(dialog->GetResult(&item))) {
          PWSTR selected = nullptr;
          if (SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH, &selected))) {
            const auto path = PanelUtf8FromUtf16(selected);
            CoTaskMemFree(selected);
            if (!path.empty()) PostEvent("pickedApp", EncodableValue(EncodableMap{
              {EncodableValue("path"), EncodableValue(path)}}));
          }
          item->Release();
        }
      }
      dialog->Release();
    }
    if (SUCCEEDED(init)) CoUninitialize();
    picking_ = false;
    PostEvent("pickerState", EncodableValue(EncodableMap{
      {EncodableValue("active"), EncodableValue(false)}}));
  });
}

// ================= app icons =================

void NativeBridge::AppIconFor(const std::string& id, const std::string& path) {
  RunWorker([this, id, path]() {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const std::string icon = IconDataUriFor(path);
    if (!icon.empty()) {
      EncodableMap args;
      args[EncodableValue("id")] = EncodableValue(id);
      args[EncodableValue("icon")] = EncodableValue(icon);
      PostEvent("appIcon", EncodableValue(args));
    }
    CoUninitialize();
  });
}

// ================= registry startup =================

bool NativeBridge::StartupRegistryEnabled() { return RegistryRunEnabled(); }
void NativeBridge::SetStartupRegistry(bool on) { RegistryRunSet(on); }

// ================= clipboard images =================

void NativeBridge::SetClipboardImage(int w, int h, const std::vector<uint8_t>& rgba) {
  ::SetClipboardImage(w, h, rgba);
}

void NativeBridge::ReadClipboardImage(int request) {
  RunWorker([this, request]() {
    EncodableMap args{{EncodableValue("request"), EncodableValue(request)}};
    std::vector<uint8_t> rgba;
    uint32_t w = 0, h = 0;
    if (ReadRawClipboardImage(rgba, w, h)) {
      args[EncodableValue("id")] = EncodableValue(std::to_string(FnvHash(rgba)));
      args[EncodableValue("w")] = EncodableValue(static_cast<int32_t>(w));
      args[EncodableValue("h")] = EncodableValue(static_cast<int32_t>(h));
      args[EncodableValue("rgba")] = EncodableValue(std::move(rgba));
    }
    PostEvent("clipboardRead", EncodableValue(std::move(args)));
  });
}

void NativeBridge::StartClipboardWatch() {
  if (clipboard_started_.exchange(true)) return;
  RunWorker([this]() {
    uint64_t seq = 0;
    for (;;) {
      if (stopping_) return;
      const uint64_t s = GetClipboardSequenceNumber();
      if (s != seq) {
        seq = s;
        const std::string text = GetClipboardText();
        if (!text.empty() && text.find_first_not_of(" \t\r\n") != std::string::npos &&
            text.size() < 100000) {
          EncodableMap args;
          args[EncodableValue("text")] = EncodableValue(text);
          PostEvent("clipText", EncodableValue(args));
          continue;
        }
        // no text: try an image
        std::vector<uint8_t> rgba;
        uint32_t w = 0, ht = 0;
        if (ReadRawClipboardImage(rgba, w, ht)) {
          uint32_t tw = 0, th = 0;
          std::vector<uint8_t> thumb;
          Downscale(w, ht, rgba, 1600, &tw, &th, &thumb);
          const uint64_t id = FnvHash(thumb) ^ (((uint64_t)tw) << 32) ^ th;
          if (g_last_image_id.exchange(id) != id) {
            EncodableMap args;
            args[EncodableValue("id")] = EncodableValue(std::to_string(id));
            args[EncodableValue("w")] = EncodableValue(static_cast<int32_t>(tw));
            args[EncodableValue("h")] = EncodableValue(static_cast<int32_t>(th));
            args[EncodableValue("rgba")] = EncodableValue(std::move(thumb));
            PostEvent("clipImage", EncodableValue(args));
          }
        }
      }
      if (WaitOrStop(400)) return;
    }
  });
}

// ================= tray =================

void NativeBridge::CreateTray() {
  tray_added_ = CreateTrayIcon(window_, tray_icon_, tray_menu_, StartupRegistryEnabled());
}

void NativeBridge::RemoveTray() {
  RemoveTrayIcon(window_, tray_icon_, tray_menu_, tray_added_);
}

void NativeBridge::ShowTrayMenu() {
  ShowTrayContextMenu(window_, tray_menu_, StartupRegistryEnabled());
}

// ================= messages =================

bool NativeBridge::OnMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_APP_SHOW) {
    SetPassthrough(false);
    SetForegroundWindow(window_);
    PostEvent("tray", EncodableValue(EncodableMap{{EncodableValue("id"), EncodableValue("capture")}}));
    return true;
  }
  if (message == WM_DISPLAYCHANGE || message == WM_DPICHANGED) {
    if (!window_mode_) PostMessage(window_, WM_APP_PLACEMENT, 0, 0);
  }
  if (message == WM_APP_PLACEMENT) {
    if (window_mode_) return true;
    const auto monitors = CollectMonitors();
    if (monitors.empty()) return true;
    int selected = 0;
    for (size_t i = 0; i < monitors.size(); ++i) {
      if (monitors[i].name == placement_display_) { selected = static_cast<int>(i); break; }
    }
    PostEvent("placement", EncodableValue(ApplyPlacement(placement_edge_, selected)));
    return true;
  }
  if (message == WM_CLOSE && !quit_requested_) {
    PostEvent("tray", EncodableValue(EncodableMap{{EncodableValue("id"), EncodableValue("shutdown")}}));
    return true;
  }
  if (message == WM_HOTKEY && wparam == 1) {
    RememberForeground();
    SetPassthrough(false);
    SetForegroundWindow(window_);
    PostEvent("tray", EncodableValue(EncodableMap{{EncodableValue("id"), EncodableValue("capture")}}));
    return true;
  }

  if (message == WM_APP_EVENT) {
    DrainEvents();
    return true;
  }
  if (message == taskbar_created_msg_ && taskbar_created_msg_ != 0) {
    if (tray_added_) {
      tray_added_ = false;
      CreateTray();
    }
    return false;
  }
  if (message == WM_GETMINMAXINFO && window_mode_) {
    auto* mmi = reinterpret_cast<MINMAXINFO*>(lparam);
    const UINT dpi = FlutterDesktopGetDpiForMonitor(
        MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST));
    const double scale = dpi == 0 ? 1.0 : dpi / 96.0;
    mmi->ptMinTrackSize.x = static_cast<LONG>(520 * scale);
    mmi->ptMinTrackSize.y = static_cast<LONG>(560 * scale);
    return false;
  }

  if (message == WM_APP_TRAY) {
    const UINT mouse = static_cast<UINT>(lparam);
    if (mouse == WM_LBUTTONUP || mouse == WM_LBUTTONDBLCLK) {
      SetPassthrough(false);
      SetForegroundWindow(window_);
      PostEvent("tray", EncodableValue(EncodableMap{
                             {EncodableValue("id"), EncodableValue("open")}}));
    } else if (mouse == WM_RBUTTONUP || mouse == WM_CONTEXTMENU) {
      ShowTrayMenu();
    }
    return true;
  }
  if (message == WM_COMMAND) {
    const int id = LOWORD(wparam);
    const char* ev = nullptr;
    switch (id) {
      case IDM_TRAY_OPEN: ev = "open"; break;
      case IDM_TRAY_SETTINGS: ev = "settings"; break;
      case IDM_TRAY_ADDAPP: ev = "addapp"; break;
      case IDM_TRAY_STARTUP: ev = "startup"; break;
      case IDM_TRAY_QUIT: ev = "quit"; break;
      default: break;
    }
    if (ev != nullptr) {
      if (id == IDM_TRAY_OPEN || id == IDM_TRAY_SETTINGS) {
        SetPassthrough(false);
        SetForegroundWindow(window_);
      }
      PostEvent("tray", EncodableValue(EncodableMap{
                             {EncodableValue("id"), EncodableValue(ev)}}));
      return true;
    }
    return false;
  }
  if (message == WM_DROPFILES) {
    HDROP drop = reinterpret_cast<HDROP>(wparam);
    wchar_t buf[MAX_PATH * 2] = {};
    const UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
    flutter::EncodableList paths;
    for (UINT i = 0; i < count && i < 16; i++) {
      if (DragQueryFileW(drop, i, buf, ARRAYSIZE(buf)) > 0) {
        paths.push_back(EncodableValue(PanelUtf8FromUtf16(buf)));
      }
    }
    DragFinish(drop);
    PostEvent("files", EncodableValue(EncodableMap{
                           {EncodableValue("paths"), EncodableValue(paths)}}));
    return true;
  }
  return false;
}
