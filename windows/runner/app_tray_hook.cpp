#include "app_tray_hook.h"

#include <shellapi.h>
#include <cwchar>
#include <unordered_map>
#include <unordered_set>

namespace {
struct SavedWindow {
  WINDOWPLACEMENT placement{};
  HICON icon = nullptr;
  bool owns_icon = false;
};

SRWLOCK g_lock = SRWLOCK_INIT;
std::unordered_map<HWND, SavedWindow> g_hidden;
std::unordered_set<HWND> g_pending_close;

bool IsWsaClientWindow(HWND window) {
  if (window == nullptr || !IsWindow(window) ||
      (GetWindowLongPtrW(window, GWL_STYLE) & WS_CHILD) != 0) return false;

  DWORD pid = 0;
  if (GetWindowThreadProcessId(window, &pid) == 0 || pid == 0) return false;
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == nullptr) return false;

  wchar_t path[32768] = {};
  DWORD length = static_cast<DWORD>(_countof(path));
  const BOOL queried = QueryFullProcessImageNameW(process, 0, path, &length);
  CloseHandle(process);
  if (!queried || length == 0) return false;

  const wchar_t* name = wcsrchr(path, L'\\');
  name = name == nullptr ? path : name + 1;
  return CompareStringOrdinal(name, -1, L"WsaClient.exe", -1, TRUE) == CSTR_EQUAL;
}

void DeleteTrayIcon(HWND window) {
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = window;
  data.uID = kWsaAppTrayIconId;
  Shell_NotifyIconW(NIM_DELETE, &data);
}

bool HideWindowToTray(HWND window) {
  if (!IsWsaClientWindow(window) || !IsWindowVisible(window)) return false;

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
    if (saved.owns_icon && saved.icon != nullptr) DestroyIcon(saved.icon);
    return false;
  }

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
  if (code == HCBT_SYSCOMMAND) {
    // For HCBT_SYSCOMMAND, wParam is the SC_* command, not an HWND.
    // This CBT hook is thread-specific, so GetActiveWindow returns the
    // WSA app window receiving the close command on this thread.
    const HWND window = GetActiveWindow();
    if ((static_cast<UINT>(wparam) & 0xFFF0) == SC_CLOSE &&
        IsWsaClientWindow(window) && HideWindowToTray(window)) return 1;
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
  if (code >= 0 && wparam == PM_REMOVE && lparam != 0) {
    auto message = reinterpret_cast<MSG*>(lparam);
    if (message->message == kWsaAppTrayCallbackMessage &&
        message->wParam == kWsaAppTrayIconId &&
        (message->lParam == WM_LBUTTONUP ||
         message->lParam == WM_LBUTTONDBLCLK ||
         message->lParam == WM_RBUTTONUP)) {
      RestoreWindowFromTray(message->hwnd);
      message->message = WM_NULL;
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}

extern "C" __declspec(dllexport) LRESULT CALLBACK WsaAppTrayCallWndProc(
    int code, WPARAM wparam, LPARAM lparam) {
  if (code >= 0 && lparam != 0) {
    const auto message = reinterpret_cast<const CWPSTRUCT*>(lparam);
    if (message->message == kWsaAppTrayRestoreManagerMessage) {
      RestoreWindowFromTray(message->hwnd);
    } else if (message->message == WM_CLOSE &&
               IsWsaClientWindow(message->hwnd)) {
      AcquireSRWLockExclusive(&g_lock);
      g_pending_close.insert(message->hwnd);
      ReleaseSRWLockExclusive(&g_lock);
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}

extern "C" __declspec(dllexport) LRESULT CALLBACK WsaAppTrayCallWndRetProc(
    int code, WPARAM wparam, LPARAM lparam) {
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
