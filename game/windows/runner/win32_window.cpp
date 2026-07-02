#include "win32_window.h"

#include <flutter_windows.h>

#include "resource.h"

namespace {

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  bool result = ::SetProcessDpiAwarenessContext(
      DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
  if (!result) {
    ::SetProcessDpiAwareness(PROCESS_PER_MONITOR_DPI_AWARE);
  }
}

}  // namespace

Win32Window::Win32Window() {}

Win32Window::~Win32Window() {
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class = GetWindowClass();
  RegisterWindowClass();

  RECT wr;
  wr.left = origin.x;
  wr.top = origin.y;
  wr.right = origin.x + size.width;
  wr.bottom = origin.y + size.height;

  AdjustWindowRect(&wr, WS_OVERLAPPEDWINDOW, FALSE);

  auto g_hInst = GetModuleHandle(nullptr);

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      wr.left, wr.top, wr.right - wr.left, wr.bottom - wr.top,
      nullptr, nullptr, g_hInst, this);

  if (!window) {
    return false;
  }

  return OnCreate();
}

const wchar_t* Win32Window::GetWindowClass() {
  return kWindowClassName;
}

void Win32Window::RegisterWindowClass() {
  EnableFullDpiSupportIfAvailable(window_handle_);

  const wchar_t* window_class = GetWindowClass();
  WNDCLASS window_class_desc = {};
  window_class_desc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class_desc.lpszClassName = window_class;
  window_class_desc.style = CS_HREDRAW | CS_VREDRAW;
  window_class_desc.cbClsExtra = 0;
  window_class_desc.cbWndExtra = 0;
  window_class_desc.hInstance = GetModuleHandle(nullptr);
  window_class_desc.hIcon =
      LoadIcon(window_class_desc.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
  window_class_desc.hbrBackground = 0;
  window_class_desc.lpszMenuName = nullptr;
  window_class_desc.lpfnWndProc = WndProc;
  RegisterClass(&window_class_desc);
}

void Win32Window::UnregisterWindowClass() {
  UnregisterClass(GetWindowClass(), nullptr);
}

LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto cs = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(cs->lpCreateParams));

    auto that = static_cast<Win32Window*>(cs->lpCreateParams);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      OnDestroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOMPOSITIONCHANGED:
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }

  UnregisterWindowClass();
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  return true;
}

void Win32Window::OnDestroy() {}

void Win32Window::Show() {
  ShowWindow(window_handle_, SW_SHOWNORMAL);
}
