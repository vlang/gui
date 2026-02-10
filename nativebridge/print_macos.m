// .m is required: this file uses Objective-C AppKit/Foundation APIs.
// V compiles it via `#flag darwin ... print_macos.m` in c_bindings.v.
// .mm is unnecessary because no C++ interop is used here.

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

#import "print_bridge.h"

enum {
    gui_native_print_status_ok = 0,
    gui_native_print_status_cancel = 1,
    gui_native_print_status_error = 2,
};

static GuiNativePrintResult gui_print_result_empty(void) {
    GuiNativePrintResult result;
    result.status = gui_native_print_status_error;
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

static NSString* gui_nsstring(const char* value) {
    if (value == NULL || value[0] == '\0') {
        return nil;
    }
    return [NSString stringWithUTF8String:value];
}

static GuiNativePrintResult gui_print_result_ok(void) {
    GuiNativePrintResult result = gui_print_result_empty();
    result.status = gui_native_print_status_ok;
    return result;
}

static GuiNativePrintResult gui_print_result_cancel(void) {
    GuiNativePrintResult result = gui_print_result_empty();
    result.status = gui_native_print_status_cancel;
    return result;
}

static GuiNativePrintResult gui_print_result_error(const char* code, const char* message) {
    GuiNativePrintResult result = gui_print_result_empty();
    result.status = gui_native_print_status_error;
    result.error_code = gui_strdup_c(code != NULL ? code : "internal");
    result.error_message = gui_strdup_c(message != NULL ? message : "native print error");
    return result;
}

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
) {
    (void)ns_window;
    @autoreleasepool {
        NSString* path = gui_nsstring(pdf_path);
        if (path == nil || path.length == 0) {
            return gui_print_result_error("invalid_cfg", "pdf_path is required");
        }

        BOOL is_dir = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&is_dir];
        if (!exists || is_dir) {
            return gui_print_result_error("io_error", "pdf_path does not exist or is not a file");
        }

        NSError* read_error = nil;
        NSData* pdf_data = [NSData dataWithContentsOfFile:path options:0 error:&read_error];
        if (pdf_data == nil || pdf_data.length == 0) {
            const char* msg = read_error.localizedDescription.UTF8String;
            return gui_print_result_error("io_error", msg != NULL ? msg : "failed to read PDF file");
        }

        NSPDFImageRep* rep = [NSPDFImageRep imageRepWithData:pdf_data];
        if (rep == nil) {
            return gui_print_result_error("render_error", "failed to decode PDF data");
        }

        NSImage* image = [[NSImage alloc] initWithSize:rep.size];
        [image addRepresentation:rep];
        NSImageView* image_view = [[NSImageView alloc] initWithFrame:
            NSMakeRect(0, 0, rep.size.width, rep.size.height)];
        [image_view setImage:image];
        [image_view setImageScaling:NSImageScaleAxesIndependently];

        NSPrintInfo* print_info = [[NSPrintInfo sharedPrintInfo] copy];
        if (paper_width > 0.0 && paper_height > 0.0) {
            [print_info setPaperSize:NSMakeSize((CGFloat)paper_width, (CGFloat)paper_height)];
        }
        [print_info setTopMargin:(CGFloat)margin_top];
        [print_info setRightMargin:(CGFloat)margin_right];
        [print_info setBottomMargin:(CGFloat)margin_bottom];
        [print_info setLeftMargin:(CGFloat)margin_left];
        [print_info setHorizontalPagination:NSAutoPagination];
        [print_info setVerticalPagination:NSAutoPagination];
        [print_info setOrientation:
            orientation == 1 ? NSPaperOrientationLandscape : NSPaperOrientationPortrait];

        NSPrintOperation* operation =
            [NSPrintOperation printOperationWithView:image_view printInfo:print_info];
        [operation setShowsPrintPanel:YES];
        [operation setShowsProgressPanel:YES];

        NSString* job_title = gui_nsstring(job_name);
        if (job_title == nil || job_title.length == 0) {
            job_title = gui_nsstring(title);
        }
        if (job_title != nil && job_title.length > 0 &&
            [operation respondsToSelector:@selector(setJobTitle:)]) {
            [operation setJobTitle:job_title];
        }

        BOOL ok = [operation runOperation];
        if (ok) {
            return gui_print_result_ok();
        }
        return gui_print_result_cancel();
    }
}

void gui_native_print_result_free(GuiNativePrintResult result) {
    if (result.error_code != NULL) {
        free(result.error_code);
    }
    if (result.error_message != NULL) {
        free(result.error_message);
    }
}
