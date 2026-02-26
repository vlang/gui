// print_windows.c — Print via ShellExecuteEx "print" verb.
// Delegates to the system's default PDF handler, avoiding
// GDI/PrintDlg complexity. Same strategy as Linux xdg-open.

#ifdef _WIN32

#include <windows.h>
#include <shellapi.h>
#include <stdlib.h>
#include <string.h>

#include "print_bridge.h"

enum {
    gui_win_print_ok     = 0,
    gui_win_print_cancel = 1,
    gui_win_print_error  = 2,
};

static char* gui_print_strdup(const char* s) {
    if (s == NULL) return NULL;
    size_t len = strlen(s);
    char* out = (char*)malloc(len + 1);
    if (out) memcpy(out, s, len + 1);
    return out;
}

static GuiNativePrintResult gui_print_win_error(
    const char* code, const char* msg
) {
    GuiNativePrintResult r;
    r.status = gui_win_print_error;
    r.error_code = gui_print_strdup(
        code ? code : "internal");
    r.error_message = gui_print_strdup(
        msg ? msg : "print error");
    return r;
}

static wchar_t* gui_print_utf8_to_wide(const char* s) {
    if (s == NULL || s[0] == '\0') return NULL;
    int len = MultiByteToWideChar(
        CP_UTF8, 0, s, -1, NULL, 0);
    if (len <= 0) return NULL;
    wchar_t* w = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (w) MultiByteToWideChar(CP_UTF8, 0, s, -1, w, len);
    return w;
}

GuiNativePrintResult gui_native_print_pdf_dialog(
    void* hwnd_ptr,
    const char* title,
    const char* job_name,
    const char* pdf_path,
    double paper_width,
    double paper_height,
    double margin_top,
    double margin_right,
    double margin_bottom,
    double margin_left,
    int orientation,
    int copies,
    const char* page_ranges,
    int duplex_mode,
    int color_mode,
    int scale_mode
) {
    // Suppress unused parameter warnings.
    (void)title; (void)job_name;
    (void)paper_width; (void)paper_height;
    (void)margin_top; (void)margin_right;
    (void)margin_bottom; (void)margin_left;
    (void)orientation; (void)copies;
    (void)page_ranges; (void)duplex_mode;
    (void)color_mode; (void)scale_mode;

    if (pdf_path == NULL || pdf_path[0] == '\0') {
        return gui_print_win_error(
            "invalid_cfg", "pdf_path is required");
    }

    wchar_t* wpath = gui_print_utf8_to_wide(pdf_path);
    if (wpath == NULL) {
        return gui_print_win_error(
            "invalid_cfg", "pdf_path conversion failed");
    }

    // Verify file exists.
    DWORD attrs = GetFileAttributesW(wpath);
    if (attrs == INVALID_FILE_ATTRIBUTES
        || (attrs & FILE_ATTRIBUTE_DIRECTORY)) {
        free(wpath);
        return gui_print_win_error(
            "io_error",
            "pdf file does not exist or is a directory");
    }

    SHELLEXECUTEINFOW sei;
    ZeroMemory(&sei, sizeof(sei));
    sei.cbSize = sizeof(sei);
    sei.fMask = SEE_MASK_FLAG_NO_UI
        | SEE_MASK_NOASYNC;
    sei.hwnd = (HWND)hwnd_ptr;
    sei.lpVerb = L"print";
    sei.lpFile = wpath;
    sei.nShow = SW_HIDE;

    BOOL ok = ShellExecuteExW(&sei);
    free(wpath);

    if (ok) {
        GuiNativePrintResult r;
        r.status = gui_win_print_ok;
        r.error_code = NULL;
        r.error_message = NULL;
        return r;
    }

    // ShellExecuteEx failed — check if no print handler.
    DWORD err = GetLastError();
    if (err == ERROR_NO_ASSOCIATION
        || err == ERROR_FILE_NOT_FOUND) {
        return gui_print_win_error(
            "no_handler",
            "no application associated with PDF printing");
    }

    return gui_print_win_error(
        "shell_error", "ShellExecuteEx print failed");
}

void gui_native_print_result_free(
    GuiNativePrintResult result
) {
    free(result.error_code);
    free(result.error_message);
}

#endif // _WIN32
