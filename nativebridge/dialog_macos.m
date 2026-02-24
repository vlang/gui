// .m is required: this file uses Objective-C AppKit/Foundation APIs.
// V compiles it via `#flag darwin ... dialog_macos.m` in c_bindings.v.
// .mm is unnecessary because no C++ interop is used here.

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

#import "dialog_bridge.h"

enum {
    gui_native_status_ok = 0,
    gui_native_status_cancel = 1,
    gui_native_status_error = 2,
};

static GuiNativeDialogResultEx gui_dialog_result_ex_empty(void) {
    GuiNativeDialogResultEx result;
    result.status = gui_native_status_error;
    result.path_count = 0;
    result.entries = NULL;
    result.error_code = NULL;
    result.error_message = NULL;
    return result;
}

static char* gui_strdup_c(const char* value) {
    if (value == NULL) {
        return NULL;
    }
    size_t len = strlen(value);
    char* out = (char*)malloc(len + 1);
    if (out == NULL) {
        return NULL;
    }
    memcpy(out, value, len + 1);
    return out;
}

static char* gui_strdup_ns(NSString* value) {
    if (value == nil) {
        return NULL;
    }
    const char* utf8 = [value UTF8String];
    if (utf8 == NULL) {
        return NULL;
    }
    return gui_strdup_c(utf8);
}

static NSString* gui_nsstring(const char* value) {
    if (value == NULL || value[0] == '\0') {
        return nil;
    }
    return [NSString stringWithUTF8String:value];
}

static NSString* gui_normalize_extension(NSString* value) {
    if (value == nil) {
        return nil;
    }
    NSString* ext = [[value stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    while ([ext hasPrefix:@"."]) {
        ext = [ext substringFromIndex:1];
    }
    return ext.length > 0 ? ext : nil;
}

static NSArray<NSString*>* gui_extensions_from_csv(const char* csv_value) {
    NSString* csv = gui_nsstring(csv_value);
    if (csv == nil || csv.length == 0) {
        return @[];
    }
    NSArray<NSString*>* parts = [csv componentsSeparatedByString:@","];
    NSMutableArray<NSString*>* out = [NSMutableArray arrayWithCapacity:parts.count];
    NSMutableSet<NSString*>* seen = [NSMutableSet setWithCapacity:parts.count];
    for (NSString* part in parts) {
        NSString* ext = gui_normalize_extension(part);
        if (ext == nil || [seen containsObject:ext]) {
            continue;
        }
        [seen addObject:ext];
        [out addObject:ext];
    }
    return out;
}

static void gui_apply_panel_title(id panel, const char* title_value) {
    NSString* title = gui_nsstring(title_value);
    if (title != nil && [panel respondsToSelector:@selector(setTitle:)]) {
        [panel setTitle:title];
    }
}

static void gui_apply_panel_start_dir(id panel, const char* start_dir_value) {
    NSString* start_dir = gui_nsstring(start_dir_value);
    if (start_dir == nil) {
        return;
    }
    BOOL is_dir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:start_dir isDirectory:&is_dir];
    if (!exists || !is_dir) {
        return;
    }
    if ([panel respondsToSelector:@selector(setDirectoryURL:)]) {
        [panel setDirectoryURL:[NSURL fileURLWithPath:start_dir isDirectory:YES]];
    }
}

static GuiNativeDialogResultEx gui_dialog_result_ex_error(const char* code, const char* message) {
    GuiNativeDialogResultEx result = gui_dialog_result_ex_empty();
    result.status = gui_native_status_error;
    result.error_code = gui_strdup_c(code != NULL ? code : "internal");
    result.error_message = gui_strdup_c(message != NULL ? message : "native dialog error");
    return result;
}

static GuiNativeDialogResultEx gui_dialog_result_ex_cancel(void) {
    GuiNativeDialogResultEx result = gui_dialog_result_ex_empty();
    result.status = gui_native_status_cancel;
    return result;
}

// Create a security-scoped bookmark for a URL.
// Returns NSData* or nil on failure.
static NSData* gui_create_bookmark(NSURL* url) {
    NSError* error = nil;
    NSData* data = [url bookmarkDataWithOptions:
        NSURLBookmarkCreationWithSecurityScope
        includingResourceValuesForKeys:nil
        relativeToURL:nil
        error:&error];
    if (error != nil || data == nil) {
        return nil;
    }
    return data;
}

// Build a GuiNativeDialogResultEx from an array of URLs,
// creating security-scoped bookmarks for each.
static GuiNativeDialogResultEx gui_dialog_result_ex_ok_urls(NSArray<NSURL*>* urls) {
    GuiNativeDialogResultEx result = gui_dialog_result_ex_empty();
    NSInteger count = urls.count;
    if (count <= 0) {
        result.status = gui_native_status_cancel;
        return result;
    }

    result.status = gui_native_status_ok;
    result.path_count = (int)count;
    result.entries = (GuiBookmarkEntry*)calloc(
        (size_t)count, sizeof(GuiBookmarkEntry));
    if (result.entries == NULL) {
        return gui_dialog_result_ex_error(
            "internal", "native dialog allocation failed");
    }

    for (NSInteger i = 0; i < count; i++) {
        NSURL* url = urls[i];
        result.entries[i].path = gui_strdup_ns(url.path);
        if (result.entries[i].path == NULL) {
            gui_native_dialog_result_ex_free(result);
            return gui_dialog_result_ex_error(
                "internal",
                "native dialog path allocation failed");
        }
        NSData* bm = gui_create_bookmark(url);
        if (bm != nil && bm.length > 0) {
            result.entries[i].data_len = (int)bm.length;
            result.entries[i].data =
                (unsigned char*)malloc(bm.length);
            if (result.entries[i].data != NULL) {
                memcpy(result.entries[i].data,
                    bm.bytes, bm.length);
            } else {
                result.entries[i].data_len = 0;
            }
        }
    }

    return result;
}

// Build a result ex from a single path string (save dialog).
static GuiNativeDialogResultEx gui_dialog_result_ex_ok_path(NSString* path) {
    NSURL* url = [NSURL fileURLWithPath:path];
    if (url == nil) {
        return gui_dialog_result_ex_error(
            "internal", "could not create URL from path");
    }
    return gui_dialog_result_ex_ok_urls(@[url]);
}

GuiNativeDialogResultEx gui_native_open_dialog_ex(
    void* ns_window,
    const char* title,
    const char* start_dir,
    const char* extensions_csv,
    int allow_multiple
) {
    (void)ns_window;
    @autoreleasepool {
        NSOpenPanel* panel = [NSOpenPanel openPanel];
        panel.canChooseFiles = YES;
        panel.canChooseDirectories = NO;
        panel.allowsMultipleSelection = allow_multiple != 0;
        panel.canCreateDirectories = NO;

        gui_apply_panel_title(panel, title);
        gui_apply_panel_start_dir(panel, start_dir);

        NSArray<NSString*>* extensions =
            gui_extensions_from_csv(extensions_csv);
        if (extensions.count > 0) {
            panel.allowedFileTypes = extensions;
        }

        NSInteger response = [panel runModal];
        if (response == NSModalResponseCancel) {
            return gui_dialog_result_ex_cancel();
        }
        if (response != NSModalResponseOK) {
            return gui_dialog_result_ex_error(
                "internal", "native open dialog failed");
        }

        return gui_dialog_result_ex_ok_urls(panel.URLs);
    }
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
    (void)ns_window;
    @autoreleasepool {
        NSSavePanel* panel = [NSSavePanel savePanel];
        panel.canCreateDirectories = YES;

        gui_apply_panel_title(panel, title);
        gui_apply_panel_start_dir(panel, start_dir);

        NSString* initial_name = gui_nsstring(default_name);
        if (initial_name != nil && initial_name.length > 0) {
            panel.nameFieldStringValue = initial_name;
        }

        NSMutableArray<NSString*>* extensions =
            [gui_extensions_from_csv(extensions_csv) mutableCopy];
        NSString* normalized_default_extension =
            gui_normalize_extension(gui_nsstring(default_extension));
        if (normalized_default_extension != nil
            && normalized_default_extension.length > 0) {
            if (![extensions
                    containsObject:normalized_default_extension]) {
                [extensions
                    addObject:normalized_default_extension];
            }
        }
        if (extensions.count > 0) {
            panel.allowedFileTypes = extensions;
        }

        NSInteger response = [panel runModal];
        if (response == NSModalResponseCancel) {
            return gui_dialog_result_ex_cancel();
        }
        if (response != NSModalResponseOK) {
            return gui_dialog_result_ex_error(
                "internal", "native save dialog failed");
        }

        NSURL* url = panel.URL;
        if (url == nil || url.path.length == 0) {
            return gui_dialog_result_ex_error(
                "internal",
                "native save dialog returned empty path");
        }

        NSString* path = url.path;
        if (normalized_default_extension != nil
            && normalized_default_extension.length > 0) {
            if (url.pathExtension.length == 0) {
                path = [path stringByAppendingPathExtension:
                    normalized_default_extension];
            }
        }

        if (confirm_overwrite == 0
            && [[NSFileManager defaultManager]
                   fileExistsAtPath:path]) {
            return gui_dialog_result_ex_error(
                "overwrite_disallowed", "file already exists");
        }

        return gui_dialog_result_ex_ok_path(path);
    }
}

GuiNativeDialogResultEx gui_native_folder_dialog_ex(
    void* ns_window,
    const char* title,
    const char* start_dir,
    int can_create_directories
) {
    (void)ns_window;
    @autoreleasepool {
        NSOpenPanel* panel = [NSOpenPanel openPanel];
        panel.canChooseFiles = NO;
        panel.canChooseDirectories = YES;
        panel.allowsMultipleSelection = NO;
        panel.canCreateDirectories = can_create_directories != 0;

        gui_apply_panel_title(panel, title);
        gui_apply_panel_start_dir(panel, start_dir);

        NSInteger response = [panel runModal];
        if (response == NSModalResponseCancel) {
            return gui_dialog_result_ex_cancel();
        }
        if (response != NSModalResponseOK) {
            return gui_dialog_result_ex_error(
                "internal", "native folder dialog failed");
        }

        NSURL* url = panel.URL;
        if (url == nil || url.path.length == 0) {
            return gui_dialog_result_ex_error(
                "internal",
                "native folder dialog returned empty path");
        }

        return gui_dialog_result_ex_ok_urls(@[url]);
    }
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
