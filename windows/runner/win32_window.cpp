#include "win32_window.h"

#include <flutter_windows.h>

#include "resource.h"
#include "app_tray_hook.h"
#include <shellapi.h>
#include <algorithm>
#include <vector>
#include <sstream>

namespace {

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

constexpr UINT kTrayCallbackMessage = WM_APP + 1;
constexpr UINT kTrayIconId = 1;
constexpr UINT kTrayShowCommand = 0x5001;
constexpr UINT kTrayExitCommand = 0x5002;

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

void AppendTrayDiagnostic(const std::wstring& message) {
  wchar_t temp_path[MAX_PATH + 1] = {};
  const DWORD path_length =
      GetTempPathW(static_cast<DWORD>(_countof(temp_path)), temp_path);
  if (path_length == 0 || path_length >= _countof(temp_path)) return;

  std::wstring log_path(temp_path, path_length);
  if (log_path.back() != L'\\' && log_path.back() != L'/') {
    log_path.push_back(L'\\');
  }
  log_path += L"WsaPacMan-AppTray-Diagnostics.log";

  HANDLE file = CreateFileW(log_path.c_str(), GENERIC_READ | FILE_APPEND_DATA,
                            FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr,
                            OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) return;

  LARGE_INTEGER file_size{};
  if (GetFileSizeEx(file, &file_size) && file_size.QuadPart == 0) {
    const wchar_t bom = 0xFEFF;
    DWORD written = 0;
    WriteFile(file, &bom, sizeof(bom), &written, nullptr);
  }

  SYSTEMTIME now{};
  GetLocalTime(&now);
  wchar_t timestamp[64] = {};
  swprintf_s(timestamp, L"[%04u-%02u-%02u %02u:%02u:%02u] ",
             now.wYear, now.wMonth, now.wDay,
             now.wHour, now.wMinute, now.wSecond);
  const std::wstring line = std::wstring(timestamp) + message + L"\r\n";
  DWORD written = 0;
  WriteFile(file, line.data(),
            static_cast<DWORD>(line.size() * sizeof(wchar_t)),
            &written, nullptr);
  CloseHandle(file);
}

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
    FreeLibrary(user32_module);
  }
}

}  // namespace

std::wstring Win32Window::ResolveWsaClientExecutablePath() {
  auto read_registry_string = [](HKEY root, const wchar_t* sub_key,
                                 const wchar_t* value_name) -> std::wstring {
    DWORD byte_count = 0;
    const DWORD flags = RRF_RT_REG_SZ | RRF_RT_REG_EXPAND_SZ;
    if (RegGetValueW(root, sub_key, value_name, flags, nullptr, nullptr,
                     &byte_count) != ERROR_SUCCESS ||
        byte_count < sizeof(wchar_t)) {
      return {};
    }

    std::vector<wchar_t> value(byte_count / sizeof(wchar_t) + 1, L'\0');
    if (RegGetValueW(root, sub_key, value_name, flags, nullptr, value.data(),
                     &byte_count) != ERROR_SUCCESS) {
      return {};
    }
    return std::wstring(value.data());
  };

  // Match the package-path resolution already used by Env.WSA_EXECUTABLE in
  // the Dart application. Prefer the WSA service registration, then App Paths.
  std::wstring registered_path = read_registry_string(
      HKEY_LOCAL_MACHINE,
      L"SYSTEM\\CurrentControlSet\\Services\\WsaService", L"ImagePath");
  if (registered_path.empty()) {
    registered_path = read_registry_string(
        HKEY_CURRENT_USER,
        L"Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\WsaClient.exe",
        nullptr);
  }
  if (registered_path.empty()) {
    return {};
  }

  const size_t first_non_space = registered_path.find_first_not_of(L" \t\r\n");
  if (first_non_space == std::wstring::npos) {
    return {};
  }
  registered_path.erase(0, first_non_space);

  // A service ImagePath can be quoted and may include command-line arguments.
  if (!registered_path.empty() && registered_path.front() == L'"') {
    const size_t closing_quote = registered_path.find(L'"', 1);
    if (closing_quote != std::wstring::npos) {
      registered_path = registered_path.substr(1, closing_quote - 1);
    }
  } else {
    const size_t exe_extension = registered_path.find(L".exe");
    if (exe_extension != std::wstring::npos) {
      registered_path.resize(exe_extension + 4);
    }
  }

  if (registered_path.rfind(L"\\??\\", 0) == 0) {
    registered_path.erase(0, 4);
  } else if (registered_path.rfind(L"\\\\?\\", 0) == 0) {
    registered_path.erase(0, 4);
  }

  const std::wstring system_root_prefix = L"\\SystemRoot\\";
  if (registered_path.rfind(system_root_prefix, 0) == 0) {
    wchar_t windows_directory[MAX_PATH + 1] = {};
    const UINT length = GetWindowsDirectoryW(
        windows_directory, static_cast<UINT>(MAX_PATH + 1));
    if (length == 0 || length >= MAX_PATH + 1) {
      return {};
    }
    registered_path = std::wstring(windows_directory) + L"\\" +
                      registered_path.substr(system_root_prefix.size());
  }

  const size_t last_separator = registered_path.find_last_of(L"\\/");
  if (last_separator == std::wstring::npos || last_separator == 0) {
    return {};
  }
  const size_t parent_separator =
      registered_path.find_last_of(L"\\/", last_separator - 1);
  if (parent_separator == std::wstring::npos) {
    return {};
  }

  const std::wstring package_root = registered_path.substr(0, parent_separator);
  return package_root + L"\\WsaClient\\WsaClient.exe";
}

std::wstring Win32Window::GetProcessImagePath(DWORD process_id) {
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                               process_id);
  if (process == nullptr) {
    return {};
  }

  std::vector<wchar_t> image_path(32768, L'\0');
  DWORD character_count = static_cast<DWORD>(image_path.size());
  const BOOL queried = QueryFullProcessImageNameW(
      process, 0, image_path.data(), &character_count);
  CloseHandle(process);

  if (!queried || character_count == 0) {
    return {};
  }
  return std::wstring(image_path.data(), character_count);
}

bool Win32Window::IsWsaAppWindow(HWND window, DWORD* process_id) {
  if (window == nullptr || !IsWindow(window) || window == window_handle_) {
    return false;
  }

  const LONG_PTR style = GetWindowLongPtrW(window, GWL_STYLE);
  if ((style & WS_CHILD) != 0) {
    return false;
  }

  DWORD pid = 0;
  if (GetWindowThreadProcessId(window, &pid) == 0 || pid == 0 ||
      pid == GetCurrentProcessId()) {
    return false;
  }

  if (wsa_client_executable_path_.empty()) {
    wsa_client_executable_path_ = ResolveWsaClientExecutablePath();
  }

  const std::wstring image_path = GetProcessImagePath(pid);
  if (image_path.empty()) return false;

  // Match the WSA client by executable name so versioned WindowsApps paths
  // cannot silently exclude its app windows after a package update.
  const size_t image_name_start = image_path.find_last_of(L"\\/");
  const wchar_t* image_name = image_name_start == std::wstring::npos
                                  ? image_path.c_str()
                                  : image_path.c_str() + image_name_start + 1;
  if (CompareStringOrdinal(image_name, -1, L"WsaClient.exe", -1, TRUE) !=
      CSTR_EQUAL) {
    return false;
  }

  if (!wsa_client_executable_path_.empty() &&
      CompareStringOrdinal(image_path.c_str(), -1,
                           wsa_client_executable_path_.c_str(), -1, TRUE) !=
          CSTR_EQUAL) {
    std::wstringstream diagnostic;
    diagnostic << L"WSA process accepted by executable name; path differs. "
               << L"Expected=" << wsa_client_executable_path_
               << L"; actual=" << image_path;
    AppendTrayDiagnostic(diagnostic.str());
  }

  if (process_id != nullptr) {
    *process_id = pid;
  }
  return true;
}

void Win32Window::LogWindowDiagnostic(HWND window) {
  if (window == nullptr || !IsWindow(window) || !IsWindowVisible(window) ||
      !diagnosed_windows_.insert(window).second) {
    return;
  }

  DWORD process_id = 0;
  const DWORD thread_id = GetWindowThreadProcessId(window, &process_id);
  const std::wstring image_path =
      process_id == 0 ? std::wstring() : GetProcessImagePath(process_id);
  wchar_t title[256] = {};
  wchar_t class_name[256] = {};
  GetWindowTextW(window, title, static_cast<int>(_countof(title)));
  GetClassNameW(window, class_name, static_cast<int>(_countof(class_name)));

  std::wstringstream diagnostic;
  diagnostic << L"Visible top-level window: PID=" << process_id
             << L" TID=" << thread_id << L" HWND=" << window
             << L" class=" << class_name << L" title=" << title
             << L" image=" << (image_path.empty() ? L"<unavailable>" : image_path);
  AppendTrayDiagnostic(diagnostic.str());
}

BOOL CALLBACK Win32Window::EnumerateWsaWindows(HWND window, LPARAM parameter) {
  auto manager = reinterpret_cast<Win32Window*>(parameter);
  if (manager != nullptr) {
    manager->LogWindowDiagnostic(window);
    manager->InstallWsaAppHookForWindow(window);
  }
  return TRUE;
}

BOOL CALLBACK Win32Window::RestoreAppTrayWindowsBeforeExit(HWND window,
                                                            LPARAM parameter) {
  auto manager = reinterpret_cast<Win32Window*>(parameter);
  if (manager != nullptr && manager->IsWsaAppWindow(window, nullptr)) {
    DWORD_PTR result = 0;
    SendMessageTimeoutW(window, kWsaAppTrayRestoreManagerMessage, 0, 0,
                        SMTO_ABORTIFHUNG | SMTO_BLOCK, 500, &result);
  }
  return TRUE;
}

void Win32Window::InstallWsaAppHookForWindow(HWND window) {
  DWORD process_id = 0;
  if (!IsWsaAppWindow(window, &process_id)) return;
  const DWORD thread_id = GetWindowThreadProcessId(window, nullptr);
  if (thread_id == 0 || wsa_thread_hooks_.count(thread_id) != 0) return;

  // A transient load/injection failure must not permanently disable a WSA
  // thread. The scan timer retries after a short cooldown while WSA starts.
  const ULONGLONG now = GetTickCount64();
  const auto retry = wsa_hook_retry_after_.find(thread_id);
  if (retry != wsa_hook_retry_after_.end()) {
    if (now < retry->second) return;
    wsa_hook_retry_after_.erase(retry);
  }

  std::wstringstream candidate_diagnostic;
  candidate_diagnostic << L"Attempting per-app hooks for WsaClient window HWND="
                       << window << L" PID=" << process_id
                       << L" TID=" << thread_id;
  AppendTrayDiagnostic(candidate_diagnostic.str());

  if (app_tray_hook_module_ == nullptr) {
    wchar_t path[32768] = {};
    const DWORD length = GetModuleFileNameW(nullptr, path,
                                             static_cast<DWORD>(_countof(path)));
    if (length == 0 || length >= _countof(path)) {
      AppendTrayDiagnostic(L"Could not resolve the WSA PacMan executable path for the app tray hook DLL; retrying in 10 seconds.");
      wsa_hook_retry_after_[thread_id] = GetTickCount64() + 10000;
      return;
    }
    std::wstring dll_path(path, length);
    const size_t slash = dll_path.find_last_of(L"\\/");
    if (slash == std::wstring::npos) {
      AppendTrayDiagnostic(L"Could not resolve the WSA PacMan executable directory for the app tray hook DLL; retrying in 10 seconds.");
      wsa_hook_retry_after_[thread_id] = GetTickCount64() + 10000;
      return;
    }
    dll_path.resize(slash + 1);
    dll_path += L"WsaPacManAppTrayHook.dll";
    app_tray_hook_module_ = LoadLibraryW(dll_path.c_str());
    if (app_tray_hook_module_ == nullptr) {
      const DWORD error = GetLastError();
      std::wstringstream diagnostic;
      diagnostic << L"Could not load app tray hook DLL: " << dll_path
                 << L"; Win32 error=" << error;
      AppendTrayDiagnostic(diagnostic.str());
      wsa_hook_retry_after_[thread_id] = GetTickCount64() + 10000;
      OutputDebugStringW(L"WSA PacMan: per-app tray hook DLL could not be loaded.\n");
      return;
    }
  }

  const auto cbt = reinterpret_cast<HOOKPROC>(
      GetProcAddress(app_tray_hook_module_, "WsaAppTrayCbtProc"));
  const auto get_message = reinterpret_cast<HOOKPROC>(
      GetProcAddress(app_tray_hook_module_, "WsaAppTrayGetMessageProc"));
  const auto call_wnd = reinterpret_cast<HOOKPROC>(
      GetProcAddress(app_tray_hook_module_, "WsaAppTrayCallWndProc"));
  const auto call_wnd_ret = reinterpret_cast<HOOKPROC>(
      GetProcAddress(app_tray_hook_module_, "WsaAppTrayCallWndRetProc"));
  if (!cbt || !get_message || !call_wnd || !call_wnd_ret) {
    AppendTrayDiagnostic(L"App tray hook DLL exports are incomplete; retrying this WsaClient thread in 10 seconds.");
    wsa_hook_retry_after_[thread_id] = GetTickCount64() + 10000;
    OutputDebugStringW(L"WSA PacMan: per-app tray hook DLL exports are incomplete.\n");
    return;
  }

  WsaThreadHooks hooks;
  SetLastError(ERROR_SUCCESS);
  hooks.cbt = SetWindowsHookExW(WH_CBT, cbt, app_tray_hook_module_, thread_id);
  const DWORD cbt_error = hooks.cbt ? ERROR_SUCCESS : GetLastError();
  SetLastError(ERROR_SUCCESS);
  hooks.get_message = SetWindowsHookExW(WH_GETMESSAGE, get_message,
                                         app_tray_hook_module_, thread_id);
  const DWORD get_message_error =
      hooks.get_message ? ERROR_SUCCESS : GetLastError();
  SetLastError(ERROR_SUCCESS);
  hooks.call_wnd = SetWindowsHookExW(WH_CALLWNDPROC, call_wnd,
                                      app_tray_hook_module_, thread_id);
  const DWORD call_wnd_error =
      hooks.call_wnd ? ERROR_SUCCESS : GetLastError();
  SetLastError(ERROR_SUCCESS);
  hooks.call_wnd_ret = SetWindowsHookExW(WH_CALLWNDPROCRET, call_wnd_ret,
                                          app_tray_hook_module_, thread_id);
  const DWORD call_wnd_ret_error =
      hooks.call_wnd_ret ? ERROR_SUCCESS : GetLastError();

  std::wstringstream hook_diagnostic;
  hook_diagnostic << L"Hook registration PID=" << process_id
                  << L" TID=" << thread_id
                  << L" CBT=" << (hooks.cbt ? L"OK" : L"FAIL")
                  << L"/" << cbt_error
                  << L" GETMESSAGE=" << (hooks.get_message ? L"OK" : L"FAIL")
                  << L"/" << get_message_error
                  << L" CALLWND=" << (hooks.call_wnd ? L"OK" : L"FAIL")
                  << L"/" << call_wnd_error
                  << L" CALLWNDRET=" << (hooks.call_wnd_ret ? L"OK" : L"FAIL")
                  << L"/" << call_wnd_ret_error;
  AppendTrayDiagnostic(hook_diagnostic.str());

  if (!hooks.cbt || !hooks.get_message || !hooks.call_wnd || !hooks.call_wnd_ret) {
    if (hooks.cbt) UnhookWindowsHookEx(hooks.cbt);
    if (hooks.get_message) UnhookWindowsHookEx(hooks.get_message);
    if (hooks.call_wnd) UnhookWindowsHookEx(hooks.call_wnd);
    if (hooks.call_wnd_ret) UnhookWindowsHookEx(hooks.call_wnd_ret);
    wsa_hook_retry_after_[thread_id] = GetTickCount64() + 10000;
    OutputDebugStringW(L"WSA PacMan: Windows rejected a per-app tray hook; retrying after cooldown.\n");
    return;
  }
  wsa_hook_retry_after_.erase(thread_id);
  wsa_thread_hooks_.emplace(thread_id, hooks);
}

void Win32Window::InstallWsaAppHooks() {
  if (!close_to_tray_) return;
  if (wsa_client_executable_path_.empty()) {
    wsa_client_executable_path_ = ResolveWsaClientExecutablePath();
  }

  static std::wstring last_logged_expected_path;
  if (last_logged_expected_path != wsa_client_executable_path_) {
    std::wstringstream diagnostic;
    diagnostic << L"Expected WsaClient path="
               << (wsa_client_executable_path_.empty()
                       ? L"<unresolved>"
                       : wsa_client_executable_path_);
    AppendTrayDiagnostic(diagnostic.str());
    last_logged_expected_path = wsa_client_executable_path_;
  }

  // Always enumerate: a versioned package path mismatch must not prevent
  // matching the actual WsaClient.exe process by its executable name.
  EnumWindows(&Win32Window::EnumerateWsaWindows,
              reinterpret_cast<LPARAM>(this));
}

void Win32Window::RemoveWsaAppHooks() {
  if (hook_scan_timer_id_ != 0 && window_handle_ != nullptr) {
    KillTimer(window_handle_, hook_scan_timer_id_);
    hook_scan_timer_id_ = 0;
  }
  if (app_tray_hook_module_ != nullptr && window_handle_ != nullptr) {
    EnumWindows(&Win32Window::RestoreAppTrayWindowsBeforeExit,
                reinterpret_cast<LPARAM>(this));
  }
  for (const auto& entry : wsa_thread_hooks_) {
    const WsaThreadHooks& hooks = entry.second;
    if (hooks.call_wnd_ret) UnhookWindowsHookEx(hooks.call_wnd_ret);
    if (hooks.call_wnd) UnhookWindowsHookEx(hooks.call_wnd);
    if (hooks.get_message) UnhookWindowsHookEx(hooks.get_message);
    if (hooks.cbt) UnhookWindowsHookEx(hooks.cbt);
  }
  wsa_thread_hooks_.clear();
  wsa_hook_retry_after_.clear();
  if (app_tray_hook_module_ != nullptr) {
    FreeLibrary(app_tray_hook_module_);
    app_tray_hook_module_ = nullptr;
  }
}

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  RemoveWsaAppHooks();
  --g_active_window_count;
  Destroy();
}

bool Win32Window::CreateAndShow(const std::wstring& title,
                                const Point& origin,
                                const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW | WS_VISIBLE,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  if (!OnCreate()) {
    return false;
  }

  update_shutdown_message_ = RegisterWindowMessageW(L"WSA.PacMan.PrepareForUpgrade.1");

  if (close_to_tray_) {
    taskbar_created_message_ = RegisterWindowMessageW(L"TaskbarCreated");
    if (!AddTrayIcon()) {
      OutputDebugStringW(L"WSA PacMan: could not register notification-area icon.\\n");
    }
    InstallWsaAppHooks();
    hook_scan_timer_id_ = SetTimer(window_handle_, 0xA11, 1000, nullptr);
  }

  return true;
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
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
  if (update_shutdown_message_ != 0 && message == update_shutdown_message_) {
    ExitApplication();
    return 0;
  }

  if (taskbar_created_message_ != 0 && message == taskbar_created_message_) {
    tray_icon_added_ = false;
    if (close_to_tray_) {
      if (AddTrayIcon()) {
        // If tray registration previously failed, move a taskbar-minimized
        // manager into the notification area now that Explorer is ready.
        if (IsIconic(hwnd)) {
          ShowWindow(hwnd, SW_HIDE);
        }
      } else {
        // Explorer may be restarting. Keep the manager reachable if the icon
        // cannot be restored; close will continue to fall back to taskbar-minimize.
        ShowWindow(hwnd, SW_RESTORE);
        OutputDebugStringW(L"WSA PacMan: notification-area icon could not be restored.\\n");
      }
    }
    return 0;
  }

  switch (message) {
    case WM_CLOSE:
      if (close_to_tray_ && !exit_requested_) {
        
        // Hide only when the notification icon exists. Otherwise keep the
        // process alive in the taskbar until Explorer can register the icon.
        ShowWindow(hwnd, tray_icon_added_ ? SW_HIDE : SW_MINIMIZE);
        return 0;
      }
      break;

    case WM_SYSCOMMAND:
      // bitsdojo_window's CloseWindowButton sends SC_CLOSE directly.
      if (close_to_tray_ && !exit_requested_ &&
          (wparam & 0xFFF0) == SC_CLOSE) {
        
        ShowWindow(hwnd, tray_icon_added_ ? SW_HIDE : SW_MINIMIZE);
        return 0;
      }
      break;

    case WM_DESTROY:
      RemoveWsaAppHooks();
      RemoveTrayIcon();
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_COMMAND:
      switch (LOWORD(wparam)) {
        case kTrayShowCommand:
          ShowFromTray();
          return 0;
        case kTrayExitCommand:
          ExitApplication();
          return 0;
      }
      break;

    case kTrayCallbackMessage:
      switch (lparam) {
        case WM_LBUTTONUP:
        case WM_LBUTTONDBLCLK:
          ShowFromTray();
          return 0;
        case WM_RBUTTONUP:
        case WM_CONTEXTMENU:
          ShowTrayMenu();
          return 0;
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
      if (wparam == SIZE_MINIMIZED && close_to_tray_) {
        
        if (tray_icon_added_) {
          ShowWindow(hwnd, SW_HIDE);
        }
        return 0;
      }

      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_TIMER:
      if (wparam == 0xA11) {
        InstallWsaAppHooks();
        return 0;
      }
      break;

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::ExitApplication() {
  if (exit_requested_) {
    return;
  }

  exit_requested_ = true;
  close_to_tray_ = false;
  // Explicit Exit must not strand invisible Android apps. Return their
  // windows to the user before terminating the PacMan manager.
  
  RemoveWsaAppHooks();
  RemoveTrayIcon();

  if (window_handle_ != nullptr) {
    DestroyWindow(window_handle_);
  } else if (quit_on_close_) {
    PostQuitMessage(0);
  }
}

void Win32Window::Destroy() {
  RemoveTrayIcon();
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
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

void Win32Window::SetCloseToTray(bool close_to_tray) {
  close_to_tray_ = close_to_tray;
}

bool Win32Window::AddTrayIcon() {
  if (window_handle_ == nullptr) {
    return false;
  }
  if (tray_icon_added_) {
    return true;
  }

  NOTIFYICONDATAW icon_data = {};
  icon_data.cbSize = sizeof(icon_data);
  icon_data.hWnd = window_handle_;
  icon_data.uID = kTrayIconId;
  icon_data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  icon_data.uCallbackMessage = kTrayCallbackMessage;
  icon_data.hIcon = LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON));
  if (icon_data.hIcon == nullptr) {
    icon_data.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
  }
  wcscpy_s(icon_data.szTip, L"WSA PacMan - running in background");

  tray_icon_added_ = Shell_NotifyIconW(NIM_ADD, &icon_data) == TRUE;
  return tray_icon_added_;
}

void Win32Window::RemoveTrayIcon() {
  if (!tray_icon_added_) {
    return;
  }

  NOTIFYICONDATAW icon_data = {};
  icon_data.cbSize = sizeof(icon_data);
  icon_data.hWnd = window_handle_;
  icon_data.uID = kTrayIconId;
  Shell_NotifyIconW(NIM_DELETE, &icon_data);
  tray_icon_added_ = false;
}

void Win32Window::ShowFromTray() {
  if (window_handle_ == nullptr) {
    return;
  }

  // Restore a minimized window, but use SW_SHOW for a window hidden
  // from the red X so an already-maximized window remains maximized.
  ShowWindow(window_handle_, IsIconic(window_handle_) ? SW_RESTORE : SW_SHOW);
  
  SetForegroundWindow(window_handle_);
}

void Win32Window::ShowTrayMenu() {
  if (window_handle_ == nullptr || !tray_icon_added_) {
    return;
  }

  HMENU menu = CreatePopupMenu();
  if (menu == nullptr) {
    return;
  }

  AppendMenuW(menu, MF_STRING, kTrayShowCommand, L"Show WSA PacMan");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kTrayExitCommand, L"Exit WSA PacMan");

  POINT cursor = {};
  GetCursorPos(&cursor);
  SetForegroundWindow(window_handle_);
  const UINT selected_command = static_cast<UINT>(
      TrackPopupMenu(menu,
                     TPM_RIGHTBUTTON | TPM_LEFTALIGN | TPM_BOTTOMALIGN |
                         TPM_RETURNCMD,
                     cursor.x, cursor.y, 0, window_handle_, nullptr));
  DestroyMenu(menu);

  // Dispatch after TrackPopupMenu returns to avoid destroying the owner HWND
  // while the native popup-menu loop is still active.
  PostMessageW(window_handle_, WM_NULL, 0, 0);
  if (selected_command != 0) {
    PostMessageW(window_handle_, WM_COMMAND,
                 MAKEWPARAM(selected_command, 0), 0);
  }
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}
