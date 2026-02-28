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
#include <string.h>

#include "notification_bridge.h"

enum {
    gui_notif_status_ok    = 0,
    gui_notif_status_denied = 1,
    gui_notif_status_error = 2,
};

static char* gui_notif_win_strdup(const char* s) {
    if (s == NULL) return NULL;
    size_t len = strlen(s);
    char* out = (char*)malloc(len + 1);
    if (out) memcpy(out, s, len + 1);
    return out;
}

static GuiNativeNotificationResult gui_notif_win_ok(void) {
    GuiNativeNotificationResult r;
    r.status = gui_notif_status_ok;
    r.error_code = NULL;
    r.error_message = NULL;
    return r;
}

static GuiNativeNotificationResult gui_notif_win_error(
    const char* code, const char* msg
) {
    GuiNativeNotificationResult r;
    r.status = gui_notif_status_error;
    r.error_code = gui_notif_win_strdup(
        code ? code : "internal");
    r.error_message = gui_notif_win_strdup(
        msg ? msg : "notification error");
    return r;
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
        return gui_notif_win_error(
            "invalid_cfg", "title is required");
    }

    wchar_t* w_title = gui_notif_utf8_to_wide(title);
    if (w_title == NULL) {
        return gui_notif_win_error(
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
        free(w_body);
        return gui_notif_win_error(
            "shell", "Shell_NotifyIconW NIM_ADD failed");
    }

    Shell_NotifyIconW(NIM_MODIFY, &nid);
    // Brief sleep to let balloon appear before cleanup.
    Sleep(100);
    Shell_NotifyIconW(NIM_DELETE, &nid);

    free(w_title);
    free(w_body);
    return gui_notif_win_ok();
}

void gui_native_notification_result_free(
    GuiNativeNotificationResult result
) {
    if (result.error_code != NULL) free(result.error_code);
    if (result.error_message != NULL)
        free(result.error_message);
}

#endif // _WIN32
