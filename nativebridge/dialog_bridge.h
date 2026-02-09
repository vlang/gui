#ifndef GUI_NATIVE_DIALOG_BRIDGE_H
#define GUI_NATIVE_DIALOG_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct GuiNativeDialogResult {
    int status;
    int path_count;
    char** paths;
    char* error_code;
    char* error_message;
} GuiNativeDialogResult;

GuiNativeDialogResult gui_native_open_dialog(
    void* ns_window,
    const char* title,
    const char* start_dir,
    const char* extensions_csv,
    int allow_multiple
);

GuiNativeDialogResult gui_native_save_dialog(
    void* ns_window,
    const char* title,
    const char* start_dir,
    const char* default_name,
    const char* default_extension,
    const char* extensions_csv,
    int confirm_overwrite
);

GuiNativeDialogResult gui_native_folder_dialog(
    void* ns_window,
    const char* title,
    const char* start_dir,
    int can_create_directories
);

void gui_native_dialog_result_free(GuiNativeDialogResult result);

#ifdef __cplusplus
}
#endif

#endif
