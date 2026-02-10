#ifndef GUI_NATIVE_PRINT_BRIDGE_H
#define GUI_NATIVE_PRINT_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct GuiNativePrintResult {
    int status;
    char* error_code;
    char* error_message;
} GuiNativePrintResult;

GuiNativePrintResult gui_native_print_pdf_dialog(
    void* ns_window,
    const char* title,
    const char* job_name,
    const char* pdf_path,
    double paper_width,
    double paper_height,
    double margin_top,
    double margin_right,
    double margin_bottom,
    double margin_left,
    int orientation
);

void gui_native_print_result_free(GuiNativePrintResult result);

#ifdef __cplusplus
}
#endif

#endif
