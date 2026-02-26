// a11y_windows.c — Accessibility stubs for Windows.
// Full UI Automation (IRawElementProviderSimple) deferred.
// These stubs allow compilation; a11y is non-functional.

#ifdef _WIN32

#include "a11y_bridge.h"

void gui_a11y_init(
    void* ns_window, GuiA11yActionFn cb, void* user_data
) {
    (void)ns_window; (void)cb; (void)user_data;
}

void gui_a11y_sync(
    GuiA11yNode* nodes, int count, int focused_idx
) {
    (void)nodes; (void)count; (void)focused_idx;
}

void gui_a11y_destroy(void) {
}

void gui_a11y_announce(const char* msg) {
    (void)msg;
}

#endif // _WIN32
