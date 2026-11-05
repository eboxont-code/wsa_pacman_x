#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>
#include <string>
#include <unordered_map>
#include <unordered_set>

class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };
  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height) : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();
  bool CreateAndShow(const std::wstring& title, const Point& origin,
                     const Size& size);
  void Destroy();
  void SetChildContent(HWND content);
  HWND GetHandle();
  void SetQuitOnClose(bool quit_on_close);
  void SetCloseToTray(bool close_to_tray);
  RECT GetClientArea();

 protected:
  virtual LRESULT MessageHandler(HWND window, UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;
  virtual bool OnCreate();
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;
  static LRESULT CALLBACK WndProc(HWND const window, UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;
  static BOOL CALLBACK EnumerateWsaWindows(HWND window, LPARAM parameter);
  void LogWindowDiagnostic(HWND window);
  static BOOL CALLBACK RestoreAppTrayWindowsBeforeExit(HWND window,
                                                        LPARAM parameter);

  struct WsaThreadHooks {
    HHOOK cbt = nullptr;
    HHOOK get_message = nullptr;
    HHOOK call_wnd = nullptr;
    HHOOK call_wnd_ret = nullptr;
  };

  bool quit_on_close_ = false;
  bool close_to_tray_ = false;
  bool tray_icon_added_ = false;
  bool exit_requested_ = false;
  UINT taskbar_created_message_ = 0;
  UINT update_shutdown_message_ = 0;
  UINT_PTR hook_scan_timer_id_ = 0;
  HMODULE app_tray_hook_module_ = nullptr;
  std::wstring wsa_client_executable_path_;
  std::unordered_map<DWORD, WsaThreadHooks> wsa_thread_hooks_;
  std::unordered_map<DWORD, ULONGLONG> wsa_hook_retry_after_;
  std::unordered_set<HWND> diagnosed_windows_;

  std::wstring ResolveWsaClientExecutablePath();
  std::wstring GetProcessImagePath(DWORD process_id);
  bool IsWsaAppWindow(HWND window, DWORD* process_id = nullptr);
  void InstallWsaAppHooks();
  void InstallWsaAppHookForWindow(HWND window);
  void RemoveWsaAppHooks();

  bool AddTrayIcon();
  void RemoveTrayIcon();
  void ShowFromTray();
  void ShowTrayMenu();
  void ExitApplication();

  HWND window_handle_ = nullptr;
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_
