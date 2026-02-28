#ifndef GUI_NATIVE_NOTIFICATION_BRIDGE_H
#define GUI_NATIVE_NOTIFICATION_BRIDGE_H

#include <stdlib.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

enum {
    GUI_NOTIF_STATUS_OK      = 0,
    GUI_NOTIF_STATUS_DENIED  = 1,
    GUI_NOTIF_STATUS_ERROR   = 2,
};

typedef struct GuiNativeNotificationResult {
    int   status;
    char* error_code;
    char* error_message;
} GuiNativeNotificationResult;

GuiNativeNotificationResult gui_native_send_notification(
    const char* title,
    const char* body
);

void gui_native_notification_result_free(
    GuiNativeNotificationResult result
);

// --- shared helpers (static inline, one copy per TU) ---

static inline char* gui_notif_strdup(const char* s) {
    if (s == NULL) return NULL;
    size_t len = strlen(s);
    char* out = (char*)malloc(len + 1);
    if (out) memcpy(out, s, len + 1);
    return out;
}

static inline GuiNativeNotificationResult
gui_notif_result_ok(void) {
    GuiNativeNotificationResult r;
    r.status = GUI_NOTIF_STATUS_OK;
    r.error_code = NULL;
    r.error_message = NULL;
    return r;
}

static inline GuiNativeNotificationResult
gui_notif_result_denied(void) {
    GuiNativeNotificationResult r;
    r.status = GUI_NOTIF_STATUS_DENIED;
    r.error_code = gui_notif_strdup("denied");
    r.error_message = gui_notif_strdup(
        "notification permission denied");
    return r;
}

static inline GuiNativeNotificationResult
gui_notif_result_error(const char* code, const char* msg) {
    GuiNativeNotificationResult r;
    r.status = GUI_NOTIF_STATUS_ERROR;
    r.error_code = gui_notif_strdup(
        code ? code : "internal");
    r.error_message = gui_notif_strdup(
        msg ? msg : "notification error");
    return r;
}

static inline void gui_notif_result_free(
    GuiNativeNotificationResult result
) {
    if (result.error_code != NULL) free(result.error_code);
    if (result.error_message != NULL)
        free(result.error_message);
}

#ifdef __cplusplus
}
#endif

#endif
