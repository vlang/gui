#ifndef GUI_NATIVE_DIALOG_BRIDGE_H
#define GUI_NATIVE_DIALOG_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct GuiBookmarkEntry {
    char* path;
    unsigned char* data;
    int data_len;
} GuiBookmarkEntry;

typedef struct GuiNativeDialogResultEx {
    int status;
    int path_count;
    GuiBookmarkEntry* entries;
    char* error_code;
    char* error_message;
} GuiNativeDialogResultEx;

GuiNativeDialogResultEx gui_native_open_dialog_ex(
    void* ns_window,
    const char* title,
    const char* start_dir,
    const char* extensions_csv,
    int allow_multiple
);

GuiNativeDialogResultEx gui_native_save_dialog_ex(
    void* ns_window,
    const char* title,
    const char* start_dir,
    const char* default_name,
    const char* default_extension,
    const char* extensions_csv,
    int confirm_overwrite
);

GuiNativeDialogResultEx gui_native_folder_dialog_ex(
    void* ns_window,
    const char* title,
    const char* start_dir,
    int can_create_directories
);

void gui_native_dialog_result_ex_free(GuiNativeDialogResultEx result);

/* Bookmark persistence (macOS impl, stubs elsewhere) */
int gui_bookmark_store(const char* app_id,
    const char* path, const unsigned char* data,
    int data_len);
int gui_bookmark_count(const char* app_id);
GuiBookmarkEntry* gui_bookmark_load_all(
    const char* app_id, int* out_count);
int gui_bookmark_remove(const char* app_id,
    const char* path);
void gui_bookmark_entries_free(
    GuiBookmarkEntry* entries, int count);
int gui_bookmark_start_access(
    const unsigned char* data, int data_len,
    char** out_path);
void gui_bookmark_stop_access(
    const unsigned char* data, int data_len);

/* Alert/confirm dialogs (native message boxes) */
typedef struct GuiNativeAlertResult {
    int status;
    char* error_code;
    char* error_message;
} GuiNativeAlertResult;

GuiNativeAlertResult gui_native_message_dialog(
    void* ns_window,
    const char* title,
    const char* body,
    int level
);

GuiNativeAlertResult gui_native_confirm_dialog(
    void* ns_window,
    const char* title,
    const char* body,
    int level
);

void gui_native_alert_result_free(GuiNativeAlertResult result);

/* Portal (Linux impl, stubs elsewhere) */
int gui_portal_available(void);
GuiNativeDialogResultEx gui_portal_open_file(
    const char* title, const char* start_dir,
    const char* extensions_csv, int allow_multiple);
GuiNativeDialogResultEx gui_portal_save_file(
    const char* title, const char* start_dir,
    const char* default_name,
    const char* default_extension,
    const char* extensions_csv);
GuiNativeDialogResultEx gui_portal_open_directory(
    const char* title, const char* start_dir);

#ifdef __cplusplus
}
#endif

#endif
