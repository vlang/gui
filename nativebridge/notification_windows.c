// notification_windows.c — Windows native notifications via
// Shell_NotifyIconW balloon tips.
// Compiled via #flag windows ... notification_windows.c
// in c_bindings.v.

#ifdef _WIN32

#ifndef _WIN32_IE
#define _WIN32_IE 0x0600
#endif

#include <windows.h>
#include <shellapi.h>
#include <stdlib.h>

#include "notification_bridge.h"

#define GUI_NOTIF_CALLBACK_MESSAGE (WM_APP + 0x4e01)
#define GUI_NOTIF_ICON_ID 1
#define GUI_NOTIF_WAIT_MS 5000

typedef struct GuiNotifWindowState {
    int balloon_done;
} GuiNotifWindowState;

static const wchar_t gui_notif_window_class[] =
    L"VGuiNativeNotificationOwner";

static UINT gui_notif_callback_code(LPARAM lparam) {
    UINT low = (UINT)LOWORD(lparam);
    UINT high = (UINT)HIWORD(lparam);
    if (low == NIN_BALLOONHIDE ||
        low == NIN_BALLOONTIMEOUT ||
        low == NIN_BALLOONUSERCLICK) {
        return low;
    }
    if (high == NIN_BALLOONHIDE ||
        high == NIN_BALLOONTIMEOUT ||
        high == NIN_BALLOONUSERCLICK) {
        return high;
    }
    return (UINT)lparam;
}

static LRESULT CALLBACK gui_notif_wnd_proc(
    HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam
) {
    (void)wparam;
    if (msg == GUI_NOTIF_CALLBACK_MESSAGE) {
        GuiNotifWindowState* state =
            (GuiNotifWindowState*)GetWindowLongPtrW(
                hwnd, GWLP_USERDATA);
        UINT code = gui_notif_callback_code(lparam);
        if (state != NULL &&
            (code == NIN_BALLOONHIDE ||
             code == NIN_BALLOONTIMEOUT ||
             code == NIN_BALLOONUSERCLICK)) {
            state->balloon_done = 1;
        }
        return 0;
    }
    if (msg == WM_NCDESTROY) {
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
    }
    return DefWindowProcW(hwnd, msg, wparam, lparam);
}

static int gui_notif_register_window_class(void) {
    WNDCLASSW wc;
    ZeroMemory(&wc, sizeof(wc));
    wc.lpfnWndProc = gui_notif_wnd_proc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.lpszClassName = gui_notif_window_class;

    if (RegisterClassW(&wc) != 0) {
        return 1;
    }
    return GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
}

static HWND gui_notif_create_owner_window(
    GuiNotifWindowState* state
) {
    if (!gui_notif_register_window_class()) {
        return NULL;
    }
    HWND hwnd = CreateWindowExW(
        0,
        gui_notif_window_class,
        L"",
        0,
        0, 0, 0, 0,
        HWND_MESSAGE,
        NULL,
        GetModuleHandleW(NULL),
        NULL);
    if (hwnd == NULL) {
        return NULL;
    }
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)state);
    return hwnd;
}

static void gui_notif_pump_bounded(
    HWND hwnd, GuiNotifWindowState* state, DWORD timeout_ms
) {
    DWORD start = GetTickCount();
    MSG msg;
    while (!state->balloon_done) {
        DWORD elapsed = GetTickCount() - start;
        if (elapsed >= timeout_ms) {
            break;
        }
        while (PeekMessageW(&msg, hwnd, 0, 0, PM_REMOVE)) {
            elapsed = GetTickCount() - start;
            if (elapsed >= timeout_ms) {
                return;
            }
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
            if (state->balloon_done) {
                break;
            }
        }
        if (state->balloon_done) {
            break;
        }
        DWORD remaining = timeout_ms - elapsed;
        DWORD slice = remaining < 50 ? remaining : 50;
        if (slice == 0) {
            break;
        }
        MsgWaitForMultipleObjectsEx(
            0, NULL, slice, QS_ALLINPUT, MWMO_INPUTAVAILABLE);
    }
}

// Convert UTF-8 to wide string. Caller must free result.
static wchar_t* gui_notif_utf8_to_wide(const char* utf8) {
    if (utf8 == NULL || utf8[0] == '\0') return NULL;
    int len = MultiByteToWideChar(
        CP_UTF8, 0, utf8, -1, NULL, 0);
    if (len <= 0) return NULL;
    wchar_t* wide = (wchar_t*)malloc(
        (size_t)len * sizeof(wchar_t));
    if (wide == NULL) return NULL;
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, wide, len);
    return wide;
}

// Copy wide string into fixed-size buffer, truncating.
static void gui_notif_copy_wide(
    wchar_t* dst, int dst_size,
    const wchar_t* src
) {
    if (src == NULL) {
        dst[0] = L'\0';
        return;
    }
    int i = 0;
    int max = dst_size - 1;
    while (i < max && src[i] != L'\0') {
        dst[i] = src[i];
        i++;
    }
    dst[i] = L'\0';
}

GuiNativeNotificationResult gui_native_send_notification(
    const char* title,
    const char* body
) {
    if (title == NULL || title[0] == '\0') {
        return gui_notif_result_error(
            "invalid_cfg", "title is required");
    }

    wchar_t* w_title = gui_notif_utf8_to_wide(title);
    if (w_title == NULL) {
        return gui_notif_result_error(
            "encoding", "UTF-8 to wide conversion failed");
    }
    wchar_t* w_body = gui_notif_utf8_to_wide(body);

    GuiNotifWindowState state;
    ZeroMemory(&state, sizeof(state));
    HWND hwnd = gui_notif_create_owner_window(&state);
    if (hwnd == NULL) {
        free(w_title);
        if (w_body) free(w_body);
        return gui_notif_result_error(
            "shell", "notification owner window creation failed");
    }

    NOTIFYICONDATAW nid;
    ZeroMemory(&nid, sizeof(nid));
    nid.cbSize = sizeof(NOTIFYICONDATAW);
    nid.hWnd = hwnd;
    nid.uID = GUI_NOTIF_ICON_ID;
    nid.uCallbackMessage = GUI_NOTIF_CALLBACK_MESSAGE;
    nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    nid.dwInfoFlags = NIIF_INFO;
    nid.hIcon = LoadIcon(NULL, IDI_APPLICATION);

    gui_notif_copy_wide(
        nid.szTip, 128, w_title);

    BOOL ok = Shell_NotifyIconW(NIM_ADD, &nid);
    if (!ok) {
        DestroyWindow(hwnd);
        free(w_title);
        if (w_body) free(w_body);
        return gui_notif_result_error(
            "shell", "Shell_NotifyIconW NIM_ADD failed");
    }

    nid.uVersion = NOTIFYICON_VERSION_4;
    ok = Shell_NotifyIconW(NIM_SETVERSION, &nid);
    if (!ok) {
        BOOL delete_ok = Shell_NotifyIconW(NIM_DELETE, &nid);
        DestroyWindow(hwnd);
        free(w_title);
        if (w_body) free(w_body);
        if (!delete_ok) {
            return gui_notif_result_error(
                "shell_cleanup",
                "Shell_NotifyIconW NIM_SETVERSION failed; cleanup NIM_DELETE also failed");
        }
        return gui_notif_result_error(
            "shell", "Shell_NotifyIconW NIM_SETVERSION failed");
    }

    nid.uFlags = NIF_INFO;
    gui_notif_copy_wide(
        nid.szInfoTitle, 64, w_title);
    gui_notif_copy_wide(
        nid.szInfo, 256, w_body);
    ok = Shell_NotifyIconW(NIM_MODIFY, &nid);
    if (!ok) {
        BOOL delete_ok = Shell_NotifyIconW(NIM_DELETE, &nid);
        DestroyWindow(hwnd);
        free(w_title);
        if (w_body) free(w_body);
        if (!delete_ok) {
            return gui_notif_result_error(
                "shell_cleanup",
                "Shell_NotifyIconW NIM_MODIFY failed; cleanup NIM_DELETE also failed");
        }
        return gui_notif_result_error(
            "shell", "Shell_NotifyIconW NIM_MODIFY failed");
    }

    gui_notif_pump_bounded(hwnd, &state, GUI_NOTIF_WAIT_MS);
    ok = Shell_NotifyIconW(NIM_DELETE, &nid);
    DestroyWindow(hwnd);

    free(w_title);
    if (w_body) free(w_body);
    if (!ok) {
        return gui_notif_result_error(
            "shell", "Shell_NotifyIconW NIM_DELETE failed");
    }
    return gui_notif_result_ok();
}

void gui_native_notification_result_free(
    GuiNativeNotificationResult result
) {
    gui_notif_result_free(result);
}

#endif // _WIN32
