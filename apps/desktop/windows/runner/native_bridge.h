#ifndef RUNNER_NATIVE_BRIDGE_H_
#define RUNNER_NATIVE_BRIDGE_H_

#include <windows.h>

#include <deque>
#include <atomic>
#include <thread>
#include <vector>
#include <functional>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <string>

#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

// Custom window messages routed through the runner's message loop so
// worker threads can talk to Dart on the platform thread.
#define WM_APP_TRAY (WM_APP + 1)
#define WM_APP_EVENT (WM_APP + 2)
#define WM_APP_QUIT (WM_APP + 3)
#define WM_APP_PLACEMENT (WM_APP + 4)
#define WM_APP_SHOW (WM_APP + 5)

// Tray menu command ids.
#define IDM_TRAY_OPEN 40001
#define IDM_TRAY_SETTINGS 40002
#define IDM_TRAY_ADDAPP 40003
#define IDM_TRAY_STARTUP 40004
#define IDM_TRAY_QUIT 40005

/// The whole native half of the app, ported from the original's
/// src/sys/windows.rs: edge window plumbing, tray, clipboard watch
/// (text + images), paste-into-previous, media keys, pin window,
/// registry startup, pickers, app icon extraction, single instance.
class NativeBridge {
 public:
  NativeBridge(HWND window, flutter::FlutterViewController* controller);
  ~NativeBridge();

  void Start();  // tray + initial passthrough + file drop

  /// Handles "rp/native" method calls from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  /// Handles tray messages and drains the cross-thread event queue.
  /// Returns true if the message was consumed.
  bool OnMessage(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);

  /// True when the settings say a tray "start with Windows" checkmark shows.
  bool StartupEnabled();

  /// Tells Dart the window lost activation (auto-close, like app.blur()).
  void NotifyBlur();

  HWND window() const { return window_; }
  bool passthrough() const { return passthrough_; }

 private:
  void PostEvent(const std::string& method, flutter::EncodableValue args);
  void DrainEvents();

  void SetPassthrough(bool on);
  void RememberForeground();
  void PasteIntoPrevious(const std::string& text);
  void PressKey(const std::string& name);
  std::string PinWindow();
  void Launch(const std::string& target);
  void PickColor();
  void PickCustomColor(const std::string& currentHex);
  void PickApp(bool folder);
  void AppIconFor(const std::string& id, const std::string& path);
  bool StartupRegistryEnabled();
  void SetStartupRegistry(bool on);
  void SetClipboardImage(int w, int h, const std::vector<uint8_t>& rgba);
  flutter::EncodableMap ApplyPlacement(const std::string& edge, int monitor);
  std::vector<flutter::EncodableMap> Screens();
  void StartClipboardWatch();
  void ReadClipboardImage(int request);

  void CreateTray();
  void RemoveTray();
  void ShowTrayMenu();

  void RunWorker(std::function<void()> work);
  bool WaitOrStop(int milliseconds);
  std::atomic<bool> stopping_{false};
  std::atomic<bool> clipboard_started_{false};
  std::condition_variable stop_cv_;
  std::mutex stop_mutex_;
  struct Worker { std::thread thread; std::shared_ptr<std::atomic<bool>> done; };
  std::vector<Worker> workers_;

  HWND window_;
  flutter::MethodChannel<flutter::EncodableValue> channel_;

  HWND previous_foreground_ = nullptr;
  bool passthrough_ = false;
  bool tray_added_ = false;
  bool quit_requested_ = false;
  bool hotkey_registered_ = false;
  UINT hotkey_vk_ = 'N';
  std::string placement_edge_ = "right";
  std::wstring placement_display_;
  std::wstring add_app_title_ = L"Nex", folder_title_ = L"Nex", apps_label_ = L"Nex", files_label_ = L"Nex";
  std::atomic<bool> picking_{false};

  std::mutex events_mutex_;
  std::deque<std::pair<std::string, flutter::EncodableValue>> pending_events_;

  UINT taskbar_created_msg_ = 0;
  HICON tray_icon_ = nullptr;
  HMENU tray_menu_ = nullptr;
};

// Shared helpers (defined in native_bridge.cpp).
std::string PanelUtf8FromUtf16(const wchar_t* s);
std::wstring Utf16FromUtf8(const std::string& s);
std::string Base64Encode(const std::vector<uint8_t>& data);
std::vector<uint8_t> PngEncode(uint32_t w, uint32_t h,
                               const std::vector<uint8_t>& rgba);
std::vector<uint8_t> TrayIconRgba();
std::string IconDataUriFor(const std::string& path);
uint64_t FnvHash(const std::vector<uint8_t>& data);

#endif  // RUNNER_NATIVE_BRIDGE_H_
