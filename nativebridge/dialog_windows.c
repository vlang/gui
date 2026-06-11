// dialog_windows.c — Win32 IFileDialog (Common Item Dialog).
// Vista+ COM interfaces: IFileOpenDialog / IFileSaveDialog.
// Each entry point calls CoInitializeEx since dialogs run on
// Sokol's main thread. The HWND comes from sapp_win32_get_hwnd().

#ifdef _WIN32

#ifndef COBJMACROS
#define COBJMACROS
#endif

#include <windows.h>
#include <shobjidl.h>
#include <shlwapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

#include "dialog_bridge.h"

enum {
    gui_win_status_ok     = 0,
    gui_win_status_cancel = 1,
    gui_win_status_error  = 2,
};

#define GUI_WIN_FILTER_SPEC_PREFIX "gfd1;"
#define GUI_WIN_FILTER_SPEC_PREFIX_LEN 5

static char* gui_win_strdup(const char* s) {
    if (s == NULL) return NULL;
    size_t len = strlen(s);
    char* out = (char*)malloc(len + 1);
    if (out) memcpy(out, s, len + 1);
    return out;
}

static char* gui_win_strndup(const char* s, size_t len) {
    if (s == NULL) return NULL;
    char* out = (char*)malloc(len + 1);
    if (out == NULL) return NULL;
    memcpy(out, s, len);
    out[len] = '\0';
    return out;
}

static GuiNativeDialogResultEx gui_win_result_empty(void) {
    GuiNativeDialogResultEx r;
    r.status = gui_win_status_error;
    r.path_count = 0;
    r.entries = NULL;
    r.error_code = NULL;
    r.error_message = NULL;
    return r;
}

static GuiNativeDialogResultEx gui_win_result_cancel(void) {
    GuiNativeDialogResultEx r = gui_win_result_empty();
    r.status = gui_win_status_cancel;
    return r;
}

static GuiNativeDialogResultEx gui_win_result_error(
    const char* code, const char* msg
) {
    GuiNativeDialogResultEx r = gui_win_result_empty();
    r.error_code = gui_win_strdup(code ? code : "internal");
    r.error_message = gui_win_strdup(msg ? msg : "dialog error");
    return r;
}

// Convert UTF-8 to wide string. Caller must free().
static wchar_t* gui_utf8_to_wide(const char* s) {
    if (s == NULL || s[0] == '\0') return NULL;
    int len = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
    if (len <= 0) return NULL;
    wchar_t* w = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (w) MultiByteToWideChar(CP_UTF8, 0, s, -1, w, len);
    return w;
}

// Convert wide string to UTF-8. Caller must free().
static char* gui_wide_to_utf8(const wchar_t* w) {
    if (w == NULL) return NULL;
    int len = WideCharToMultiByte(
        CP_UTF8, 0, w, -1, NULL, 0, NULL, NULL);
    if (len <= 0) return NULL;
    char* s = (char*)malloc(len);
    if (s) WideCharToMultiByte(
        CP_UTF8, 0, w, -1, s, len, NULL, NULL);
    return s;
}

typedef struct GuiWinComScope {
    HRESULT hr;
    int must_uninit;
} GuiWinComScope;

static GuiWinComScope gui_win_com_scope_init(void) {
    GuiWinComScope scope;
    scope.hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    scope.must_uninit = SUCCEEDED(scope.hr) ? 1 : 0;
    return scope;
}

static void gui_win_com_scope_uninit(GuiWinComScope scope) {
    if (scope.must_uninit) CoUninitialize();
}

static void gui_win_swprintf(
    wchar_t* dst,
    size_t dst_count,
    const wchar_t* fmt,
    const wchar_t* a,
    const wchar_t* b
) {
    if (dst == NULL || dst_count == 0) return;
#ifdef _MSC_VER
    swprintf_s(dst, dst_count, fmt, a, b);
#else
    swprintf(dst, dst_count, fmt, a, b);
#endif
    dst[dst_count - 1] = L'\0';
}

static void gui_free_filter_specs(
    COMDLG_FILTERSPEC* specs, int count
);

static int gui_parse_len_token(
    const char** cursor, const char* end, size_t* out
) {
    if (cursor == NULL || *cursor == NULL || out == NULL) return 0;
    const char* p = *cursor;
    if (p >= end || *p < '0' || *p > '9') return 0;

    size_t value = 0;
    while (p < end && *p >= '0' && *p <= '9') {
        size_t digit = (size_t)(*p - '0');
        if (value > (((size_t)-1) - digit) / 10) return 0;
        value = value * 10 + digit;
        p++;
    }
    if (p >= end || *p != ':') return 0;

    *cursor = p + 1;
    *out = value;
    return 1;
}

static wchar_t* gui_filter_pattern_from_csv(const char* csv) {
    if (csv == NULL || csv[0] == '\0') return NULL;

    size_t csv_len = strlen(csv);
    size_t buf_cap = csv_len * 4 + 16;
    wchar_t* pattern = (wchar_t*)calloc(buf_cap, sizeof(wchar_t));
    if (pattern == NULL) return NULL;

    char* dup = gui_win_strdup(csv);
    if (dup == NULL) {
        free(pattern);
        return NULL;
    }

    wchar_t* cp = pattern;
    char* token = strtok(dup, ",");
    while (token != NULL) {
        while (*token == ' ' || *token == '.') token++;
        char* token_end = token + strlen(token);
        while (token_end > token
            && (token_end[-1] == ' ' || token_end[-1] == '.')) {
            token_end--;
        }
        *token_end = '\0';
        if (*token != '\0') {
            if (cp != pattern) *cp++ = L';';
            *cp++ = L'*';
            *cp++ = L'.';
            MultiByteToWideChar(
                CP_UTF8, 0, token, -1, cp,
                (int)(buf_cap - (cp - pattern)));
            cp += wcslen(cp);
        }
        token = strtok(NULL, ",");
    }
    free(dup);

    if (cp == pattern) {
        free(pattern);
        return NULL;
    }
    *cp = L'\0';
    return pattern;
}

static wchar_t* gui_filter_name_from_pattern(const wchar_t* pattern) {
    if (pattern == NULL || pattern[0] == L'\0') return NULL;
    size_t nlen = wcslen(pattern) + 16;
    wchar_t* name = (wchar_t*)calloc(nlen, sizeof(wchar_t));
    if (name == NULL) return NULL;
#ifdef _MSC_VER
    swprintf_s(name, nlen, L"Files (%ls)", pattern);
#else
    swprintf(name, nlen, L"Files (%ls)", pattern);
#endif
    name[nlen - 1] = L'\0';
    return name;
}

static int gui_win_path_exists(const char* path) {
    wchar_t* wpath = gui_utf8_to_wide(path);
    if (wpath == NULL) return 0;
    DWORD attrs = GetFileAttributesW(wpath);
    free(wpath);
    return attrs != INVALID_FILE_ATTRIBUTES;
}

static int gui_parse_named_filter_specs(
    const char* spec, COMDLG_FILTERSPEC** out
) {
    *out = NULL;
    if (spec == NULL
        || strncmp(spec, GUI_WIN_FILTER_SPEC_PREFIX,
            GUI_WIN_FILTER_SPEC_PREFIX_LEN) != 0) {
        return 0;
    }

    const char* p = spec + GUI_WIN_FILTER_SPEC_PREFIX_LEN;
    const char* end = spec + strlen(spec);
    int capacity = 4;
    int count = 0;
    COMDLG_FILTERSPEC* specs = (COMDLG_FILTERSPEC*)calloc(
        capacity, sizeof(COMDLG_FILTERSPEC));
    if (specs == NULL) return 0;

    while (p < end) {
        size_t name_len = 0;
        size_t csv_len = 0;
        char* name_utf8 = NULL;
        char* csv = NULL;
        wchar_t* pattern = NULL;
        wchar_t* name = NULL;

        if (!gui_parse_len_token(&p, end, &name_len)
            || name_len > (size_t)(end - p)) {
            goto fail;
        }
        name_utf8 = gui_win_strndup(p, name_len);
        if (name_utf8 == NULL) goto fail;
        p += name_len;

        if (!gui_parse_len_token(&p, end, &csv_len)
            || csv_len > (size_t)(end - p)) {
            free(name_utf8);
            goto fail;
        }
        csv = gui_win_strndup(p, csv_len);
        if (csv == NULL) {
            free(name_utf8);
            goto fail;
        }
        p += csv_len;

        pattern = gui_filter_pattern_from_csv(csv);
        if (pattern != NULL) {
            if (name_utf8[0] != '\0') {
                name = gui_utf8_to_wide(name_utf8);
            }
            if (name == NULL) {
                name = gui_filter_name_from_pattern(pattern);
            }
            if (name == NULL) {
                free(pattern);
                free(name_utf8);
                free(csv);
                goto fail;
            }

            if (count == capacity) {
                int new_capacity = capacity * 2;
                COMDLG_FILTERSPEC* grown =
                    (COMDLG_FILTERSPEC*)realloc(
                        specs,
                        new_capacity * sizeof(COMDLG_FILTERSPEC));
                if (grown == NULL) {
                    free((void*)name);
                    free((void*)pattern);
                    free(name_utf8);
                    free(csv);
                    goto fail;
                }
                memset(grown + capacity, 0,
                    (new_capacity - capacity)
                        * sizeof(COMDLG_FILTERSPEC));
                specs = grown;
                capacity = new_capacity;
            }

            specs[count].pszName = name;
            specs[count].pszSpec = pattern;
            count++;
        }
        free(name_utf8);
        free(csv);
    }

    if (count == 0) {
        free(specs);
        return 0;
    }
    *out = specs;
    return count;

fail:
    gui_free_filter_specs(specs, count);
    return 0;
}

// Parse named "gfd1;" filter specs or legacy "jpg,png,gif" CSV
// into COMDLG_FILTERSPEC array.
// Returns count; *out receives malloc'd array. Caller frees
// each spec's pszName and pszSpec, then the array itself.
static int gui_parse_filter_specs(
    const char* csv, COMDLG_FILTERSPEC** out
) {
    *out = NULL;
    if (csv == NULL || csv[0] == '\0') return 0;
    if (strncmp(csv, GUI_WIN_FILTER_SPEC_PREFIX,
        GUI_WIN_FILTER_SPEC_PREFIX_LEN) == 0) {
        return gui_parse_named_filter_specs(csv, out);
    }

    // Count extensions.
    int count = 1;
    for (const char* p = csv; *p; p++) {
        if (*p == ',') count++;
    }

    // Build a single "All Supported" filter + one per ext.
    // Total = 1 (combined) + count (individual).
    int total = 1 + count;
    COMDLG_FILTERSPEC* specs = (COMDLG_FILTERSPEC*)calloc(
        total, sizeof(COMDLG_FILTERSPEC));
    if (specs == NULL) return 0;

    // Build combined wildcard: "*.jpg;*.png;*.gif"
    size_t csv_len = strlen(csv);
    // Max: each ext gets "*." prefix (2) + ext + ";" separator
    size_t buf_cap = csv_len * 4 + 16;
    wchar_t* combined = (wchar_t*)calloc(buf_cap, sizeof(wchar_t));
    if (combined == NULL) { free(specs); return 0; }

    // Parse individual extensions.
    char* dup = gui_win_strdup(csv);
    if (dup == NULL) { free(combined); free(specs); return 0; }

    wchar_t* cp = combined;
    int idx = 1; // specs[0] reserved for combined
    char* token = strtok(dup, ",");
    while (token != NULL && idx < total) {
        // Trim leading dots/spaces.
        while (*token == ' ' || *token == '.') token++;
        if (*token == '\0') { token = strtok(NULL, ","); continue; }

        // Build "*.ext" for individual filter.
        size_t elen = strlen(token);
        size_t wlen = elen + 3; // "*." + ext + NUL
        wchar_t* pattern = (wchar_t*)calloc(wlen, sizeof(wchar_t));
        if (pattern) {
            pattern[0] = L'*';
            pattern[1] = L'.';
            MultiByteToWideChar(
                CP_UTF8, 0, token, -1, pattern + 2, (int)elen + 1);
        }

        // Build display name (uppercase ext).
        size_t nlen = elen * 2 + 16;
        wchar_t* name = (wchar_t*)calloc(nlen, sizeof(wchar_t));
        if (name && pattern) {
            // e.g. "JPG Files (*.jpg)"
            wchar_t ext_upper[64] = {0};
            MultiByteToWideChar(
                CP_UTF8, 0, token, -1, ext_upper, 63);
            CharUpperW(ext_upper);
            gui_win_swprintf(
                name, nlen, L"%ls Files (%ls)",
                ext_upper, pattern);
        }

        specs[idx].pszName = name;
        specs[idx].pszSpec = pattern;

        // Append to combined pattern.
        if (cp != combined) { *cp++ = L';'; }
        *cp++ = L'*'; *cp++ = L'.';
        MultiByteToWideChar(
            CP_UTF8, 0, token, -1, cp,
            (int)(buf_cap - (cp - combined)));
        cp += wcslen(cp);

        idx++;
        token = strtok(NULL, ",");
    }
    free(dup);
    *cp = L'\0';

    int actual = idx;

    // Build combined filter as specs[0].
    wchar_t* all_name = (wchar_t*)calloc(32, sizeof(wchar_t));
    if (all_name) wcscpy(all_name, L"All Supported");
    wchar_t* all_spec = (wchar_t*)calloc(
        wcslen(combined) + 1, sizeof(wchar_t));
    if (all_spec) wcscpy(all_spec, combined);
    specs[0].pszName = all_name;
    specs[0].pszSpec = all_spec;
    free(combined);

    // If only one extension, skip the combined entry.
    if (actual <= 2) {
        // Return just the individual filter.
        free((void*)specs[0].pszName);
        free((void*)specs[0].pszSpec);
        specs[0] = specs[1];
        specs[1].pszName = NULL;
        specs[1].pszSpec = NULL;
        *out = specs;
        return 1;
    }

    *out = specs;
    return actual;
}

static void gui_free_filter_specs(
    COMDLG_FILTERSPEC* specs, int count
) {
    if (specs == NULL) return;
    for (int i = 0; i < count; i++) {
        free((void*)specs[i].pszName);
        free((void*)specs[i].pszSpec);
    }
    free(specs);
}

// Set the initial folder on a file dialog.
static void gui_win_set_folder(
    IFileDialog* dlg, const char* dir
) {
    wchar_t* wdir = gui_utf8_to_wide(dir);
    if (wdir == NULL) return;
    IShellItem* item = NULL;
    HRESULT hr = SHCreateItemFromParsingName(
        wdir, NULL, &IID_IShellItem, (void**)&item);
    free(wdir);
    if (SUCCEEDED(hr) && item != NULL) {
        IFileDialog_SetFolder(dlg, item);
        IShellItem_Release(item);
    }
}

// Get path string from IShellItem. Caller must free().
static char* gui_win_shell_item_path(IShellItem* item) {
    wchar_t* wpath = NULL;
    HRESULT hr = IShellItem_GetDisplayName(
        item, SIGDN_FILESYSPATH, &wpath);
    if (FAILED(hr) || wpath == NULL) return NULL;
    char* path = gui_wide_to_utf8(wpath);
    CoTaskMemFree(wpath);
    return path;
}

// Build result from an array of paths (no bookmarks on Win).
static GuiNativeDialogResultEx gui_win_result_paths(
    char** paths, int count
) {
    GuiNativeDialogResultEx r = gui_win_result_empty();
    r.status = gui_win_status_ok;
    r.path_count = count;
    r.entries = (GuiBookmarkEntry*)calloc(
        count, sizeof(GuiBookmarkEntry));
    if (r.entries == NULL) {
        for (int i = 0; i < count; i++) free(paths[i]);
        return gui_win_result_error(
            "internal", "allocation failed");
    }
    for (int i = 0; i < count; i++) {
        r.entries[i].path = paths[i];
        r.entries[i].data = NULL;
        r.entries[i].data_len = 0;
    }
    return r;
}

GuiNativeDialogResultEx gui_native_open_dialog_ex(
    void* hwnd_ptr,
    const char* title,
    const char* start_dir,
    const char* extensions_csv,
    int allow_multiple
) {
    HRESULT hr;
    GuiWinComScope com = gui_win_com_scope_init();
    hr = com.hr;
    if (FAILED(hr)) {
        return gui_win_result_error(
            "com_init", "CoInitializeEx failed");
    }

    IFileOpenDialog* dlg = NULL;
    hr = CoCreateInstance(
        &CLSID_FileOpenDialog, NULL, CLSCTX_INPROC_SERVER,
        &IID_IFileOpenDialog, (void**)&dlg);
    if (FAILED(hr) || dlg == NULL) {
        gui_win_com_scope_uninit(com);
        return gui_win_result_error(
            "com_create", "IFileOpenDialog create failed");
    }

    // Title.
    wchar_t* wtitle = gui_utf8_to_wide(title);
    if (wtitle) {
        IFileDialog_SetTitle((IFileDialog*)dlg, wtitle);
        free(wtitle);
    }

    // Start directory.
    gui_win_set_folder((IFileDialog*)dlg, start_dir);

    // Extension filters.
    COMDLG_FILTERSPEC* specs = NULL;
    int spec_count = gui_parse_filter_specs(
        extensions_csv, &specs);
    if (spec_count > 0 && specs != NULL) {
        IFileDialog_SetFileTypes(
            (IFileDialog*)dlg, spec_count, specs);
    }

    // Multi-select.
    DWORD opts = 0;
    IFileDialog_GetOptions((IFileDialog*)dlg, &opts);
    opts |= FOS_FORCEFILESYSTEM;
    if (allow_multiple) opts |= FOS_ALLOWMULTISELECT;
    IFileDialog_SetOptions((IFileDialog*)dlg, opts);

    // Show dialog.
    HWND owner = (HWND)hwnd_ptr;
    hr = IFileDialog_Show((IFileDialog*)dlg, owner);
    if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
        IFileOpenDialog_Release(dlg);
        gui_free_filter_specs(specs, spec_count);
        gui_win_com_scope_uninit(com);
        return gui_win_result_cancel();
    }
    if (FAILED(hr)) {
        IFileOpenDialog_Release(dlg);
        gui_free_filter_specs(specs, spec_count);
        gui_win_com_scope_uninit(com);
        return gui_win_result_error(
            "show", "dialog Show failed");
    }

    // Collect results.
    IShellItemArray* items = NULL;
    hr = IFileOpenDialog_GetResults(dlg, &items);
    if (FAILED(hr) || items == NULL) {
        IFileOpenDialog_Release(dlg);
        gui_free_filter_specs(specs, spec_count);
        gui_win_com_scope_uninit(com);
        return gui_win_result_error(
            "results", "GetResults failed");
    }

    DWORD item_count = 0;
    hr = IShellItemArray_GetCount(items, &item_count);
    if (FAILED(hr)) {
        IShellItemArray_Release(items);
        IFileOpenDialog_Release(dlg);
        gui_free_filter_specs(specs, spec_count);
        gui_win_com_scope_uninit(com);
        return gui_win_result_error(
            "results", "GetCount failed");
    }
    if (item_count == 0) {
        IShellItemArray_Release(items);
        IFileOpenDialog_Release(dlg);
        gui_free_filter_specs(specs, spec_count);
        gui_win_com_scope_uninit(com);
        return gui_win_result_cancel();
    }

    char** paths = (char**)calloc(item_count, sizeof(char*));
    if (paths == NULL) {
        IShellItemArray_Release(items);
        IFileOpenDialog_Release(dlg);
        gui_free_filter_specs(specs, spec_count);
        gui_win_com_scope_uninit(com);
        return gui_win_result_error(
            "allocation", "allocation failed");
    }
    int valid = 0;
    for (DWORD i = 0; i < item_count; i++) {
        IShellItem* item = NULL;
        hr = IShellItemArray_GetItemAt(items, i, &item);
        if (SUCCEEDED(hr) && item != NULL) {
            char* p = gui_win_shell_item_path(item);
            if (p) paths[valid++] = p;
            IShellItem_Release(item);
        }
    }

    IShellItemArray_Release(items);
    IFileOpenDialog_Release(dlg);
    gui_free_filter_specs(specs, spec_count);

    GuiNativeDialogResultEx result;
    if (valid > 0) {
        result = gui_win_result_paths(paths, valid);
    } else {
        result = gui_win_result_error(
            "internal", "no valid paths");
    }
    free(paths);
    gui_win_com_scope_uninit(com);
    return result;
}

GuiNativeDialogResultEx gui_native_save_dialog_ex(
    void* hwnd_ptr,
    const char* title,
    const char* start_dir,
    const char* default_name,
    const char* default_extension,
    const char* extensions_csv,
    int confirm_overwrite
) {
    HRESULT hr;
    GuiWinComScope com = gui_win_com_scope_init();
    hr = com.hr;
    if (FAILED(hr)) {
        return gui_win_result_error(
            "com_init", "CoInitializeEx failed");
    }

    IFileSaveDialog* dlg = NULL;
    hr = CoCreateInstance(
        &CLSID_FileSaveDialog, NULL, CLSCTX_INPROC_SERVER,
        &IID_IFileSaveDialog, (void**)&dlg);
    if (FAILED(hr) || dlg == NULL) {
        gui_win_com_scope_uninit(com);
        return gui_win_result_error(
            "com_create", "IFileSaveDialog create failed");
    }

    // Title.
    wchar_t* wtitle = gui_utf8_to_wide(title);
    if (wtitle) {
        IFileDialog_SetTitle((IFileDialog*)dlg, wtitle);
        free(wtitle);
    }

    // Start directory.
    gui_win_set_folder((IFileDialog*)dlg, start_dir);

    // Default filename.
    wchar_t* wname = gui_utf8_to_wide(default_name);
    if (wname) {
        IFileDialog_SetFileName((IFileDialog*)dlg, wname);
        free(wname);
    }

    // Default extension (without leading dot).
    wchar_t* wext = gui_utf8_to_wide(default_extension);
    if (wext) {
        // Skip leading dots.
        wchar_t* e = wext;
        while (*e == L'.') e++;
        if (*e != L'\0') {
            IFileDialog_SetDefaultExtension(
                (IFileDialog*)dlg, e);
        }
        free(wext);
    }

    // Extension filters.
    COMDLG_FILTERSPEC* specs = NULL;
    int spec_count = gui_parse_filter_specs(
        extensions_csv, &specs);
    if (spec_count > 0 && specs != NULL) {
        IFileDialog_SetFileTypes(
            (IFileDialog*)dlg, spec_count, specs);
    }

    // Overwrite prompt.
    DWORD opts = 0;
    IFileDialog_GetOptions((IFileDialog*)dlg, &opts);
    opts |= FOS_FORCEFILESYSTEM;
    if (confirm_overwrite) opts |= FOS_OVERWRITEPROMPT;
    else opts &= ~FOS_OVERWRITEPROMPT;
    IFileDialog_SetOptions((IFileDialog*)dlg, opts);

    // Show dialog.
    HWND owner = (HWND)hwnd_ptr;
    hr = IFileDialog_Show((IFileDialog*)dlg, owner);
    if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
        IFileSaveDialog_Release(dlg);
        gui_free_filter_specs(specs, spec_count);
        gui_win_com_scope_uninit(com);
        return gui_win_result_cancel();
    }
    if (FAILED(hr)) {
        IFileSaveDialog_Release(dlg);
        gui_free_filter_specs(specs, spec_count);
        gui_win_com_scope_uninit(com);
        return gui_win_result_error(
            "show", "dialog Show failed");
    }

    // Get result path.
    IShellItem* item = NULL;
    hr = IFileDialog_GetResult((IFileDialog*)dlg, &item);
    if (FAILED(hr) || item == NULL) {
        IFileSaveDialog_Release(dlg);
        gui_free_filter_specs(specs, spec_count);
        gui_win_com_scope_uninit(com);
        return gui_win_result_error(
            "result", "GetResult failed");
    }

    char* path = gui_win_shell_item_path(item);
    IShellItem_Release(item);
    IFileSaveDialog_Release(dlg);
    gui_free_filter_specs(specs, spec_count);

    GuiNativeDialogResultEx result;
    if (path != NULL) {
        if (confirm_overwrite == 0 && gui_win_path_exists(path)) {
            free(path);
            result = gui_win_result_error(
                "overwrite_disallowed", "file already exists");
        } else {
            result = gui_win_result_paths(&path, 1);
        }
    } else {
        result = gui_win_result_error(
            "internal", "empty path from save dialog");
    }
    gui_win_com_scope_uninit(com);
    return result;
}

GuiNativeDialogResultEx gui_native_folder_dialog_ex(
    void* hwnd_ptr,
    const char* title,
    const char* start_dir,
    int can_create_directories
) {
    HRESULT hr;
    GuiWinComScope com = gui_win_com_scope_init();
    hr = com.hr;
    if (FAILED(hr)) {
        return gui_win_result_error(
            "com_init", "CoInitializeEx failed");
    }

    IFileOpenDialog* dlg = NULL;
    hr = CoCreateInstance(
        &CLSID_FileOpenDialog, NULL, CLSCTX_INPROC_SERVER,
        &IID_IFileOpenDialog, (void**)&dlg);
    if (FAILED(hr) || dlg == NULL) {
        gui_win_com_scope_uninit(com);
        return gui_win_result_error(
            "com_create", "IFileOpenDialog create failed");
    }

    // Title.
    wchar_t* wtitle = gui_utf8_to_wide(title);
    if (wtitle) {
        IFileDialog_SetTitle((IFileDialog*)dlg, wtitle);
        free(wtitle);
    }

    // Start directory.
    gui_win_set_folder((IFileDialog*)dlg, start_dir);

    // Folder-only + options.
    DWORD opts = 0;
    IFileDialog_GetOptions((IFileDialog*)dlg, &opts);
    opts |= FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM;
    (void)can_create_directories; // Windows always allows.
    IFileDialog_SetOptions((IFileDialog*)dlg, opts);

    // Show dialog.
    HWND owner = (HWND)hwnd_ptr;
    hr = IFileDialog_Show((IFileDialog*)dlg, owner);
    if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
        IFileOpenDialog_Release(dlg);
        gui_win_com_scope_uninit(com);
        return gui_win_result_cancel();
    }
    if (FAILED(hr)) {
        IFileOpenDialog_Release(dlg);
        gui_win_com_scope_uninit(com);
        return gui_win_result_error(
            "show", "dialog Show failed");
    }

    // Get result.
    IShellItem* item = NULL;
    hr = IFileDialog_GetResult((IFileDialog*)dlg, &item);
    if (FAILED(hr) || item == NULL) {
        IFileOpenDialog_Release(dlg);
        gui_win_com_scope_uninit(com);
        return gui_win_result_error(
            "result", "GetResult failed");
    }

    char* path = gui_win_shell_item_path(item);
    IShellItem_Release(item);
    IFileOpenDialog_Release(dlg);

    GuiNativeDialogResultEx result;
    if (path != NULL) {
        result = gui_win_result_paths(&path, 1);
    } else {
        result = gui_win_result_error(
            "internal", "empty path from folder dialog");
    }
    gui_win_com_scope_uninit(com);
    return result;
}

// Alert level: 0=info, 1=warning, 2=critical.
static UINT gui_win_alert_icon(int level) {
    switch (level) {
    case 2:  return MB_ICONERROR;
    case 1:  return MB_ICONWARNING;
    default: return MB_ICONINFORMATION;
    }
}

static GuiNativeAlertResult gui_win_alert_ok(void) {
    GuiNativeAlertResult r;
    r.status = gui_win_status_ok;
    r.error_code = NULL;
    r.error_message = NULL;
    return r;
}

static GuiNativeAlertResult gui_win_alert_cancel(void) {
    GuiNativeAlertResult r;
    r.status = gui_win_status_cancel;
    r.error_code = NULL;
    r.error_message = NULL;
    return r;
}

GuiNativeAlertResult gui_native_message_dialog(
    void* hwnd_ptr,
    const char* title,
    const char* body,
    int level
) {
    wchar_t* wtitle = gui_utf8_to_wide(title);
    wchar_t* wbody = gui_utf8_to_wide(body);
    MessageBoxW(
        (HWND)hwnd_ptr,
        wbody ? wbody : L"",
        wtitle ? wtitle : L"",
        MB_OK | gui_win_alert_icon(level));
    free(wtitle);
    free(wbody);
    return gui_win_alert_ok();
}

GuiNativeAlertResult gui_native_confirm_dialog(
    void* hwnd_ptr,
    const char* title,
    const char* body,
    int level
) {
    wchar_t* wtitle = gui_utf8_to_wide(title);
    wchar_t* wbody = gui_utf8_to_wide(body);
    int result = MessageBoxW(
        (HWND)hwnd_ptr,
        wbody ? wbody : L"",
        wtitle ? wtitle : L"",
        MB_YESNO | gui_win_alert_icon(level));
    free(wtitle);
    free(wbody);
    if (result == IDYES) {
        return gui_win_alert_ok();
    }
    return gui_win_alert_cancel();
}

void gui_native_alert_result_free(GuiNativeAlertResult result) {
    free(result.error_code);
    free(result.error_message);
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
    free(result.error_code);
    free(result.error_message);
}

#endif // _WIN32
