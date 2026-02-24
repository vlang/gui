// bookmark_stub.c — Empty stubs for non-macOS platforms.
// Security-scoped bookmarks are a macOS concept; these
// functions return 0/NULL on Linux and other platforms.

#include <stddef.h>
#include "dialog_bridge.h"

int gui_bookmark_store(
    const char* app_id,
    const char* path,
    const unsigned char* data,
    int data_len
) {
    (void)app_id; (void)path; (void)data; (void)data_len;
    return 0;
}

int gui_bookmark_count(const char* app_id) {
    (void)app_id;
    return 0;
}

GuiBookmarkEntry* gui_bookmark_load_all(
    const char* app_id,
    int* out_count
) {
    (void)app_id;
    *out_count = 0;
    return NULL;
}

int gui_bookmark_remove(
    const char* app_id,
    const char* path
) {
    (void)app_id; (void)path;
    return 0;
}

void gui_bookmark_entries_free(
    GuiBookmarkEntry* entries,
    int count
) {
    (void)entries; (void)count;
}

int gui_bookmark_start_access(
    const unsigned char* data,
    int data_len,
    char** out_path
) {
    (void)data; (void)data_len; (void)out_path;
    return 0;
}

void gui_bookmark_stop_access(
    const unsigned char* data,
    int data_len
) {
    (void)data; (void)data_len;
}
