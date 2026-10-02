// Native bridge: the entire Windows-specific half of Nex, ported
// from the original's src/sys/windows.rs. Runs inside the Flutter runner
// (no plugins, no extra DLLs).

#include "native_bridge.h"
#include "resource.h"

#include <windows.h>

#include <commctrl.h>
#include <commdlg.h>
#include <cctype>
#include <dwmapi.h>
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

const wchar_t kRunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
const wchar_t kRunName[] = L"NexDesktop";

const EncodableValue* Find(const EncodableMap* m, const char* key) {
  if (m == nullptr) return nullptr;
  auto it = m->find(EncodableValue(key));
  return it == m->end() ? nullptr : &it->second;
}

std::string ArgString(const EncodableMap* m, const char* key) {
  const auto* v = Find(m, key);
  const auto* s = v ? std::get_if<std::string>(v) : nullptr;
  return s ? *s : std::string();
}

bool ArgBool(const EncodableMap* m, const char* key) {
  const auto* v = Find(m, key);
  if (!v) return false;
  if (const auto* b = std::get_if<bool>(v)) return *b;
  if (const auto* i = std::get_if<int32_t>(v)) return *i != 0;
  if (const auto* l = std::get_if<int64_t>(v)) return *l != 0;
  return false;
}

int ArgInt(const EncodableMap* m, const char* key) {
  const auto* v = Find(m, key);
  if (!v) return 0;
  if (const auto* i = std::get_if<int32_t>(v)) return *i;
  if (const auto* l = std::get_if<int64_t>(v)) return static_cast<int>(*l);
  if (const auto* d = std::get_if<double>(v)) return static_cast<int>(*d);
  return 0;
}

std::vector<uint8_t> ArgBytes(const EncodableMap* m, const char* key) {
  const auto* v = Find(m, key);
  const auto* b = v ? std::get_if<std::vector<uint8_t>>(v) : nullptr;
  return b ? *b : std::vector<uint8_t>();
}

std::wstring Utf16FromUtf8Inner(const std::string& s) {
  if (s.empty()) return std::wstring();
  int len = MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), nullptr, 0);
  std::wstring out(len, 0);
  MultiByteToWideChar(CP_UTF8, 0, s.data(), (int)s.size(), out.data(), len);
  return out;
}

std::string Utf8FromUtf16Inner(const wchar_t* s) {
  if (s == nullptr) return std::string();
  int len = WideCharToMultiByte(CP_UTF8, 0, s, -1, nullptr, 0, nullptr, nullptr);
  if (len <= 1) return std::string();
  std::string out(len - 1, 0);
  WideCharToMultiByte(CP_UTF8, 0, s, -1, out.data(), len, nullptr, nullptr);
  return out;
}

// ---------- keyboard ----------

void SendCombo(const std::vector<WORD>& combo) {
  std::vector<INPUT> inputs;
  for (WORD vk : combo) {
    INPUT down = {};
    down.type = INPUT_KEYBOARD;
    down.ki.wVk = vk;
    inputs.push_back(down);
  }
  for (auto it = combo.rbegin(); it != combo.rend(); ++it) {
    INPUT up = {};
    up.type = INPUT_KEYBOARD;
    up.ki.wVk = *it;
    up.ki.dwFlags = KEYEVENTF_KEYUP;
    inputs.push_back(up);
  }
  SendInput((UINT)inputs.size(), inputs.data(), sizeof(INPUT));
}

std::vector<WORD> ComboFor(const std::string& name) {
  const WORD play = 0xB3, next = 0xB0, prev = 0xB1, mute = 0xAD,
            volup = 0xAF, voldown = 0xAE, lwin = 0x5B, d = 0x44;
  if (name == "play") return {play};
  if (name == "next") return {next};
  if (name == "prev") return {prev};
  if (name == "mute") return {mute};
  if (name == "volup") return {volup};
  if (name == "voldown") return {voldown};
  if (name == "desktop") return {lwin, d};
  return {};
}

// ---------- clipboard helpers ----------

bool SetClipboardText(const std::wstring& text) {
  if (!OpenClipboard(nullptr)) return false;
  EmptyClipboard();
  const size_t bytes = (text.size() + 1) * sizeof(wchar_t);
  HGLOBAL mem = GlobalAlloc(GMEM_MOVEABLE, bytes);
  if (mem == nullptr) {
    CloseClipboard();
    return false;
  }
  auto* dst = static_cast<wchar_t*>(GlobalLock(mem));
  if (dst != nullptr) {
    memcpy(dst, text.c_str(), bytes);
    GlobalUnlock(mem);
  }
  const HANDLE ok = SetClipboardData(CF_UNICODETEXT, mem);
  CloseClipboard();
  return ok != nullptr;
}

std::string GetClipboardText() {
  if (!OpenClipboard(nullptr)) return std::string();
  std::string out;
  HANDLE h = GetClipboardData(CF_UNICODETEXT);
  if (h != nullptr) {
    if (auto* wide = static_cast<const wchar_t*>(GlobalLock(h))) {
      out = Utf8FromUtf16Inner(wide);
      GlobalUnlock(h);
    }
  }
  CloseClipboard();
  return out;
}

// ---------- registry (startup) ----------

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
                  (DWORD)((value.size() + 1) * sizeof(wchar_t)));
}

// ---------- monitors ----------

struct MonitorItem {
  HMONITOR handle;
  int x, y, w, h;
  std::wstring name;
};

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

std::atomic<uint64_t> g_last_image_id{0};


}  // namespace

std::string PanelUtf8FromUtf16(const wchar_t* s) { return Utf8FromUtf16Inner(s); }
std::wstring Utf16FromUtf8(const std::string& s) { return Utf16FromUtf8Inner(s); }

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
    if (hotkey_registered_) SendCombo({VK_CONTROL, VK_MENU, static_cast<WORD>(hotkey_vk_)});
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
      // let the panel slide away first
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
  } else if (name == "screens") {
    EncodableList list;
    for (auto& m : Screens()) list.push_back(EncodableValue(m));
    result->Success(EncodableValue(list));
  } else if (name == "ready") {
    StartClipboardWatch();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

// ================= window plumbing =================

void NativeBridge::SetPassthrough(bool on) {
  passthrough_ = on;
  LONG ex = GetWindowLong(window_, GWL_EXSTYLE);
  // Hide the closed host instead of putting a DirectComposition child inside
  // a layered parent. That combination produced a ghost shadow/invisible UI.
  ex &= ~(WS_EX_TRANSPARENT | WS_EX_LAYERED | WS_EX_TOOLWINDOW);
  ex |= WS_EX_APPWINDOW;
  SetWindowLong(window_, GWL_EXSTYLE, ex);
  SetWindowPos(window_, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED);
  ShowWindow(window_, on ? SW_HIDE : SW_SHOWNOACTIVATE);
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
  std::string title = Utf8FromUtf16Inner(n > 0 ? buf : L"");
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
  const auto monitors = CollectMonitors();
  EncodableMap out;
  if (monitors.empty()) return out;
  const size_t idx = monitor >= 0 && (size_t)monitor < monitors.size()
                         ? (size_t)monitor
                         : 0;
  const auto& m = monitors[idx];
  const UINT dpi = FlutterDesktopGetDpiForMonitor(m.handle);
  const double scale = dpi == 0 ? 1.0 : dpi / 96.0;
  const int w = (int)(480 * scale);
  const int h = (int)(680 * scale);
  const int hClamped = h < m.h ? h : m.h;
  const bool left = edge == "left";
  placement_edge_ = left ? "left" : "right";
  placement_display_ = m.name;
  const int x = left ? m.x : (m.x + m.w - w);
  const int y = m.y + (m.h - hClamped) / 2;
  SetWindowPos(window_, nullptr, x, y, w, hClamped,
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

std::vector<flutter::EncodableMap> NativeBridge::Screens() {
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

// ================= eyedropper =================

void NativeBridge::PickColor() {
  if (picking_) return;
  picking_ = true;
  RunWorker([this]() {
    // wait for the current press to release
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

// ================= native color dialog (input type=color) =================

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
            const auto path = Utf8FromUtf16Inner(selected);
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

std::string IconDataUriFor(const std::string& path) {
  const std::wstring wide = Utf16FromUtf8(path);
  HICON icon = nullptr;
  std::string lower = path;
  std::transform(lower.begin(), lower.end(), lower.begin(),
    [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  if (lower.size() > 4 && lower.substr(lower.size() - 4) == ".exe") {
    UINT id = 0;
    PrivateExtractIconsW(wide.c_str(), 0, 64, 64, &icon, &id, 1, 0);
  }
  if (icon == nullptr) {
    SHFILEINFOW info = {};
    SHGetFileInfoW(wide.c_str(), FILE_ATTRIBUTE_NORMAL, &info, sizeof(info),
                   SHGFI_SYSICONINDEX);
    // {46EB5926-582E-4017-9FDF-E8998DAA0950} = IID_IImageList
    const CLSID iid_iimagelist = {0x46eb5926, 0x582e, 0x4017,
                                  {0x9f, 0xdf, 0xe8, 0x99, 0x8d, 0xaa, 0x09, 0x50}};
    void* list = nullptr;
    if (SHGetImageList(SHIL_EXTRALARGE, iid_iimagelist, &list) >= 0 && list != nullptr) {
      icon = ImageList_GetIcon((HIMAGELIST)list, info.iIcon, ILD_TRANSPARENT);
      reinterpret_cast<IUnknown*>(list)->Release();
    }
  }
  if (icon == nullptr) return std::string();
  ICONINFO ii = {};
  GetIconInfo(icon, &ii);
  std::string out;
  if (ii.hbmColor != nullptr) {
    BITMAP bm = {};
    GetObjectW(ii.hbmColor, sizeof(bm), &bm);
    if (bm.bmWidth > 0 && bm.bmHeight > 0) {
      BITMAPINFO bi = {};
      bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
      bi.bmiHeader.biWidth = bm.bmWidth;
      bi.bmiHeader.biHeight = -bm.bmHeight;
      bi.bmiHeader.biPlanes = 1;
      bi.bmiHeader.biBitCount = 32;
      bi.bmiHeader.biCompression = BI_RGB;
      const size_t px_count = (size_t)bm.bmWidth * bm.bmHeight;
      std::vector<uint8_t> px(px_count * 4);
      HDC dc = CreateCompatibleDC(nullptr);
      if (GetDIBits(dc, ii.hbmColor, 0, bm.bmHeight, px.data(), &bi,
                    DIB_RGB_COLORS) != 0) {
        bool has_alpha = false;
        for (size_t i = 3; i < px.size(); i += 4) {
          if (px[i] != 0) {
            has_alpha = true;
            break;
          }
        }
        for (size_t i = 0; i < px.size(); i += 4) {
          std::swap(px[i], px[i + 2]);  // BGRA -> RGBA
          if (!has_alpha) px[i + 3] = 255;
        }
        const auto png = PngEncode((uint32_t)bm.bmWidth, (uint32_t)bm.bmHeight, px);
        out = "data:image/png;base64," + Base64Encode(png);
      }
      DeleteDC(dc);
    }
  }
  if (ii.hbmMask != nullptr) DeleteObject(ii.hbmMask);
  if (ii.hbmColor != nullptr) DeleteObject(ii.hbmColor);
  DestroyIcon(icon);
  return out;
}

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

namespace {

// Port of dib_to_rgba: reads a CF_DIB into RGBA.
bool DibToRgba(const uint8_t* dib, size_t size, uint32_t* out_w, uint32_t* out_h,
               std::vector<uint8_t>* out) {
  if (dib == nullptr || size < sizeof(BITMAPINFOHEADER)) return false;
  const auto* head = reinterpret_cast<const BITMAPINFOHEADER*>(dib);
  const int32_t w = head->biWidth;
  const int32_t h = head->biHeight;
  if (w <= 0 || h == 0 || w > 10000 || (h > 10000 || h < -10000)) return false;
  if ((head->biBitCount != 24 && head->biBitCount != 32) ||
      (head->biCompression != BI_RGB && head->biCompression != BI_BITFIELDS) ||
      head->biSize < sizeof(BITMAPINFOHEADER) || head->biSize > size) return false;
  const uint32_t rows = (uint32_t)(h > 0 ? h : -h);
  const bool flip = h > 0;
  const size_t bpp = head->biBitCount / 8;
  const size_t stride = ((size_t)w * bpp + 3) & ~3;
  const size_t masks = head->biCompression == BI_BITFIELDS && head->biSize == sizeof(BITMAPINFOHEADER) ? 12 : 0;
  const uint64_t offset = head->biSize + masks + static_cast<uint64_t>(head->biClrUsed) * 4;
  if (offset > size || stride * rows > size - offset) return false;
  const uint8_t* pixels = dib + static_cast<size_t>(offset);
  out->assign((size_t)w * rows * 4, 0);
  for (uint32_t y = 0; y < rows; y++) {
    const size_t src_row = flip ? (rows - 1 - y) : y;
    const uint8_t* src = pixels + src_row * stride;
    for (int32_t x = 0; x < w; x++) {
      const uint8_t* p = src + (size_t)x * bpp;
      const size_t i = ((size_t)y * w + x) * 4;
      (*out)[i] = p[2];
      (*out)[i + 1] = p[1];
      (*out)[i + 2] = p[0];
      (*out)[i + 3] = bpp == 4 ? (p[3] != 0 ? p[3] : 255) : 255;
    }
  }
  *out_w = (uint32_t)w;
  *out_h = rows;
  return true;
}

// Nearest-neighbour downscale, port of thumbnail().
void Downscale(uint32_t w, uint32_t h, const std::vector<uint8_t>& src,
               uint32_t max_dim, uint32_t* out_w, uint32_t* out_h,
               std::vector<uint8_t>* out) {
  if (w <= max_dim && h <= max_dim) {
    *out_w = w;
    *out_h = h;
    *out = src;
    return;
  }
  const double scale = (double)max_dim / (w > h ? w : h);
  if (scale > 1.0) {
    *out_w = w;
    *out_h = h;
    *out = src;
    return;
  }
  const uint32_t tw = std::max(1u, (uint32_t)(w * scale));
  const uint32_t th = std::max(1u, (uint32_t)(h * scale));
  out->assign((size_t)tw * th * 4, 0);
  for (uint32_t y = 0; y < th; y++) {
    for (uint32_t x = 0; x < tw; x++) {
      const size_t si = (((size_t)y * h / th) * w + ((size_t)x * w / tw)) * 4;
      const size_t di = ((size_t)y * tw + x) * 4;
      memcpy(out->data() + di, src.data() + si, 4);
    }
  }
  *out_w = tw;
  *out_h = th;
}

}  // namespace

void NativeBridge::SetClipboardImage(int w, int h, const std::vector<uint8_t>& rgba) {
  if (w <= 0 || h <= 0 || rgba.size() != (size_t)w * h * 4) return;
  const size_t header = sizeof(BITMAPINFOHEADER);
  std::vector<uint8_t> buf(header + (size_t)w * h * 4);
  auto* head = reinterpret_cast<BITMAPINFOHEADER*>(buf.data());
  head->biSize = header;
  head->biWidth = w;
  head->biHeight = h;  // positive: bottom-up
  head->biPlanes = 1;
  head->biBitCount = 32;
  head->biCompression = BI_RGB;
  head->biSizeImage = (DWORD)(w * h * 4);
  for (int y = 0; y < h; y++) {
    const size_t src = (size_t)(h - 1 - y) * w * 4;
    for (int x = 0; x < w; x++) {
      const size_t s = src + (size_t)x * 4;
      const size_t d = header + ((size_t)y * w + x) * 4;
      buf[d] = rgba[s + 2];
      buf[d + 1] = rgba[s + 1];
      buf[d + 2] = rgba[s];
      buf[d + 3] = rgba[s + 3];
    }
  }
  if (!OpenClipboard(nullptr)) return;
  EmptyClipboard();
  HGLOBAL mem = GlobalAlloc(GMEM_MOVEABLE, buf.size());
  if (mem != nullptr) {
    void* dst = GlobalLock(mem);
    memcpy(dst, buf.data(), buf.size());
    GlobalUnlock(mem);
    SetClipboardData(CF_DIB, mem);
  }
  CloseClipboard();
}

// ================= clipboard watch =================

void NativeBridge::ReadClipboardImage(int request) {
  RunWorker([this, request]() {
    EncodableMap args{{EncodableValue("request"), EncodableValue(request)}};
    if (OpenClipboard(nullptr)) {
      HANDLE handle = GetClipboardData(CF_DIBV5);
      if (handle == nullptr) handle = GetClipboardData(CF_DIB);
      if (handle != nullptr) {
        const auto* dib = static_cast<const uint8_t*>(GlobalLock(handle));
        uint32_t w = 0, h = 0;
        std::vector<uint8_t> rgba;
        if (DibToRgba(dib, GlobalSize(handle), &w, &h, &rgba)) {
          args[EncodableValue("id")] = EncodableValue(std::to_string(FnvHash(rgba)));
          args[EncodableValue("w")] = EncodableValue(static_cast<int32_t>(w));
          args[EncodableValue("h")] = EncodableValue(static_cast<int32_t>(h));
          args[EncodableValue("rgba")] = EncodableValue(std::move(rgba));
        }
        if (dib != nullptr) GlobalUnlock(handle);
      }
      CloseClipboard();
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
        if (OpenClipboard(nullptr)) {
          HANDLE h = GetClipboardData(CF_DIB);
          if (h != nullptr) {
            if (const auto* dib = static_cast<const uint8_t*>(GlobalLock(h))) {
              const size_t size = GlobalSize(h);
              uint32_t w = 0, ht = 0;
              std::vector<uint8_t> rgba;
              if (DibToRgba(dib, size, &w, &ht, &rgba)) {
                uint32_t tw = 0, th = 0;
                std::vector<uint8_t> thumb;
                Downscale(w, ht, rgba, 1600, &tw, &th, &thumb);
                const uint64_t id = FnvHash(thumb) ^ (((uint64_t)tw) << 32) ^ th;
                if (g_last_image_id.exchange(id) != id) {
                  EncodableMap args;
                  args[EncodableValue("id")] = EncodableValue(std::to_string(id));
                  args[EncodableValue("w")] = EncodableValue((int32_t)tw);
                  args[EncodableValue("h")] = EncodableValue((int32_t)th);
                  args[EncodableValue("rgba")] = EncodableValue(std::move(thumb));
                  PostEvent("clipImage", EncodableValue(args));
                }
              }
              GlobalUnlock(h);
            }
          }
          CloseClipboard();
        }
      }
      if (WaitOrStop(400)) return;
    }
  });
}

// ================= tray =================

std::vector<uint8_t> TrayIconRgba() {
  // black liquid drop with a white ring, 32x32 — port of util::tray_rgba().
  std::vector<uint8_t> px(32 * 32 * 4, 0);
  for (int y = 0; y < 32; y++) {
    for (int x = 0; x < 32; x++) {
      const float dx = (float)x - 15.5f;
      const float dy = (float)y - 15.5f;
      const float d = std::sqrt(dx * dx + dy * dy);
      const size_t i = ((size_t)y * 32 + x) * 4;
      const float edge = std::min(std::max(15.5f - d, 0.0f), 1.0f);
      if (edge > 0.0f) {
        const float ringRaw = 1.0f - (std::abs(d - 8.0f) - 1.4f);
        const float ring = std::min(std::max(ringRaw, 0.0f), 1.0f);
        const uint8_t v = (uint8_t)(ring * 255);
        px[i] = v;
        px[i + 1] = v;
        px[i + 2] = v;
        px[i + 3] = (uint8_t)(edge * 255);
      }
    }
  }
  return px;
}

void NativeBridge::CreateTray() {
  if (tray_icon_ != nullptr) DestroyIcon(tray_icon_);
  if (tray_menu_ != nullptr) DestroyMenu(tray_menu_);
  tray_menu_ = nullptr;
  tray_icon_ = CopyIcon(LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON)));
  if (tray_icon_ == nullptr) return;

  NOTIFYICONDATAW nid = {};
  nid.cbSize = sizeof(nid);
  nid.hWnd = window_;
  nid.uID = 1;
  nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  nid.uCallbackMessage = WM_APP_TRAY;
  nid.hIcon = tray_icon_;
  wcscpy_s(nid.szTip, L"Nex");
  tray_added_ = Shell_NotifyIconW(NIM_ADD, &nid) != FALSE;

  tray_menu_ = CreatePopupMenu();
  AppendMenuW(tray_menu_, MF_STRING, IDM_TRAY_OPEN, L"Nex");
  AppendMenuW(tray_menu_, MF_STRING, IDM_TRAY_SETTINGS, L"Nex");
  AppendMenuW(tray_menu_, MF_STRING, IDM_TRAY_ADDAPP, L"Nex");
  AppendMenuW(tray_menu_, MF_SEPARATOR, 0, nullptr);
  UINT flag = MF_STRING | (StartupRegistryEnabled() ? MF_CHECKED : 0);
  AppendMenuW(tray_menu_, flag, IDM_TRAY_STARTUP, L"Nex");
  AppendMenuW(tray_menu_, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(tray_menu_, MF_STRING, IDM_TRAY_QUIT, L"Nex");
}

void NativeBridge::RemoveTray() {
  if (tray_added_) {
    NOTIFYICONDATAW nid = {};
    nid.cbSize = sizeof(nid);
    nid.hWnd = window_;
    nid.uID = 1;
    Shell_NotifyIconW(NIM_DELETE, &nid);
    tray_added_ = false;
  }
  if (tray_icon_ != nullptr) {
    DestroyIcon(tray_icon_);
    tray_icon_ = nullptr;
  }
  if (tray_menu_ != nullptr) {
    DestroyMenu(tray_menu_);
    tray_menu_ = nullptr;
  }
}

void NativeBridge::ShowTrayMenu() {
  if (tray_menu_ == nullptr) return;
  CheckMenuItem(tray_menu_, IDM_TRAY_STARTUP,
                StartupRegistryEnabled() ? MF_CHECKED : MF_UNCHECKED);
  POINT p{};
  GetCursorPos(&p);
  SetForegroundWindow(window_);
  TrackPopupMenu(tray_menu_, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN, p.x, p.y, 0,
                 window_, nullptr);
  PostMessage(window_, WM_NULL, 0, 0);
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
    // Let Win32 process the suggested DPI rectangle, then re-anchor using the
    // selected display's current scale rather than stale Dart placement data.
    PostMessage(window_, WM_APP_PLACEMENT, 0, 0);
  }
  if (message == WM_APP_PLACEMENT) {
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
    // Explorer restarted: re-add the tray icon.
    if (tray_added_) {
      tray_added_ = false;
      CreateTray();
    }
    return false;
  }
  if (message == WM_APP_TRAY) {
    const UINT mouse = (UINT)lparam;
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
    HDROP drop = (HDROP)wparam;
    wchar_t buf[MAX_PATH * 2] = {};
    const UINT count = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
    flutter::EncodableList paths;
    for (UINT i = 0; i < count && i < 16; i++) {
      if (DragQueryFileW(drop, i, buf, ARRAYSIZE(buf)) > 0) {
        paths.push_back(EncodableValue(Utf8FromUtf16Inner(buf)));
      }
    }
    DragFinish(drop);
    PostEvent("files", EncodableValue(EncodableMap{
                           {EncodableValue("paths"), EncodableValue(paths)}}));
    return true;
  }
  return false;
}

// ================= tiny PNG encoder + base64 + hash (ports of util.rs) =================

namespace {

uint32_t Crc32(const uint8_t* data, size_t len) {
  uint32_t c = 0xFFFFFFFFu;
  for (size_t i = 0; i < len; i++) {
    c ^= data[i];
    for (int k = 0; k < 8; k++) {
      c = (c & 1) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
    }
  }
  return ~c;
}

void WriteBE32(std::vector<uint8_t>* out, uint32_t v) {
  out->push_back((uint8_t)(v >> 24));
  out->push_back((uint8_t)(v >> 16));
  out->push_back((uint8_t)(v >> 8));
  out->push_back((uint8_t)v);
}

void AppendChunk(std::vector<uint8_t>* out, const char* kind, const uint8_t* data, size_t len) {
  WriteBE32(out, (uint32_t)len);
  std::vector<uint8_t> body(kind, kind + 4);
  body.insert(body.end(), data, data + len);
  out->insert(out->end(), body.begin(), body.end());
  WriteBE32(out, Crc32(body.data(), body.size()));
}

}  // namespace

std::vector<uint8_t> PngEncode(uint32_t w, uint32_t h,
                               const std::vector<uint8_t>& rgba) {
  // raw scanlines with filter byte 0
  std::vector<uint8_t> raw;
  raw.reserve((size_t)h * ((size_t)w * 4 + 1));
  for (uint32_t y = 0; y < h; y++) {
    raw.push_back(0);
    raw.insert(raw.end(), rgba.begin() + (size_t)y * w * 4,
               rgba.begin() + (size_t)(y + 1) * w * 4);
  }
  // uncompressed deflate: stored blocks
  std::vector<uint8_t> z{0x78, 0x01};
  const size_t chunk = 65535;
  const size_t blocks = (raw.size() + chunk - 1) / chunk;
  for (size_t i = 0; i < blocks; i++) {
    const size_t start = i * chunk;
    const size_t len = std::min(chunk, raw.size() - start);
    const bool last = i == blocks - 1;
    z.push_back(last ? 1 : 0);
    z.push_back((uint8_t)(len & 0xff));
    z.push_back((uint8_t)((len >> 8) & 0xff));
    const uint16_t nlen = (uint16_t)~(uint16_t)len;
    z.push_back((uint8_t)(nlen & 0xff));
    z.push_back((uint8_t)((nlen >> 8) & 0xff));
    z.insert(z.end(), raw.begin() + start, raw.begin() + start + len);
  }
  uint32_t a = 1, b = 0;
  for (uint8_t byte : raw) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  WriteBE32(&z, (b << 16) | a);

  std::vector<uint8_t> out{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'};
  std::vector<uint8_t> ihdr;
  WriteBE32(&ihdr, w);
  WriteBE32(&ihdr, h);
  ihdr.insert(ihdr.end(), {8, 6, 0, 0, 0});
  AppendChunk(&out, "IHDR", ihdr.data(), ihdr.size());
  AppendChunk(&out, "IDAT", z.data(), z.size());
  AppendChunk(&out, "IEND", nullptr, 0);
  return out;
}

std::string Base64Encode(const std::vector<uint8_t>& data) {
  static const char* table =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::string s;
  s.reserve(data.size() * 4 / 3 + 4);
  for (size_t i = 0; i < data.size(); i += 3) {
    const uint32_t n = (uint32_t)data[i] << 16 |
                       (i + 1 < data.size() ? (uint32_t)data[i + 1] : 0) << 8 |
                       (i + 2 < data.size() ? (uint32_t)data[i + 2] : 0);
    const size_t have = std::min((size_t)3, data.size() - i);
    for (int k = 0; k < 4; k++) {
      if ((size_t)k <= have) {
        s.push_back(table[(n >> (18 - 6 * k)) & 63]);
      } else {
        s.push_back('=');
      }
    }
  }
  return s;
}

uint64_t FnvHash(const std::vector<uint8_t>& data) {
  uint64_t h = 0xcbf29ce484222325ULL;
  for (uint8_t byte : data) {
    h = (h ^ byte) * 0x100000001b3ULL;
  }
  return h ^ data.size();
}
