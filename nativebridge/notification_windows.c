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

#include "notification_bridge.h"

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

    NOTIFYICONDATAW nid;
    ZeroMemory(&nid, sizeof(nid));
    nid.cbSize = sizeof(NOTIFYICONDATAW);
    nid.uFlags = NIF_INFO | NIF_ICON | NIF_TIP;
    nid.dwInfoFlags = NIIF_INFO;
    nid.hIcon = LoadIcon(NULL, IDI_APPLICATION);

    gui_notif_copy_wide(
        nid.szInfoTitle, 64, w_title);
    gui_notif_copy_wide(
        nid.szInfo, 256, w_body);
    gui_notif_copy_wide(
        nid.szTip, 128, w_title);

    // Add icon, show balloon, then remove icon.
    BOOL ok = Shell_NotifyIconW(NIM_ADD, &nid);
    if (!ok) {
        free(w_title);
        if (w_body) free(w_body);
        return gui_notif_result_error(
            "shell", "Shell_NotifyIconW NIM_ADD failed");
    }

    Shell_NotifyIconW(NIM_MODIFY, &nid);
    // Brief sleep so the balloon has time to appear before
    // the tray icon is removed. Without this the balloon
    // may never display on some Windows versions.
    Sleep(100);
    Shell_NotifyIconW(NIM_DELETE, &nid);

    free(w_title);
    if (w_body) free(w_body);
    return gui_notif_result_ok();
}

void gui_native_notification_result_free(
    GuiNativeNotificationResult result
) {
    gui_notif_result_free(result);
}

#endif // _WIN32
