// portal_stub.c — Empty stubs for non-Linux platforms.
// XDG Desktop Portal is Linux-only.

#include <stddef.h>
#include "dialog_bridge.h"

int gui_portal_available(void) {
    return 0;
}

GuiNativeDialogResultEx gui_portal_open_file(
    const char* title,
    const char* start_dir,
    const char* extensions_csv,
    int allow_multiple
) {
    (void)title; (void)start_dir;
    (void)extensions_csv; (void)allow_multiple;
    GuiNativeDialogResultEx result;
    result.status = 2;
    result.path_count = 0;
    result.entries = NULL;
    result.error_code = NULL;
    result.error_message = NULL;
    return result;
}

GuiNativeDialogResultEx gui_portal_save_file(
    const char* title,
    const char* start_dir,
    const char* default_name,
    const char* default_extension,
    const char* extensions_csv
) {
    (void)title; (void)start_dir;
    (void)default_name; (void)default_extension;
    (void)extensions_csv;
    GuiNativeDialogResultEx result;
    result.status = 2;
    result.path_count = 0;
    result.entries = NULL;
    result.error_code = NULL;
    result.error_message = NULL;
    return result;
}

GuiNativeDialogResultEx gui_portal_open_directory(
    const char* title,
    const char* start_dir
) {
    (void)title; (void)start_dir;
    GuiNativeDialogResultEx result;
    result.status = 2;
    result.path_count = 0;
    result.entries = NULL;
    result.error_code = NULL;
    result.error_message = NULL;
    return result;
}
