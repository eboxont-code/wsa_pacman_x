#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>
#include <shellapi.h>

#include <functional>
#include <memory>
#include <string>

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
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  bool CreateAndShow(const std::wstring& title,
                     const Point& origin,
                     const Size& size);
  void Destroy();
  void SetChildContent(HWND content);
  HWND GetHandle();

  void SetQuitOnClose(bool quit_on_close);
  void ExitApplication();
  RECT GetClientArea();

 protected:
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;
  virtual bool OnCreate();
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;

  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  void AddTrayIcon();
  void RemoveTrayIcon();
  void ShowFromTray();
  void ShowTrayMenu();

  bool quit_on_close_ = false;
  bool tray_icon_added_ = false;
  UINT taskbar_created_message_ = 0;
  NOTIFYICONDATAW tray_icon_data_{};

  HWND window_handle_ = nullptr;
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_
