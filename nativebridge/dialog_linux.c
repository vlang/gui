// dialog_linux.c — Stubs for macOS-only native dialog functions
// and shared result-free logic for Linux portal results.

#include <stdlib.h>
#include "dialog_bridge.h"

static GuiNativeDialogResultEx dialog_stub_error(void) {
    GuiNativeDialogResultEx result;
    result.status = 2;
    result.path_count = 0;
    result.entries = NULL;
    result.error_code = NULL;
    result.error_message = NULL;
    return result;
}

GuiNativeDialogResultEx gui_native_open_dialog_ex(
    void* ns_window,
    const char* title,
    const char* start_dir,
    const char* extensions_csv,
    int allow_multiple
) {
    (void)ns_window; (void)title; (void)start_dir;
    (void)extensions_csv; (void)allow_multiple;
    return dialog_stub_error();
}

GuiNativeDialogResultEx gui_native_save_dialog_ex(
    void* ns_window,
    const char* title,
    const char* start_dir,
    const char* default_name,
    const char* default_extension,
    const char* extensions_csv,
    int confirm_overwrite
) {
    (void)ns_window; (void)title; (void)start_dir;
    (void)default_name; (void)default_extension;
    (void)extensions_csv; (void)confirm_overwrite;
    return dialog_stub_error();
}

GuiNativeDialogResultEx gui_native_folder_dialog_ex(
    void* ns_window,
    const char* title,
    const char* start_dir,
    int can_create_directories
) {
    (void)ns_window; (void)title; (void)start_dir;
    (void)can_create_directories;
    return dialog_stub_error();
}

void gui_native_dialog_result_ex_free(
    GuiNativeDialogResultEx result
) {
    if (result.entries != NULL) {
        for (int i = 0; i < result.path_count; i++) {
            free(result.entries[i].path);
            free(result.entries[i].data);
        }
        free(result.entries);
    }
    if (result.error_code != NULL) {
        free(result.error_code);
    }
    if (result.error_message != NULL) {
        free(result.error_message);
    }
}
