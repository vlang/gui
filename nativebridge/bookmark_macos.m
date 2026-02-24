// bookmark_macos.m — NSUserDefaults-based security-scoped
// bookmark persistence for macOS sandboxed apps.

#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

#include "dialog_bridge.h"

// NSUserDefaults key: "gui_bookmarks_<app_id>"
static NSString* gui_bookmark_defaults_key(const char* app_id) {
    return [NSString stringWithFormat:@"gui_bookmarks_%s",
        app_id];
}

int gui_bookmark_store(
    const char* app_id,
    const char* path,
    const unsigned char* data,
    int data_len
) {
    if (app_id == NULL || path == NULL
        || data == NULL || data_len <= 0) {
        return 0;
    }

    NSString* key = gui_bookmark_defaults_key(app_id);
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary* existing = [defaults dictionaryForKey:key];
    NSMutableDictionary* dict = existing
        ? [existing mutableCopy]
        : [NSMutableDictionary dictionary];

    NSString* nsPath =
        [NSString stringWithUTF8String:path];
    NSData* nsData =
        [NSData dataWithBytes:data length:(NSUInteger)data_len];
    dict[nsPath] = nsData;

    [defaults setObject:dict forKey:key];
    [defaults synchronize];
    return 1;
}

int gui_bookmark_count(const char* app_id) {
    if (app_id == NULL) {
        return 0;
    }
    NSString* key = gui_bookmark_defaults_key(app_id);
    NSDictionary* dict =
        [[NSUserDefaults standardUserDefaults]
            dictionaryForKey:key];
    return dict ? (int)dict.count : 0;
}

GuiBookmarkEntry* gui_bookmark_load_all(
    const char* app_id,
    int* out_count
) {
    *out_count = 0;
    if (app_id == NULL) {
        return NULL;
    }

    NSString* key = gui_bookmark_defaults_key(app_id);
    NSUserDefaults* defaults =
        [NSUserDefaults standardUserDefaults];
    NSDictionary* dict = [defaults dictionaryForKey:key];
    if (dict == nil || dict.count == 0) {
        return NULL;
    }

    NSInteger count = dict.count;
    GuiBookmarkEntry* entries = (GuiBookmarkEntry*)calloc(
        (size_t)count, sizeof(GuiBookmarkEntry));
    if (entries == NULL) {
        return NULL;
    }

    NSMutableDictionary* refreshed =
        [NSMutableDictionary dictionaryWithCapacity:count];
    NSMutableArray* staleKeys = [NSMutableArray array];
    int valid = 0;

    for (NSString* storedPath in dict) {
        NSData* bmData = dict[storedPath];
        if (![bmData isKindOfClass:[NSData class]]
            || bmData.length == 0) {
            [staleKeys addObject:storedPath];
            continue;
        }

        // Resolve bookmark, refresh if stale
        BOOL isStale = NO;
        NSError* error = nil;
        NSURL* url = [NSURL
            URLByResolvingBookmarkData:bmData
            options:NSURLBookmarkResolutionWithSecurityScope
            relativeToURL:nil
            bookmarkDataIsStale:&isStale
            error:&error];

        if (url == nil || error != nil) {
            [staleKeys addObject:storedPath];
            continue;
        }

        // Activate security scope
        [url startAccessingSecurityScopedResource];

        // Refresh stale bookmark
        NSData* activeData = bmData;
        if (isStale) {
            NSData* fresh = [url bookmarkDataWithOptions:
                NSURLBookmarkCreationWithSecurityScope
                includingResourceValuesForKeys:nil
                relativeToURL:nil
                error:nil];
            if (fresh != nil && fresh.length > 0) {
                activeData = fresh;
            }
        }

        NSString* resolvedPath = url.path;
        if (resolvedPath == nil
            || resolvedPath.length == 0) {
            resolvedPath = storedPath;
        }

        refreshed[resolvedPath] = activeData;

        // Fill entry
        const char* utf8 = [resolvedPath UTF8String];
        entries[valid].path = (char*)malloc(
            strlen(utf8) + 1);
        if (entries[valid].path != NULL) {
            strcpy(entries[valid].path, utf8);
        }
        entries[valid].data_len = (int)activeData.length;
        entries[valid].data = (unsigned char*)malloc(
            activeData.length);
        if (entries[valid].data != NULL) {
            memcpy(entries[valid].data,
                activeData.bytes, activeData.length);
        } else {
            entries[valid].data_len = 0;
        }
        valid++;
    }

    // Persist refreshed bookmarks, removing stale entries
    if (staleKeys.count > 0 || valid < (int)count) {
        [defaults setObject:refreshed forKey:key];
        [defaults synchronize];
    }

    *out_count = valid;
    if (valid == 0) {
        free(entries);
        return NULL;
    }
    return entries;
}

int gui_bookmark_remove(
    const char* app_id,
    const char* path
) {
    if (app_id == NULL || path == NULL) {
        return 0;
    }
    NSString* key = gui_bookmark_defaults_key(app_id);
    NSUserDefaults* defaults =
        [NSUserDefaults standardUserDefaults];
    NSDictionary* existing = [defaults dictionaryForKey:key];
    if (existing == nil) {
        return 0;
    }
    NSMutableDictionary* dict = [existing mutableCopy];
    NSString* nsPath =
        [NSString stringWithUTF8String:path];
    [dict removeObjectForKey:nsPath];
    [defaults setObject:dict forKey:key];
    [defaults synchronize];
    return 1;
}

void gui_bookmark_entries_free(
    GuiBookmarkEntry* entries,
    int count
) {
    if (entries == NULL) {
        return;
    }
    for (int i = 0; i < count; i++) {
        free(entries[i].path);
        free(entries[i].data);
    }
    free(entries);
}

int gui_bookmark_start_access(
    const unsigned char* data,
    int data_len,
    char** out_path
) {
    if (data == NULL || data_len <= 0 || out_path == NULL) {
        return 0;
    }
    *out_path = NULL;

    NSData* bmData =
        [NSData dataWithBytes:data
                       length:(NSUInteger)data_len];
    BOOL isStale = NO;
    NSError* error = nil;
    NSURL* url = [NSURL
        URLByResolvingBookmarkData:bmData
        options:NSURLBookmarkResolutionWithSecurityScope
        relativeToURL:nil
        bookmarkDataIsStale:&isStale
        error:&error];

    if (url == nil || error != nil) {
        return 0;
    }

    if (![url startAccessingSecurityScopedResource]) {
        return 0;
    }

    const char* utf8 = [url.path UTF8String];
    if (utf8 != NULL) {
        size_t len = strlen(utf8);
        *out_path = (char*)malloc(len + 1);
        if (*out_path != NULL) {
            memcpy(*out_path, utf8, len + 1);
        }
    }
    return 1;
}

void gui_bookmark_stop_access(
    const unsigned char* data,
    int data_len
) {
    if (data == NULL || data_len <= 0) {
        return;
    }

    NSData* bmData =
        [NSData dataWithBytes:data
                       length:(NSUInteger)data_len];
    BOOL isStale = NO;
    NSError* error = nil;
    NSURL* url = [NSURL
        URLByResolvingBookmarkData:bmData
        options:NSURLBookmarkResolutionWithSecurityScope
        relativeToURL:nil
        bookmarkDataIsStale:&isStale
        error:&error];

    if (url != nil && error == nil) {
        [url stopAccessingSecurityScopedResource];
    }
}
