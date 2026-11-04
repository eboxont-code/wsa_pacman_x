#include "app_tray_hook.h"
#include <shellapi.h>
#include <unordered_map>
namespace {
struct Saved { WINDOWPLACEMENT p{}; HICON icon=nullptr; bool owned=false; };
SRWLOCK lock=SRWLOCK_INIT;
std::unordered_map<HWND,Saved> hidden;
bool IsWsa(HWND w) {
 if(!w||!IsWindow(w)||(GetWindowLongPtrW(w,GWL_STYLE)&WS_CHILD))return false;
 DWORD pid=0;if(!GetWindowThreadProcessId(w,&pid)||!pid)return false;
 HANDLE h=OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION,FALSE,pid);if(!h)return false;
 wchar_t path[32768]={};DWORD n=static_cast<DWORD>(_countof(path));
 BOOL ok=QueryFullProcessImageNameW(h,0,path,&n);CloseHandle(h);if(!ok)return false;
 const wchar_t* name=wcsrchr(path,L'\\');name=name?name+1:path;
 return CompareStringOrdinal(name,-1,L"WsaClient.exe",-1,TRUE)==CSTR_EQUAL;
}
void DelIcon(HWND w){NOTIFYICONDATAW d{};d.cbSize=sizeof(d);d.hWnd=w;d.uID=kWsaAppTrayIconId;Shell_NotifyIconW(NIM_DELETE,&d);}
void Restore(HWND w){
 Saved s;AcquireSRWLockExclusive(&lock);auto i=hidden.find(w);if(i==hidden.end()){ReleaseSRWLockExclusive(&lock);return;}s=i->second;hidden.erase(i);ReleaseSRWLockExclusive(&lock);
 DelIcon(w);if(IsWindow(w)){WINDOWPLACEMENT p=s.p;p.length=sizeof(p);if(!SetWindowPlacement(w,&p))ShowWindow(w,SW_SHOW);SetForegroundWindow(w);}if(s.owned)DestroyIcon(s.icon);
}
bool Hide(HWND w){
 if(!IsWsa(w)||!IsWindowVisible(w))return false;
 AcquireSRWLockShared(&lock);bool exists=hidden.count(w)!=0;ReleaseSRWLockShared(&lock);if(exists)return true;
 Saved s;s.p.length=sizeof(WINDOWPLACEMENT);if(!GetWindowPlacement(w,&s.p))return false;
 DWORD_PTR v=0;SendMessageTimeoutW(w,WM_GETICON,ICON_SMALL2,0,SMTO_ABORTIFHUNG|SMTO_BLOCK,200,&v);
 HICON src=reinterpret_cast<HICON>(v);if(!src)src=reinterpret_cast<HICON>(GetClassLongPtrW(w,GCLP_HICONSM));
 if(!src)src=LoadIconW(nullptr,IDI_APPLICATION);s.icon=src?CopyIcon(src):nullptr;s.owned=s.icon!=nullptr;if(!s.icon)s.icon=LoadIconW(nullptr,IDI_APPLICATION);
 NOTIFYICONDATAW d{};d.cbSize=sizeof(d);d.hWnd=w;d.uID=kWsaAppTrayIconId;d.uFlags=NIF_MESSAGE|NIF_ICON|NIF_TIP;d.uCallbackMessage=kWsaAppTrayCallbackMessage;d.hIcon=s.icon;
 wchar_t title[128]={};GetWindowTextW(w,title,128);if(!title[0])wcscpy_s(title,L"Android app");wcsncpy_s(d.szTip,title,_TRUNCATE);
 if(!Shell_NotifyIconW(NIM_ADD,&d)){if(s.owned)DestroyIcon(s.icon);return false;}
 AcquireSRWLockExclusive(&lock);hidden[w]=s;ReleaseSRWLockExclusive(&lock);ShowWindow(w,SW_HIDE);return true;
}
}
extern "C" __declspec(dllexport) LRESULT CALLBACK WsaAppTrayCbtProc(int c,WPARAM w,LPARAM l){
 if(c==HCBT_SYSCOMMAND&&(static_cast<UINT>(l)&0xFFF0)==SC_CLOSE&&Hide(reinterpret_cast<HWND>(w)))return 1;
 return CallNextHookEx(nullptr,c,w,l);
}
extern "C" __declspec(dllexport) LRESULT CALLBACK WsaAppTrayGetMessageProc(int c,WPARAM w,LPARAM l){
 if(c>=0&&w==PM_REMOVE&&l){auto m=reinterpret_cast<MSG*>(l);if(m->message==kWsaAppTrayCallbackMessage&&m->wParam==kWsaAppTrayIconId&&(m->lParam==WM_LBUTTONUP||m->lParam==WM_LBUTTONDBLCLK||m->lParam==WM_RBUTTONUP)){Restore(m->hwnd);m->message=WM_NULL;}}
 return CallNextHookEx(nullptr,c,w,l);
}
extern "C" __declspec(dllexport) LRESULT CALLBACK WsaAppTrayCallWndProc(int c,WPARAM w,LPARAM l){
 if(c>=0&&l){auto m=reinterpret_cast<const CWPSTRUCT*>(l);if(m->message==kWsaAppTrayRestoreManagerMessage)Restore(m->hwnd);}
 return CallNextHookEx(nullptr,c,w,l);
}