// portal_linux.c — XDG Desktop Portal FileChooser via D-Bus.
// Follows the a11y_linux.c D-Bus pattern. Uses libdbus-1
// (already linked for AT-SPI2 a11y).

#include <dbus/dbus.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "dialog_bridge.h"

#define PORTAL_BUS    "org.freedesktop.portal.Desktop"
#define PORTAL_PATH   "/org/freedesktop/portal/desktop"
#define PORTAL_FC     "org.freedesktop.portal.FileChooser"
#define PORTAL_REQ    "org.freedesktop.portal.Request"

enum {
    PORTAL_STATUS_OK = 0,
    PORTAL_STATUS_CANCEL = 1,
    PORTAL_STATUS_ERROR = 2,
};

// Cached session bus and availability flag.
static DBusConnection* portal_bus = NULL;
static int portal_checked = 0;
static int portal_is_available = 0;

static DBusConnection* portal_get_bus(void) {
    if (portal_bus != NULL) {
        return portal_bus;
    }
    DBusError err;
    dbus_error_init(&err);
    portal_bus = dbus_bus_get(DBUS_BUS_SESSION, &err);
    if (dbus_error_is_set(&err)) {
        dbus_error_free(&err);
        return NULL;
    }
    return portal_bus;
}

int gui_portal_available(void) {
    if (portal_checked) {
        return portal_is_available;
    }
    portal_checked = 1;

    DBusConnection* bus = portal_get_bus();
    if (bus == NULL) {
        return 0;
    }

    // Check if the portal bus name is activatable
    DBusError err;
    dbus_error_init(&err);
    int has_owner = dbus_bus_name_has_owner(bus, PORTAL_BUS, &err);
    if (dbus_error_is_set(&err)) {
        dbus_error_free(&err);
        // Try to activate the service
        dbus_error_init(&err);
        dbus_bus_start_service_by_name(bus, PORTAL_BUS, 0, NULL, &err);
        if (dbus_error_is_set(&err)) {
            dbus_error_free(&err);
            portal_is_available = 0;
            return 0;
        }
        has_owner = 1;
    }

    portal_is_available = has_owner ? 1 : 0;
    return portal_is_available;
}

static GuiNativeDialogResultEx portal_result_error(
    const char* msg
) {
    GuiNativeDialogResultEx result;
    memset(&result, 0, sizeof(result));
    result.status = PORTAL_STATUS_ERROR;
    result.error_code = strdup("portal_error");
    result.error_message = strdup(msg ? msg : "unknown error");
    return result;
}

static GuiNativeDialogResultEx portal_result_cancel(void) {
    GuiNativeDialogResultEx result;
    memset(&result, 0, sizeof(result));
    result.status = PORTAL_STATUS_CANCEL;
    return result;
}

// Generate a unique handle token: "gui_<timestamp>_<counter>"
static void portal_handle_token(char* buf, size_t len) {
    static unsigned int counter = 0;
    snprintf(buf, len, "gui_%lu_%u",
        (unsigned long)time(NULL), counter++);
}

// Convert "file:///path" URI to "/path". Returns malloc'd string.
static char* portal_uri_to_path(const char* uri) {
    if (uri == NULL) return NULL;
    if (strncmp(uri, "file://", 7) == 0) {
        return strdup(uri + 7);
    }
    return strdup(uri);
}

// Parse the Response signal. Extracts response code and
// "uris" string array from the results dict.
static GuiNativeDialogResultEx portal_parse_response(
    DBusMessage* msg
) {
    DBusMessageIter args;
    if (!dbus_message_iter_init(msg, &args)) {
        return portal_result_error("empty response signal");
    }

    // First arg: uint32 response
    if (dbus_message_iter_get_arg_type(&args) != DBUS_TYPE_UINT32) {
        return portal_result_error("bad response type");
    }
    dbus_uint32_t response = 0;
    dbus_message_iter_get_basic(&args, &response);

    if (response == 1) {
        return portal_result_cancel();
    }
    if (response != 0) {
        return portal_result_error("portal returned error");
    }

    // Second arg: a{sv} results dict
    if (!dbus_message_iter_next(&args)) {
        return portal_result_error("no results dict");
    }
    if (dbus_message_iter_get_arg_type(&args)
        != DBUS_TYPE_ARRAY) {
        return portal_result_error("results not a dict");
    }

    DBusMessageIter dict;
    dbus_message_iter_recurse(&args, &dict);

    // Walk dict entries looking for "uris"
    while (dbus_message_iter_get_arg_type(&dict)
           == DBUS_TYPE_DICT_ENTRY) {
        DBusMessageIter entry;
        dbus_message_iter_recurse(&dict, &entry);

        // Key
        if (dbus_message_iter_get_arg_type(&entry)
            != DBUS_TYPE_STRING) {
            dbus_message_iter_next(&dict);
            continue;
        }
        const char* key = NULL;
        dbus_message_iter_get_basic(&entry, &key);

        if (strcmp(key, "uris") != 0) {
            dbus_message_iter_next(&dict);
            continue;
        }

        // Value: variant containing as (array of strings)
        if (!dbus_message_iter_next(&entry)) break;
        if (dbus_message_iter_get_arg_type(&entry)
            != DBUS_TYPE_VARIANT) break;

        DBusMessageIter variant;
        dbus_message_iter_recurse(&entry, &variant);
        if (dbus_message_iter_get_arg_type(&variant)
            != DBUS_TYPE_ARRAY) break;

        DBusMessageIter arr;
        dbus_message_iter_recurse(&variant, &arr);

        // Count URIs
        int count = 0;
        DBusMessageIter counter_iter = arr;
        while (dbus_message_iter_get_arg_type(&counter_iter)
               == DBUS_TYPE_STRING) {
            count++;
            dbus_message_iter_next(&counter_iter);
        }

        if (count == 0) {
            return portal_result_cancel();
        }

        GuiNativeDialogResultEx result;
        memset(&result, 0, sizeof(result));
        result.status = PORTAL_STATUS_OK;
        result.path_count = count;
        result.entries = (GuiBookmarkEntry*)calloc(
            (size_t)count, sizeof(GuiBookmarkEntry));
        if (result.entries == NULL) {
            return portal_result_error("alloc failed");
        }

        for (int i = 0; i < count; i++) {
            const char* uri = NULL;
            dbus_message_iter_get_basic(&arr, &uri);
            result.entries[i].path = portal_uri_to_path(uri);
            result.entries[i].data = NULL;
            result.entries[i].data_len = 0;
            dbus_message_iter_next(&arr);
        }

        return result;
    }

    // No "uris" key found
    return portal_result_cancel();
}

// Add match rule for the portal Request.Response signal.
static void portal_add_match(
    DBusConnection* bus,
    const char* sender,
    const char* handle_path
) {
    char rule[512];
    snprintf(rule, sizeof(rule),
        "type='signal',sender='%s',interface='" PORTAL_REQ
        "',member='Response',path='%s'",
        sender, handle_path);
    DBusError err;
    dbus_error_init(&err);
    dbus_bus_add_match(bus, rule, &err);
    dbus_connection_flush(bus);
    if (dbus_error_is_set(&err)) {
        dbus_error_free(&err);
    }
}

static void portal_remove_match(
    DBusConnection* bus,
    const char* sender,
    const char* handle_path
) {
    char rule[512];
    snprintf(rule, sizeof(rule),
        "type='signal',sender='%s',interface='" PORTAL_REQ
        "',member='Response',path='%s'",
        sender, handle_path);
    DBusError err;
    dbus_error_init(&err);
    dbus_bus_remove_match(bus, rule, &err);
    if (dbus_error_is_set(&err)) {
        dbus_error_free(&err);
    }
}

// Wait for the Response signal on handle_path. Timeout 120s.
static GuiNativeDialogResultEx portal_wait_response(
    DBusConnection* bus,
    const char* sender,
    const char* handle_path
) {
    portal_add_match(bus, sender, handle_path);

    // Block-wait with timeout
    int timeout_ms = 120000;
    int elapsed = 0;
    int step = 100; // poll interval in ms

    while (elapsed < timeout_ms) {
        dbus_connection_read_write(bus, step);
        DBusMessage* msg = dbus_connection_pop_message(bus);
        if (msg == NULL) {
            elapsed += step;
            continue;
        }

        if (dbus_message_is_signal(msg, PORTAL_REQ,
                                   "Response")
            && dbus_message_get_path(msg) != NULL
            && strcmp(dbus_message_get_path(msg),
                      handle_path) == 0) {
            GuiNativeDialogResultEx result =
                portal_parse_response(msg);
            dbus_message_unref(msg);
            portal_remove_match(bus, sender, handle_path);
            return result;
        }

        dbus_message_unref(msg);
        elapsed += step;
    }

    portal_remove_match(bus, sender, handle_path);
    return portal_result_error("portal dialog timed out");
}

// Build the expected handle path from the bus unique name
// and handle_token.
static void portal_build_handle_path(
    DBusConnection* bus,
    const char* token,
    char* buf,
    size_t len
) {
    const char* name = dbus_bus_get_unique_name(bus);
    if (name == NULL) {
        buf[0] = '\0';
        return;
    }
    // Unique name is like ":1.42" → replace : and . with _
    char sanitized[128];
    size_t j = 0;
    for (size_t i = 0; name[i] && j < sizeof(sanitized) - 1;
         i++) {
        if (name[i] == ':' || name[i] == '.') {
            sanitized[j++] = '_';
        } else {
            sanitized[j++] = name[i];
        }
    }
    sanitized[j] = '\0';

    snprintf(buf, len,
        "/org/freedesktop/portal/desktop/request/%s/%s",
        sanitized, token);
}

// Build file filter for the portal. Filters are encoded as
// a(sa(us)) where each filter is (name, [(type, glob)]).
// We build from CSV extensions: "png,jpg" → filter
// "Files" with globs "*.png", "*.jpg".
static void portal_append_filters(
    DBusMessageIter* opts_iter,
    const char* extensions_csv
) {
    if (extensions_csv == NULL || extensions_csv[0] == '\0') {
        return;
    }

    // Open dict entry for "filters"
    DBusMessageIter entry, variant, filters_array,
        filter_struct, patterns_array, pattern_struct;

    dbus_message_iter_open_container(
        opts_iter, DBUS_TYPE_DICT_ENTRY, NULL, &entry);

    const char* key = "filters";
    dbus_message_iter_append_basic(
        &entry, DBUS_TYPE_STRING, &key);

    dbus_message_iter_open_container(
        &entry, DBUS_TYPE_VARIANT, "a(sa(us))", &variant);

    dbus_message_iter_open_container(
        &variant, DBUS_TYPE_ARRAY, "(sa(us))",
        &filters_array);

    // Single filter named "Files"
    dbus_message_iter_open_container(
        &filters_array, DBUS_TYPE_STRUCT, NULL,
        &filter_struct);

    const char* filter_name = "Files";
    dbus_message_iter_append_basic(
        &filter_struct, DBUS_TYPE_STRING, &filter_name);

    dbus_message_iter_open_container(
        &filter_struct, DBUS_TYPE_ARRAY, "(us)",
        &patterns_array);

    // Parse CSV and add each as a glob pattern
    char* csv_copy = strdup(extensions_csv);
    char* saveptr = NULL;
    char* token = strtok_r(csv_copy, ",", &saveptr);
    while (token != NULL) {
        // Skip leading whitespace/dots
        while (*token == ' ' || *token == '.') token++;
        if (*token != '\0') {
            char glob[64];
            snprintf(glob, sizeof(glob), "*.%s", token);

            dbus_message_iter_open_container(
                &patterns_array, DBUS_TYPE_STRUCT, NULL,
                &pattern_struct);

            dbus_uint32_t type = 0; // 0 = glob pattern
            dbus_message_iter_append_basic(
                &pattern_struct, DBUS_TYPE_UINT32, &type);
            const char* glob_ptr = glob;
            dbus_message_iter_append_basic(
                &pattern_struct, DBUS_TYPE_STRING,
                &glob_ptr);

            dbus_message_iter_close_container(
                &patterns_array, &pattern_struct);
        }
        token = strtok_r(NULL, ",", &saveptr);
    }
    free(csv_copy);

    dbus_message_iter_close_container(
        &filter_struct, &patterns_array);
    dbus_message_iter_close_container(
        &filters_array, &filter_struct);
    dbus_message_iter_close_container(
        &variant, &filters_array);
    dbus_message_iter_close_container(
        &entry, &variant);
    dbus_message_iter_close_container(
        opts_iter, &entry);
}

// Append a string option to the options dict.
static void portal_append_string_option(
    DBusMessageIter* opts_iter,
    const char* key,
    const char* value
) {
    if (value == NULL || value[0] == '\0') return;

    DBusMessageIter entry, variant;
    dbus_message_iter_open_container(
        opts_iter, DBUS_TYPE_DICT_ENTRY, NULL, &entry);
    dbus_message_iter_append_basic(
        &entry, DBUS_TYPE_STRING, &key);
    dbus_message_iter_open_container(
        &entry, DBUS_TYPE_VARIANT, "s", &variant);
    dbus_message_iter_append_basic(
        &variant, DBUS_TYPE_STRING, &value);
    dbus_message_iter_close_container(&entry, &variant);
    dbus_message_iter_close_container(opts_iter, &entry);
}

// Append a boolean option to the options dict.
static void portal_append_bool_option(
    DBusMessageIter* opts_iter,
    const char* key,
    int value
) {
    DBusMessageIter entry, variant;
    dbus_message_iter_open_container(
        opts_iter, DBUS_TYPE_DICT_ENTRY, NULL, &entry);
    dbus_message_iter_append_basic(
        &entry, DBUS_TYPE_STRING, &key);
    dbus_message_iter_open_container(
        &entry, DBUS_TYPE_VARIANT, "b", &variant);
    dbus_bool_t bval = value ? TRUE : FALSE;
    dbus_message_iter_append_basic(
        &variant, DBUS_TYPE_BOOLEAN, &bval);
    dbus_message_iter_close_container(&entry, &variant);
    dbus_message_iter_close_container(opts_iter, &entry);
}

GuiNativeDialogResultEx gui_portal_open_file(
    const char* title,
    const char* start_dir,
    const char* extensions_csv,
    int allow_multiple
) {
    (void)start_dir; // portal doesn't support start_dir well

    DBusConnection* bus = portal_get_bus();
    if (bus == NULL) {
        return portal_result_error("no session bus");
    }

    char token[64];
    portal_handle_token(token, sizeof(token));

    char handle_path[256];
    portal_build_handle_path(bus, token,
        handle_path, sizeof(handle_path));

    DBusMessage* msg = dbus_message_new_method_call(
        PORTAL_BUS, PORTAL_PATH, PORTAL_FC, "OpenFile");
    if (msg == NULL) {
        return portal_result_error("failed to create message");
    }

    DBusMessageIter args, opts;
    dbus_message_iter_init_append(msg, &args);

    // parent_window: empty string (no window handle)
    const char* parent = "";
    dbus_message_iter_append_basic(
        &args, DBUS_TYPE_STRING, &parent);

    // title
    const char* t = (title && title[0]) ? title : "Open";
    dbus_message_iter_append_basic(
        &args, DBUS_TYPE_STRING, &t);

    // options: a{sv}
    dbus_message_iter_open_container(
        &args, DBUS_TYPE_ARRAY, "{sv}", &opts);

    portal_append_string_option(&opts, "handle_token", token);
    portal_append_bool_option(&opts, "multiple",
        allow_multiple);
    portal_append_filters(&opts, extensions_csv);

    dbus_message_iter_close_container(&args, &opts);

    DBusError err;
    dbus_error_init(&err);
    DBusMessage* reply = dbus_connection_send_with_reply_and_block(
        bus, msg, 5000, &err);
    dbus_message_unref(msg);

    if (dbus_error_is_set(&err)) {
        char errbuf[256];
        snprintf(errbuf, sizeof(errbuf),
            "portal call failed: %s", err.message);
        dbus_error_free(&err);
        return portal_result_error(errbuf);
    }
    if (reply != NULL) {
        dbus_message_unref(reply);
    }

    return portal_wait_response(bus, PORTAL_BUS, handle_path);
}

GuiNativeDialogResultEx gui_portal_save_file(
    const char* title,
    const char* start_dir,
    const char* default_name,
    const char* default_extension,
    const char* extensions_csv
) {
    (void)start_dir;

    DBusConnection* bus = portal_get_bus();
    if (bus == NULL) {
        return portal_result_error("no session bus");
    }

    char token[64];
    portal_handle_token(token, sizeof(token));

    char handle_path[256];
    portal_build_handle_path(bus, token,
        handle_path, sizeof(handle_path));

    DBusMessage* msg = dbus_message_new_method_call(
        PORTAL_BUS, PORTAL_PATH, PORTAL_FC, "SaveFile");
    if (msg == NULL) {
        return portal_result_error("failed to create message");
    }

    DBusMessageIter args, opts;
    dbus_message_iter_init_append(msg, &args);

    const char* parent = "";
    dbus_message_iter_append_basic(
        &args, DBUS_TYPE_STRING, &parent);

    const char* t = (title && title[0]) ? title : "Save";
    dbus_message_iter_append_basic(
        &args, DBUS_TYPE_STRING, &t);

    dbus_message_iter_open_container(
        &args, DBUS_TYPE_ARRAY, "{sv}", &opts);

    portal_append_string_option(&opts, "handle_token", token);
    if (default_name && default_name[0]) {
        portal_append_string_option(
            &opts, "current_name", default_name);
    }
    // Portal doesn't have a direct "default_extension" option
    // but we pass filters which effectively constrain it
    (void)default_extension;
    portal_append_filters(&opts, extensions_csv);

    dbus_message_iter_close_container(&args, &opts);

    DBusError err;
    dbus_error_init(&err);
    DBusMessage* reply = dbus_connection_send_with_reply_and_block(
        bus, msg, 5000, &err);
    dbus_message_unref(msg);

    if (dbus_error_is_set(&err)) {
        char errbuf[256];
        snprintf(errbuf, sizeof(errbuf),
            "portal call failed: %s", err.message);
        dbus_error_free(&err);
        return portal_result_error(errbuf);
    }
    if (reply != NULL) {
        dbus_message_unref(reply);
    }

    return portal_wait_response(bus, PORTAL_BUS, handle_path);
}

GuiNativeDialogResultEx gui_portal_open_directory(
    const char* title,
    const char* start_dir
) {
    (void)start_dir;

    DBusConnection* bus = portal_get_bus();
    if (bus == NULL) {
        return portal_result_error("no session bus");
    }

    char token[64];
    portal_handle_token(token, sizeof(token));

    char handle_path[256];
    portal_build_handle_path(bus, token,
        handle_path, sizeof(handle_path));

    DBusMessage* msg = dbus_message_new_method_call(
        PORTAL_BUS, PORTAL_PATH, PORTAL_FC, "OpenFile");
    if (msg == NULL) {
        return portal_result_error("failed to create message");
    }

    DBusMessageIter args, opts;
    dbus_message_iter_init_append(msg, &args);

    const char* parent = "";
    dbus_message_iter_append_basic(
        &args, DBUS_TYPE_STRING, &parent);

    const char* t = (title && title[0])
        ? title : "Choose Folder";
    dbus_message_iter_append_basic(
        &args, DBUS_TYPE_STRING, &t);

    dbus_message_iter_open_container(
        &args, DBUS_TYPE_ARRAY, "{sv}", &opts);

    portal_append_string_option(&opts, "handle_token", token);
    portal_append_bool_option(&opts, "directory", 1);

    dbus_message_iter_close_container(&args, &opts);

    DBusError err;
    dbus_error_init(&err);
    DBusMessage* reply = dbus_connection_send_with_reply_and_block(
        bus, msg, 5000, &err);
    dbus_message_unref(msg);

    if (dbus_error_is_set(&err)) {
        char errbuf[256];
        snprintf(errbuf, sizeof(errbuf),
            "portal call failed: %s", err.message);
        dbus_error_free(&err);
        return portal_result_error(errbuf);
    }
    if (reply != NULL) {
        dbus_message_unref(reply);
    }

    return portal_wait_response(bus, PORTAL_BUS, handle_path);
}
