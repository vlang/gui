#ifndef GUI_NATIVE_NOTIFICATION_BRIDGE_H
#define GUI_NATIVE_NOTIFICATION_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

// status: 0=ok, 1=denied (macOS permission), 2=error
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

#ifdef __cplusplus
}
#endif

#endif
