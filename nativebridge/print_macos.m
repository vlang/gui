// .m is required: this file uses Objective-C AppKit/Foundation APIs.
// V compiles it via `#flag darwin ... print_macos.m` in c_bindings.v.
// .mm is unnecessary because no C++ interop is used here.

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

#import "print_bridge.h"

@interface GuiNativePdfPrintView : NSView

@property(nonatomic, strong) NSPDFImageRep* rep;
@property(nonatomic, assign) NSInteger page_count;

- (instancetype)initWithPDFRep:(NSPDFImageRep*)rep frame:(NSRect)frame;

@end

@implementation GuiNativePdfPrintView

- (instancetype)initWithPDFRep:(NSPDFImageRep*)rep frame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.rep = rep;
        NSInteger count = (NSInteger)[rep pageCount];
        self.page_count = count > 0 ? count : 1;
    }
    return self;
}

- (BOOL)knowsPageRange:(NSRangePointer)range {
    if (range != NULL) {
        range->location = 1;
        range->length = self.page_count;
    }
    return YES;
}

- (NSRect)rectForPage:(NSInteger)page {
    NSInteger page_index = page - 1;
    if (page_index < 0) {
        page_index = 0;
    }
    if (page_index >= self.page_count) {
        page_index = self.page_count - 1;
    }
    [self.rep setCurrentPage:(int)page_index];
    return [self bounds];
}

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    NSSize source_size = [self.rep size];
    if (source_size.width <= 0.0 || source_size.height <= 0.0) {
        [self.rep drawInRect:bounds];
        return;
    }

    CGFloat scale_x = bounds.size.width / source_size.width;
    CGFloat scale_y = bounds.size.height / source_size.height;
    CGFloat scale = MIN(scale_x, scale_y);

    NSSize draw_size = NSMakeSize(source_size.width * scale, source_size.height * scale);
    NSRect target = NSMakeRect(
        bounds.origin.x + (bounds.size.width - draw_size.width) * 0.5,
        bounds.origin.y + (bounds.size.height - draw_size.height) * 0.5,
        draw_size.width,
        draw_size.height
    );
    [self.rep drawInRect:target];
}

@end

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

        CGFloat view_width = (CGFloat)paper_width - (CGFloat)margin_left - (CGFloat)margin_right;
        CGFloat view_height = (CGFloat)paper_height - (CGFloat)margin_top - (CGFloat)margin_bottom;
        if (view_width <= 0.0 || view_height <= 0.0) {
            view_width = rep.size.width > 0.0 ? rep.size.width : 612.0;
            view_height = rep.size.height > 0.0 ? rep.size.height : 792.0;
        }
        GuiNativePdfPrintView* pdf_view = [[GuiNativePdfPrintView alloc]
            initWithPDFRep:rep
            frame:NSMakeRect(0, 0, view_width, view_height)];

        NSPrintOperation* operation =
            [NSPrintOperation printOperationWithView:pdf_view printInfo:print_info];
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
