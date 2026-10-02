#include "flutter_window.h"

#include <optional>

#include <shellapi.h>

#include "flutter/generated_plugin_registrant.h"
#include "native_bridge.h"

namespace {

// Per-pixel window transparency, the same recipe used by window_manager /
// flutter_acrylic on Windows: an accent policy of
// ACCENT_ENABLE_TRANSPARENTGRADIENT with a zero color makes the window
// surface transparent, letting the Flutter content (which paints its own
// opaque panels) float over the desktop.
typedef enum _ACCENT_STATE_ACC {
  ACCENT_DISABLED_ACC = 0,
  ACCENT_ENABLE_GRADIENT_ACC = 1,
  ACCENT_ENABLE_TRANSPARENTGRADIENT_ACC = 2,
} ACCENT_STATE_ACC;

typedef struct _ACCENT_POLICY_ACC {
  int nAccentState;
  int nFlags;
  int nColor;
  int nAnimationId;
} ACCENT_POLICY_ACC;

typedef struct _WINCOMPATTRDATA_ACC {
  int nAttribute;
  PVOID pData;
  ULONG ulDataSize;
} WINCOMPATTRDATA_ACC;

typedef BOOL(WINAPI* SetWindowCompositionAttributeAcc)(
    HWND, WINCOMPATTRDATA_ACC*);

void EnableTransparentWindow(HWND hwnd) {
  const HINSTANCE user32 = LoadLibrary(TEXT("user32.dll"));
  if (user32 == nullptr) return;
  const auto set_window_composition_attribute =
      reinterpret_cast<SetWindowCompositionAttributeAcc>(
          GetProcAddress(user32, "SetWindowCompositionAttribute"));
  if (set_window_composition_attribute != nullptr) {
    ACCENT_POLICY_ACC policy = {ACCENT_ENABLE_TRANSPARENTGRADIENT_ACC, 2, 0, 0};
    WINCOMPATTRDATA_ACC data = {19, &policy, sizeof(policy)};
    set_window_composition_attribute(hwnd, &data);
  }
  FreeLibrary(user32);
}

}  // namespace

// The Flutter view is a child HWND that covers the client area; file drops
// land on IT, not on the top-level window, so its proc is subclassed to
// route WM_DROPFILES (and friends) into the bridge.
namespace {
NativeBridge* g_bridge = nullptr;
WNDPROC g_view_orig_proc = nullptr;

LRESULT CALLBACK PanelViewSubclassProc(HWND hwnd, UINT message, WPARAM wparam,
                                       LPARAM lparam) {
  if (g_bridge != nullptr && g_bridge->OnMessage(hwnd, message, wparam, lparam)) {
    return 0;
  }
  return CallWindowProc(g_view_orig_proc, hwnd, message, wparam, lparam);
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary
  // surface creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Right Panel native half: tray, clipboard watch, edge helpers...
  bridge_ = std::make_unique<NativeBridge>(GetHandle(), flutter_controller_.get());
  g_bridge = bridge_.get();

  EnableTransparentWindow(GetHandle());
  SetWindowPos(GetHandle(), HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  // Accept file drops on the Flutter view (the actual drop target).
  HWND view_hwnd = flutter_controller_->view()->GetNativeWindow();
  DragAcceptFiles(view_hwnd, TRUE);
  g_view_orig_proc = reinterpret_cast<WNDPROC>(
      SetWindowLongPtrW(view_hwnd, GWLP_WNDPROC,
                        reinterpret_cast<LONG_PTR>(PanelViewSubclassProc)));

  bridge_->Start();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    if (bridge_ && !bridge_->passthrough()) this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback
  // is registered. The following call ensures a frame is pending to ensure
  // the window is shown. It is a no-op if the first frame hasn't completed
  // yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (g_view_orig_proc != nullptr) {
    // restore the original proc if the view is still alive
    HWND view_hwnd = flutter_controller_ ? flutter_controller_->view()->GetNativeWindow() : nullptr;
    if (view_hwnd != nullptr) {
      SetWindowLongPtrW(view_hwnd, GWLP_WNDPROC,
                        reinterpret_cast<LONG_PTR>(g_view_orig_proc));
    }
    g_view_orig_proc = nullptr;
  }
  g_bridge = nullptr;
  // Clear channel handlers and join bridge workers while messenger still lives.
  bridge_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Taskbar activation and accessibility tools can focus the top-level host.
  // Keyboard input belongs to Flutter's child HWND, including after restore.
  if (message == WM_SETFOCUS && flutter_controller_) {
    SetFocus(flutter_controller_->view()->GetNativeWindow());
    return 0;
  }
  const bool display_change = message == WM_DPICHANGED || message == WM_DISPLAYCHANGE;
  if (bridge_ && display_change) bridge_->OnMessage(hwnd, message, wparam, lparam);
  // Give Flutter, including plugins, an opportunity to handle window
  // messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  // Native bridge messages: tray, cross-thread event queue, file drops.
  if (bridge_ && !display_change && bridge_->OnMessage(hwnd, message, wparam, lparam)) {
    return 0;
  }

  // Losing focus (the user clicked another app) closes the panel, exactly
  // like the original's WindowEvent::Focused(false) -> app.blur().
  if (message == WM_ACTIVATE && LOWORD(wparam) == WA_INACTIVE) {
    bridge_->NotifyBlur();
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
