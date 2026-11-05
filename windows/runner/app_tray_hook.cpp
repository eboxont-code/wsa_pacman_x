#include "app_tray_hook.h"

#include <shellapi.h>
#include <cwchar>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <cstdint>

namespace {
struct SavedWindow {
  WINDOWPLACEMENT placement{};
  HICON icon = nullptr;
  bool owns_icon = false;
};

SRWLOCK g_lock = SRWLOCK_INIT;
std::unordered_map<HWND, SavedWindow> g_hidden;
std::unordered_set<HWND> g_pending_close;
volatile LONG g_hook_execution_logged = 0;

void AppendHookDiagnostic(const wchar_t* message) {
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

  SYSTEMTIME now{};
  GetLocalTime(&now);
  wchar_t line[512] = {};
  const int length = swprintf_s(
      line, L"[%04u-%02u-%02u %02u:%02u:%02u] HOOK: %s\r\n",
      now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond,
      message);
  if (length > 0) {
    DWORD written = 0;
    WriteFile(file, line, static_cast<DWORD>(length * sizeof(wchar_t)),
              &written, nullptr);
  }
  CloseHandle(file);
}

void LogHookExecutionOnce(const wchar_t* callback_name) {
  if (InterlockedCompareExchange(&g_hook_execution_logged, 1, 0) != 0) {
    return;
  }
  wchar_t message[320] = {};
  swprintf_s(message, L"Hook DLL executed inside process. PID=%lu TID=%lu first_callback=%s",
             GetCurrentProcessId(), GetCurrentThreadId(), callback_name);
  AppendHookDiagnostic(message);
}

bool IsWsaClientWindow(HWND window) {
  if (window == nullptr || !IsWindow(window) ||
      (GetWindowLongPtrW(window, GWL_STYLE) & WS_CHILD) != 0) return false;

  DWORD pid = 0;
  if (GetWindowThreadProcessId(window, &pid) == 0 ||
      pid == 0 || pid != GetCurrentProcessId()) {
    AppendHookDiagnostic(L"Window rejected: HWND does not belong to the injected WsaClient process.");
    return false;
  }

  // This DLL is injected only into WsaClient.exe UI threads. Resolve the
  // current process image directly instead of reopening our own AppX process;
  // OpenProcess can be denied by package/process restrictions even though the
  // thread-specific hook itself was installed successfully.
  wchar_t path[32768] = {};
  const DWORD length = GetModuleFileNameW(nullptr, path,
                                           static_cast<DWORD>(_countof(path)));
  if (length == 0 || length >= _countof(path)) {
    AppendHookDiagnostic(L"Window rejected: could not resolve injected process image path.");
    return false;
  }

  const wchar_t* name = wcsrchr(path, L'\\');
  name = name == nullptr ? path : name + 1;
  const bool is_wsa_client =
      CompareStringOrdinal(name, -1, L"WsaClient.exe", -1, TRUE) == CSTR_EQUAL;
  if (!is_wsa_client) {
    AppendHookDiagnostic(L"Window rejected: injected process image is not WsaClient.exe.");
  }
  return is_wsa_client;
}

// Remove the native system-menu style from each WSA Android app window.
// Windows does not expose a supported way to remove only the X while keeping
// the standard Minimize/Maximize buttons: those controls are part of the same
// WS_SYSMENU caption feature. This intentionally removes the complete system
// menu and its caption buttons from WSA app windows only.
bool RemoveAppCloseControl(HWND window) {
  if (!IsWsaClientWindow(window)) return false;

  SetLastError(ERROR_SUCCESS);
  const LONG_PTR style = GetWindowLongPtrW(window, GWL_STYLE);
  if (style == 0 && GetLastError() != ERROR_SUCCESS) {
    AppendHookDiagnostic(L"Could not read WSA app window styles.");
    return false;
  }

  if ((style & WS_SYSMENU) == 0) return true;

  SetLastError(ERROR_SUCCESS);
  const LONG_PTR previous =
      SetWindowLongPtrW(window, GWL_STYLE, style & ~static_cast<LONG_PTR>(WS_SYSMENU));
  if (previous == 0 && GetLastError() != ERROR_SUCCESS) {
    const DWORD error = GetLastError();
    wchar_t diagnostic[192] = {};
    swprintf_s(diagnostic, L"Could not remove WS_SYSMENU from WSA app window; error=%lu.", error);
    AppendHookDiagnostic(diagnostic);
    return false;
  }

  if (!SetWindowPos(window, nullptr, 0, 0, 0, 0,
                    SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                    SWP_NOACTIVATE | SWP_FRAMECHANGED)) {
    const DWORD error = GetLastError();
    wchar_t diagnostic[192] = {};
    swprintf_s(diagnostic, L"WSA app frame refresh failed after removing X; error=%lu.", error);
    AppendHookDiagnostic(diagnostic);
    return false;
  }

  AppendHookDiagnostic(L"Removed WS_SYSMENU from WSA Android app window; X, Minimize, Maximize and system menu are hidden.");
  return true;
}


void DeleteTrayIcon(HWND window) {
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = window;
  data.uID = kWsaAppTrayIconId;
  Shell_NotifyIconW(NIM_DELETE, &data);
}

bool HideWindowToTray(HWND window) {
  if (!IsWsaClientWindow(window)) {
    AppendHookDiagnostic(L"Hide request rejected: window process is not WsaClient.exe.");
    return false;
  }
  if (!IsWindowVisible(window)) {
    AppendHookDiagnostic(L"Hide request rejected: WsaClient window is not visible.");
    return false;
  }

  AcquireSRWLockShared(&g_lock);
  const bool already_hidden = g_hidden.find(window) != g_hidden.end();
  ReleaseSRWLockShared(&g_lock);
  if (already_hidden) return true;

  SavedWindow saved;
  saved.placement.length = sizeof(WINDOWPLACEMENT);
  if (!GetWindowPlacement(window, &saved.placement)) return false;

  DWORD_PTR icon_value = 0;
  SendMessageTimeoutW(window, WM_GETICON, ICON_SMALL2, 0,
                      SMTO_ABORTIFHUNG | SMTO_BLOCK, 200, &icon_value);
  HICON source_icon = reinterpret_cast<HICON>(icon_value);
  if (source_icon == nullptr) {
    source_icon = reinterpret_cast<HICON>(GetClassLongPtrW(window, GCLP_HICONSM));
  }
  if (source_icon == nullptr) {
    source_icon = reinterpret_cast<HICON>(GetClassLongPtrW(window, GCLP_HICON));
  }
  if (source_icon != nullptr) {
    saved.icon = CopyIcon(source_icon);
    saved.owns_icon = saved.icon != nullptr;
  }
  if (saved.icon == nullptr) saved.icon = LoadIconW(nullptr, IDI_APPLICATION);

  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = window;
  data.uID = kWsaAppTrayIconId;
  data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  data.uCallbackMessage = kWsaAppTrayCallbackMessage;
  data.hIcon = saved.icon;

  wchar_t title[128] = {};
  GetWindowTextW(window, title, static_cast<int>(_countof(title)));
  if (title[0] == L'\0') wcscpy_s(title, L"Android app");
  wcsncpy_s(data.szTip, title, _TRUNCATE);

  if (!Shell_NotifyIconW(NIM_ADD, &data)) {
    const DWORD error = GetLastError();
    wchar_t diagnostic[256] = {};
    swprintf_s(diagnostic,
               L"Shell_NotifyIconW(NIM_ADD) failed for HWND=%p; Win32 error=%lu.",
               window, error);
    AppendHookDiagnostic(diagnostic);
    if (saved.owns_icon && saved.icon != nullptr) DestroyIcon(saved.icon);
    return false;
  }
  AppendHookDiagnostic(L"Per-app notification icon successfully added.");

  AcquireSRWLockExclusive(&g_lock);
  g_hidden[window] = saved;
  g_pending_close.erase(window);
  ReleaseSRWLockExclusive(&g_lock);

  // Hide only this one Android window. The WSA process and Android activity
  // are not terminated, so audio and background work can continue.
  ShowWindow(window, SW_HIDE);
  return true;
}

void RestoreWindowFromTray(HWND window) {
  SavedWindow saved;
  AcquireSRWLockExclusive(&g_lock);
  const auto found = g_hidden.find(window);
  if (found == g_hidden.end()) {
    ReleaseSRWLockExclusive(&g_lock);
    return;
  }
  saved = found->second;
  g_hidden.erase(found);
  ReleaseSRWLockExclusive(&g_lock);

  DeleteTrayIcon(window);
  if (IsWindow(window)) {
    WINDOWPLACEMENT placement = saved.placement;
    placement.length = sizeof(WINDOWPLACEMENT);
    if (!SetWindowPlacement(window, &placement)) ShowWindow(window, SW_SHOW);
    SetForegroundWindow(window);
  }
  if (saved.owns_icon && saved.icon != nullptr) DestroyIcon(saved.icon);
}

bool IsClosePending(HWND window) {
  AcquireSRWLockShared(&g_lock);
  const bool pending = g_pending_close.find(window) != g_pending_close.end();
  ReleaseSRWLockShared(&g_lock);
  return pending;
}
}  // namespace

extern "C" __declspec(dllexport) LRESULT CALLBACK WsaAppTrayCbtProc(
    int code, WPARAM wparam, LPARAM lparam) {
  LogHookExecutionOnce(L"WH_CBT");
  if (code == HCBT_ACTIVATE) {
    RemoveAppCloseControl(reinterpret_cast<HWND>(wparam));
  } else if (code == HCBT_SYSCOMMAND) {
    // For HCBT_SYSCOMMAND, wParam is the SC_* command, not an HWND.
    // This CBT hook is thread-specific, so GetActiveWindow returns the
    // WSA app window receiving the close command on this thread.
    const HWND window = GetActiveWindow();
    if ((static_cast<UINT>(wparam) & 0xFFF0) == SC_CLOSE) {
      AppendHookDiagnostic(L"WH_CBT received SC_CLOSE.");
      if (IsWsaClientWindow(window)) {
        if (HideWindowToTray(window)) return 1;
        AppendHookDiagnostic(L"SC_CLOSE was seen, but the app window could not be hidden.");
      } else {
        AppendHookDiagnostic(L"SC_CLOSE target was not recognized as WsaClient.exe.");
      }
    }
  } else if (code == HCBT_DESTROYWND) {
    const HWND window = reinterpret_cast<HWND>(wparam);
    if (IsClosePending(window)) {
      if (HideWindowToTray(window)) return 1;
      AcquireSRWLockExclusive(&g_lock);
      g_pending_close.erase(window);
      ReleaseSRWLockExclusive(&g_lock);
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}

extern "C" __declspec(dllexport) LRESULT CALLBACK WsaAppTrayGetMessageProc(
    int code, WPARAM wparam, LPARAM lparam) {
  LogHookExecutionOnce(L"WH_GETMESSAGE");
  if (code >= 0 && wparam == PM_REMOVE && lparam != 0) {
    auto message = reinterpret_cast<MSG*>(lparam);

    // The first queued message after hook installation also updates an
    // already-open Android window, even when it is already active.
    HWND candidate = message->hwnd != nullptr ? message->hwnd : GetActiveWindow();
    if (candidate != nullptr) RemoveAppCloseControl(candidate);

    if (message->message == kWsaAppTrayCallbackMessage &&
        message->wParam == kWsaAppTrayIconId &&
        (message->lParam == WM_LBUTTONUP ||
         message->lParam == WM_LBUTTONDBLCLK ||
         message->lParam == WM_RBUTTONUP)) {
      RestoreWindowFromTray(message->hwnd);
      message->message = WM_NULL;
      message->wParam = 0;
      message->lParam = 0;
    }

    // Some WSA window frameworks post WM_CLOSE (or queue SC_CLOSE) rather
    // than passing the X action through DefWindowProc's CBT system-command
    // path. Intercept those queued messages before WsaClient dispatches them.
    const bool queued_close =
        message->message == WM_CLOSE ||
        (message->message == WM_SYSCOMMAND &&
         (static_cast<UINT>(message->wParam) & 0xFFF0) == SC_CLOSE);
    if (queued_close && message->hwnd != nullptr) {
      AppendHookDiagnostic(
          message->message == WM_CLOSE
              ? L"WH_GETMESSAGE received queued WM_CLOSE for a WSA app window."
              : L"WH_GETMESSAGE received queued SC_CLOSE for a WSA app window.");
      if (HideWindowToTray(message->hwnd)) {
        message->message = WM_NULL;
        message->wParam = 0;
        message->lParam = 0;
        AppendHookDiagnostic(
            L"Queued Android app close intercepted; close message replaced with WM_NULL.");
      } else {
        AppendHookDiagnostic(
            L"Queued Android app close could not be converted to a tray hide; original close message will continue.");
      }
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}

extern "C" __declspec(dllexport) LRESULT CALLBACK WsaAppTrayCallWndProc(
    int code, WPARAM wparam, LPARAM lparam) {
  LogHookExecutionOnce(L"WH_CALLWNDPROC");
  if (code >= 0 && lparam != 0) {
    const auto message = reinterpret_cast<const CWPSTRUCT*>(lparam);
    if (message->message == kWsaAppTrayRestoreManagerMessage) {
      RestoreWindowFromTray(message->hwnd);
    } else if (message->message == WM_CLOSE &&
               IsWsaClientWindow(message->hwnd)) {
      AppendHookDiagnostic(L"WH_CALLWNDPROC received WM_CLOSE for WsaClient window.");
      AcquireSRWLockExclusive(&g_lock);
      g_pending_close.insert(message->hwnd);
      ReleaseSRWLockExclusive(&g_lock);
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}

extern "C" __declspec(dllexport) LRESULT CALLBACK WsaAppTrayCallWndRetProc(
    int code, WPARAM wparam, LPARAM lparam) {
  LogHookExecutionOnce(L"WH_CALLWNDPROCRET");
  if (code >= 0 && lparam != 0) {
    const auto message = reinterpret_cast<const CWPRETSTRUCT*>(lparam);
    if (message->message == WM_CLOSE) {
      AcquireSRWLockExclusive(&g_lock);
      if (g_hidden.find(message->hwnd) == g_hidden.end()) {
        g_pending_close.erase(message->hwnd);
      }
      ReleaseSRWLockExclusive(&g_lock);
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}
