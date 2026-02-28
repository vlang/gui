// notification_macos.m — macOS native notifications.
// Uses UNUserNotificationCenter when a bundle ID is present
// (packaged apps). Falls back to the deprecated
// NSUserNotificationCenter for unbundled executables (e.g.
// v run during development).
// Compiled via #flag darwin ... notification_macos.m in
// c_bindings.v.

#import <UserNotifications/UserNotifications.h>
#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>
#include <dispatch/dispatch.h>

#include "notification_bridge.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

enum {
    gui_notif_status_ok     = 0,
    gui_notif_status_denied = 1,
    gui_notif_status_error  = 2,
};

static char* gui_notif_strdup(const char* s) {
    if (s == NULL) return NULL;
    size_t len = strlen(s);
    char* out = (char*)malloc(len + 1);
    if (out) memcpy(out, s, len + 1);
    return out;
}

static GuiNativeNotificationResult gui_notif_result_ok(void) {
    GuiNativeNotificationResult r;
    r.status = gui_notif_status_ok;
    r.error_code = NULL;
    r.error_message = NULL;
    return r;
}

static GuiNativeNotificationResult gui_notif_result_denied(void) {
    GuiNativeNotificationResult r;
    r.status = gui_notif_status_denied;
    r.error_code = gui_notif_strdup("denied");
    r.error_message = gui_notif_strdup(
        "notification permission denied");
    return r;
}

static GuiNativeNotificationResult gui_notif_result_error(
    const char* code, const char* msg
) {
    GuiNativeNotificationResult r;
    r.status = gui_notif_status_error;
    r.error_code = gui_notif_strdup(
        code ? code : "internal");
    r.error_message = gui_notif_strdup(
        msg ? msg : "notification error");
    return r;
}

// Returns YES when the process has a real bundle identifier
// (i.e. a packaged .app). Unbundled executables get a
// synthetic identifier from AppKit which is not sufficient
// for UNUserNotificationCenter.
static BOOL gui_notif_has_bundle(void) {
    NSBundle* main = [NSBundle mainBundle];
    if (main == nil) return NO;
    NSString* bid = [main bundleIdentifier];
    return (bid != nil && bid.length > 0);
}

// Modern path: UNUserNotificationCenter (macOS 10.14+).
// Requires a bundled app with Info.plist.
static GuiNativeNotificationResult gui_notif_send_un(
    const char* title, const char* body
) {
    UNUserNotificationCenter* center =
        [UNUserNotificationCenter
            currentNotificationCenter];

    // Request permission synchronously via semaphore.
    __block BOOL granted = NO;
    __block NSError* authError = nil;
    dispatch_semaphore_t sem =
        dispatch_semaphore_create(0);

    [center requestAuthorizationWithOptions:
        (UNAuthorizationOptionAlert |
         UNAuthorizationOptionSound)
        completionHandler:
            ^(BOOL g, NSError* _Nullable err) {
                granted = g;
                authError = err;
                dispatch_semaphore_signal(sem);
            }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    if (!granted) {
        if (authError != nil) {
            const char* desc =
                [[authError localizedDescription]
                    UTF8String];
            return gui_notif_result_error(
                "auth_error", desc);
        }
        return gui_notif_result_denied();
    }

    // Build notification content.
    UNMutableNotificationContent* content =
        [[UNMutableNotificationContent alloc] init];
    content.title = [NSString
        stringWithUTF8String:title];
    if (body != NULL && body[0] != '\0') {
        content.body = [NSString
            stringWithUTF8String:body];
    }
    content.sound = [UNNotificationSound defaultSound];

    NSString* identifier = [[NSUUID UUID] UUIDString];
    UNNotificationRequest* request =
        [UNNotificationRequest
            requestWithIdentifier:identifier
            content:content
            trigger:nil];

    __block NSError* addError = nil;
    dispatch_semaphore_t sem2 =
        dispatch_semaphore_create(0);
    [center addNotificationRequest:request
        withCompletionHandler:
            ^(NSError* _Nullable err) {
                addError = err;
                dispatch_semaphore_signal(sem2);
            }];
    dispatch_semaphore_wait(sem2, DISPATCH_TIME_FOREVER);

    if (addError != nil) {
        const char* desc =
            [[addError localizedDescription] UTF8String];
        return gui_notif_result_error(
            "delivery_error", desc);
    }

    return gui_notif_result_ok();
}

// Escape a C string for embedding in an AppleScript
// single-quoted literal. Backslashes and single quotes
// need escaping.
static NSString* gui_notif_escape_applescript(
    const char* s
) {
    if (s == NULL || s[0] == '\0') return @"";
    NSString* ns = [NSString stringWithUTF8String:s];
    ns = [ns stringByReplacingOccurrencesOfString:@"\\"
        withString:@"\\\\"];
    ns = [ns stringByReplacingOccurrencesOfString:@"\""
        withString:@"\\\""];
    return ns;
}

// Fallback path: osascript `display notification`.
// Works for unbundled executables on all macOS versions.
static GuiNativeNotificationResult gui_notif_send_osascript(
    const char* title, const char* body
) {
    NSString* esc_title =
        gui_notif_escape_applescript(title);
    NSString* esc_body =
        gui_notif_escape_applescript(body);

    NSString* script;
    if (body != NULL && body[0] != '\0') {
        script = [NSString stringWithFormat:
            @"display notification \"%@\""
             " with title \"%@\"",
            esc_body, esc_title];
    } else {
        script = [NSString stringWithFormat:
            @"display notification \"\" with title \"%@\"",
            esc_title];
    }

    NSTask* task = [[NSTask alloc] init];
    task.executableURL =
        [NSURL fileURLWithPath:@"/usr/bin/osascript"];
    task.arguments = @[@"-e", script];
    task.standardOutput = [NSPipe pipe];
    task.standardError  = [NSPipe pipe];

    NSError* launchErr = nil;
    [task launchAndReturnError:&launchErr];
    if (launchErr != nil) {
        const char* desc =
            [[launchErr localizedDescription] UTF8String];
        return gui_notif_result_error(
            "osascript_launch", desc);
    }
    [task waitUntilExit];

    if (task.terminationStatus != 0) {
        return gui_notif_result_error(
            "osascript_exit", "osascript returned non-zero");
    }

    return gui_notif_result_ok();
}

GuiNativeNotificationResult gui_native_send_notification(
    const char* title,
    const char* body
) {
    @autoreleasepool {
        if (title == NULL || title[0] == '\0') {
            return gui_notif_result_error(
                "invalid_cfg", "title is required");
        }

        if (gui_notif_has_bundle()) {
            return gui_notif_send_un(title, body);
        }
        return gui_notif_send_osascript(title, body);
    }
}

void gui_native_notification_result_free(
    GuiNativeNotificationResult result
) {
    if (result.error_code != NULL) free(result.error_code);
    if (result.error_message != NULL)
        free(result.error_message);
}

#pragma clang diagnostic pop
