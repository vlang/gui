// notification_macos.m — macOS native notifications.
// Uses UNUserNotificationCenter when a bundle ID is present
// (packaged apps). Falls back to osascript
// `display notification` for unbundled executables (e.g.
// v run during development).
// Compiled via #flag darwin ... notification_macos.m in
// c_bindings.v.

#import <UserNotifications/UserNotifications.h>
#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>

#include "notification_bridge.h"

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

// Cached authorization state. After the first grant the OS
// returns immediately, but we skip the semaphore round-trip
// entirely on subsequent calls.
static BOOL gui_notif_auth_cached = NO;
static BOOL gui_notif_auth_granted = NO;

// 30-second timeout for authorization / delivery semaphores.
// Prevents indefinite render-thread hang if the permission
// dialog is dismissed without a choice.
#define GUI_NOTIF_SEM_TIMEOUT_NS (30LL * NSEC_PER_SEC)

// Modern path: UNUserNotificationCenter (macOS 10.14+).
// Requires a bundled app with Info.plist.
static GuiNativeNotificationResult gui_notif_send_un(
    const char* title, const char* body
) {
    UNUserNotificationCenter* center =
        [UNUserNotificationCenter
            currentNotificationCenter];

    // Request permission (cached after first response).
    if (!gui_notif_auth_cached) {
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
        long wait_result = dispatch_semaphore_wait(
            sem,
            dispatch_time(DISPATCH_TIME_NOW,
                GUI_NOTIF_SEM_TIMEOUT_NS));
        // ARC manages GCD objects; no dispatch_release needed.

        if (wait_result != 0) {
            return gui_notif_result_error(
                "auth_timeout",
                "authorization request timed out");
        }

        gui_notif_auth_cached = YES;
        gui_notif_auth_granted = granted;

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
    }

    if (!gui_notif_auth_granted) {
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
    long add_result = dispatch_semaphore_wait(
        sem2,
        dispatch_time(DISPATCH_TIME_NOW,
            GUI_NOTIF_SEM_TIMEOUT_NS));
    // ARC manages GCD objects; no dispatch_release needed.

    if (add_result != 0) {
        return gui_notif_result_error(
            "delivery_timeout",
            "notification delivery timed out");
    }

    if (addError != nil) {
        const char* desc =
            [[addError localizedDescription] UTF8String];
        return gui_notif_result_error(
            "delivery_error", desc);
    }

    return gui_notif_result_ok();
}

// Fallback path: osascript `display notification`.
// Works for unbundled executables on all macOS versions.
// Title and body are passed via environment variables to
// avoid AppleScript injection — no string escaping needed.
static GuiNativeNotificationResult gui_notif_send_osascript(
    const char* title, const char* body
) {
    // AppleScript reads title/body from env vars, so
    // arbitrary user content cannot break the script.
    NSString* script;
    if (body != NULL && body[0] != '\0') {
        script = @"display notification"
            " (system attribute \"GUI_NOTIF_BODY\")"
            " with title"
            " (system attribute \"GUI_NOTIF_TITLE\")";
    } else {
        script = @"display notification"
            " \"\" with title"
            " (system attribute \"GUI_NOTIF_TITLE\")";
    }

    NSTask* task = [[NSTask alloc] init];
    task.executableURL =
        [NSURL fileURLWithPath:@"/usr/bin/osascript"];
    task.arguments = @[@"-e", script];
    task.standardOutput = [NSPipe pipe];
    task.standardError  = [NSPipe pipe];

    // Inherit current environment, add notification vars.
    NSMutableDictionary* env = [[[NSProcessInfo
        processInfo] environment] mutableCopy];
    env[@"GUI_NOTIF_TITLE"] =
        [NSString stringWithUTF8String:title];
    if (body != NULL && body[0] != '\0') {
        env[@"GUI_NOTIF_BODY"] =
            [NSString stringWithUTF8String:body];
    }
    task.environment = env;

    // Timeout guard — consistent with the UN path's 30s limit.
    // Set terminationHandler before launch to avoid a race
    // where the task finishes before the handler is installed.
    dispatch_semaphore_t sem =
        dispatch_semaphore_create(0);
    task.terminationHandler =
        ^(NSTask* __unused t) {
            dispatch_semaphore_signal(sem);
        };

    NSError* launchErr = nil;
    [task launchAndReturnError:&launchErr];
    if (launchErr != nil) {
        const char* desc =
            [[launchErr localizedDescription] UTF8String];
        return gui_notif_result_error(
            "osascript_launch", desc);
    }

    long wait_result = dispatch_semaphore_wait(
        sem,
        dispatch_time(DISPATCH_TIME_NOW,
            GUI_NOTIF_SEM_TIMEOUT_NS));
    if (wait_result != 0) {
        [task terminate];
        return gui_notif_result_error(
            "osascript_timeout",
            "osascript timed out");
    }

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
    gui_notif_result_free(result);
}
