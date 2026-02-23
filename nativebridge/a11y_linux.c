// a11y_linux.c — AT-SPI2 D-Bus accessibility backend for Linux.
// Implements the same four C functions as a11y_macos.m using
// libdbus-1 to speak the AT-SPI2 protocol directly (no ATK/GLib).

#include <dbus/dbus.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "a11y_bridge.h"

// AT-SPI2 D-Bus constants
#define ATSPI_BUS_NAME      "org.a11y.Bus"
#define ATSPI_BUS_PATH      "/org/a11y/bus"
#define ATSPI_BUS_IFACE     "org.a11y.Bus"
#define ATSPI_REG_PATH      "/org/a11y/atspi/registry"
#define ATSPI_REG_IFACE     "org.a11y.atspi.Registry"
#define ATSPI_ACCESSIBLE    "org.a11y.atspi.Accessible"
#define ATSPI_APPLICATION   "org.a11y.atspi.Application"
#define ATSPI_COMPONENT     "org.a11y.atspi.Component"
#define ATSPI_ACTION        "org.a11y.atspi.Action"
#define ATSPI_VALUE         "org.a11y.atspi.Value"
#define DBUS_PROPERTIES     "org.freedesktop.DBus.Properties"

#define ROOT_PATH    "/org/a11y/atspi/accessible/root"
#define NODE_PREFIX  "/org/a11y/atspi/accessible/"

// AccessState bitmask constants (match a11y.v)
enum {
    A11Y_STATE_EXPANDED  = 1,
    A11Y_STATE_SELECTED  = 2,
    A11Y_STATE_CHECKED   = 4,
    A11Y_STATE_REQUIRED  = 8,
    A11Y_STATE_INVALID   = 16,
    A11Y_STATE_BUSY      = 32,
    A11Y_STATE_READ_ONLY = 64,
    A11Y_STATE_MODAL     = 128
};

// AT-SPI2 role constants
enum {
    ATSPI_ROLE_CHECK_BOX     =  7,
    ATSPI_ROLE_COLOR_CHOOSER =  9,
    ATSPI_ROLE_COMBO_BOX     = 11,
    ATSPI_ROLE_DATE_EDITOR   = 12,
    ATSPI_ROLE_DIALOG        = 16,
    ATSPI_ROLE_IMAGE         = 27,
    ATSPI_ROLE_LIST          = 31,
    ATSPI_ROLE_LIST_ITEM     = 32,
    ATSPI_ROLE_MENU          = 33,
    ATSPI_ROLE_MENU_BAR      = 34,
    ATSPI_ROLE_MENU_ITEM     = 35,
    ATSPI_ROLE_PAGE_TAB      = 37,
    ATSPI_ROLE_PAGE_TAB_LIST = 38,
    ATSPI_ROLE_PANEL         = 39,
    ATSPI_ROLE_PROGRESS_BAR  = 42,
    ATSPI_ROLE_PUSH_BUTTON   = 43,
    ATSPI_ROLE_RADIO_BUTTON  = 44,
    ATSPI_ROLE_SCROLL_BAR    = 48,
    ATSPI_ROLE_SCROLL_PANE   = 49,
    ATSPI_ROLE_SLIDER        = 51,
    ATSPI_ROLE_SPLIT_PANE    = 53,
    ATSPI_ROLE_TABLE         = 55,
    ATSPI_ROLE_TABLE_CELL    = 56,
    ATSPI_ROLE_TEXT          = 61,
    ATSPI_ROLE_TOGGLE_BUTTON = 62,
    ATSPI_ROLE_TOOL_BAR      = 63,
    ATSPI_ROLE_TREE          = 65,
    ATSPI_ROLE_ENTRY         = 79,
    ATSPI_ROLE_HEADING       = 83,
    ATSPI_ROLE_LINK          = 88,
    ATSPI_ROLE_TREE_ITEM     = 91,
    ATSPI_ROLE_STATIC        = 116,
    ATSPI_ROLE_APPLICATION   = 75,
    ATSPI_ROLE_FRAME         = 22
};

// AT-SPI2 state bit positions (two 32-bit words)
// Low word (index 0)
enum {
    ATSPI_STATE_ACTIVE     =  1,
    ATSPI_STATE_BUSY       =  3,
    ATSPI_STATE_CHECKED    =  4,
    ATSPI_STATE_EDITABLE   =  7,
    ATSPI_STATE_ENABLED    =  8,
    ATSPI_STATE_EXPANDED   = 10,
    ATSPI_STATE_FOCUSABLE  = 11,
    ATSPI_STATE_FOCUSED    = 12,
    ATSPI_STATE_MODAL      = 16,
    ATSPI_STATE_SENSITIVE  = 21,
    ATSPI_STATE_SELECTED   = 23,
    ATSPI_STATE_SHOWING    = 24,
    ATSPI_STATE_VISIBLE    = 29
};
// High word (index 1)
enum {
    ATSPI_STATE_HI_REQUIRED      = 1,
    ATSPI_STATE_HI_INVALID_ENTRY = 4,
    ATSPI_STATE_HI_READ_ONLY     = 11
};

// -------------------------------------------------------
// Module-level state
// -------------------------------------------------------

static DBusConnection *g_a11y_bus    = NULL;
static GuiA11yActionFn g_action_fn   = NULL;
static void           *g_user_data   = NULL;
static GuiA11yNode    *g_nodes       = NULL;
static int             g_node_count  = 0;
static int             g_focused_idx = -1;
static int             g_prev_focused_id = -1;
static char           *g_bus_name    = NULL;

// -------------------------------------------------------
// Role mapping: AccessRole ordinal → AT-SPI2 role int
// -------------------------------------------------------

static int gui_a11y_map_role(int role) {
    switch (role) {
        case  0: return ATSPI_ROLE_PANEL;          // none
        case  1: return ATSPI_ROLE_PUSH_BUTTON;    // button
        case  2: return ATSPI_ROLE_CHECK_BOX;      // checkbox
        case  3: return ATSPI_ROLE_COLOR_CHOOSER;  // color_well
        case  4: return ATSPI_ROLE_COMBO_BOX;      // combo_box
        case  5: return ATSPI_ROLE_DATE_EDITOR;    // date_field
        case  6: return ATSPI_ROLE_DIALOG;         // dialog
        case  7: return ATSPI_ROLE_TOGGLE_BUTTON;  // disclosure
        case  8: return ATSPI_ROLE_TABLE;          // grid
        case  9: return ATSPI_ROLE_TABLE_CELL;     // grid_cell
        case 10: return ATSPI_ROLE_PANEL;          // group
        case 11: return ATSPI_ROLE_HEADING;        // heading
        case 12: return ATSPI_ROLE_IMAGE;          // image
        case 13: return ATSPI_ROLE_LINK;           // link
        case 14: return ATSPI_ROLE_LIST;           // list
        case 15: return ATSPI_ROLE_LIST_ITEM;      // list_item
        case 16: return ATSPI_ROLE_MENU;           // menu
        case 17: return ATSPI_ROLE_MENU_BAR;       // menu_bar
        case 18: return ATSPI_ROLE_MENU_ITEM;      // menu_item
        case 19: return ATSPI_ROLE_PROGRESS_BAR;   // progress_bar
        case 20: return ATSPI_ROLE_RADIO_BUTTON;   // radio_button
        case 21: return ATSPI_ROLE_PANEL;          // radio_group
        case 22: return ATSPI_ROLE_SCROLL_PANE;    // scroll_area
        case 23: return ATSPI_ROLE_SCROLL_BAR;     // scroll_bar
        case 24: return ATSPI_ROLE_SLIDER;         // slider
        case 25: return ATSPI_ROLE_SPLIT_PANE;     // splitter
        case 26: return ATSPI_ROLE_STATIC;         // static_text
        case 27: return ATSPI_ROLE_TOGGLE_BUTTON;  // switch_toggle
        case 28: return ATSPI_ROLE_PAGE_TAB_LIST;  // tab
        case 29: return ATSPI_ROLE_PAGE_TAB;       // tab_item
        case 30: return ATSPI_ROLE_TEXT;           // text_area
        case 31: return ATSPI_ROLE_ENTRY;          // text_field
        case 32: return ATSPI_ROLE_TOOL_BAR;       // toolbar
        case 33: return ATSPI_ROLE_TREE;           // tree
        case 34: return ATSPI_ROLE_TREE_ITEM;      // tree_item
        default: return ATSPI_ROLE_PANEL;
    }
}

// -------------------------------------------------------
// State mapping: gui state → AT-SPI2 state pair
// -------------------------------------------------------

static void gui_a11y_build_state(const GuiA11yNode *n,
        int is_focused, dbus_uint32_t out[2]) {
    // Low word: always VISIBLE, SHOWING, ENABLED, SENSITIVE
    dbus_uint32_t lo = (1u << ATSPI_STATE_VISIBLE)
                     | (1u << ATSPI_STATE_SHOWING)
                     | (1u << ATSPI_STATE_ENABLED)
                     | (1u << ATSPI_STATE_SENSITIVE);
    dbus_uint32_t hi = 0;

    if (n->focus_id > 0) {
        lo |= (1u << ATSPI_STATE_FOCUSABLE);
    }
    if (is_focused) {
        lo |= (1u << ATSPI_STATE_FOCUSED);
    }

    int st = n->state;
    if (st & A11Y_STATE_EXPANDED)  lo |= (1u << ATSPI_STATE_EXPANDED);
    if (st & A11Y_STATE_SELECTED)  lo |= (1u << ATSPI_STATE_SELECTED);
    if (st & A11Y_STATE_CHECKED)   lo |= (1u << ATSPI_STATE_CHECKED);
    if (st & A11Y_STATE_BUSY)      lo |= (1u << ATSPI_STATE_BUSY);
    if (st & A11Y_STATE_MODAL)     lo |= (1u << ATSPI_STATE_MODAL);
    if (st & A11Y_STATE_REQUIRED)  hi |= (1u << ATSPI_STATE_HI_REQUIRED);
    if (st & A11Y_STATE_INVALID)   hi |= (1u << ATSPI_STATE_HI_INVALID_ENTRY);
    if (st & A11Y_STATE_READ_ONLY) hi |= (1u << ATSPI_STATE_HI_READ_ONLY);

    // EDITABLE for text roles when not read_only
    int role = n->role;
    if ((role == 30 || role == 31) && !(st & A11Y_STATE_READ_ONLY)) {
        lo |= (1u << ATSPI_STATE_EDITABLE);
    }

    out[0] = lo;
    out[1] = hi;
}

// -------------------------------------------------------
// Helpers: object path from node index
// -------------------------------------------------------

// Return static path for root, or write into buf for nodes.
static const char* node_path(int idx, char *buf, size_t bufsz) {
    if (idx < 0) return ROOT_PATH;
    snprintf(buf, bufsz, NODE_PREFIX "%d", idx);
    return buf;
}

// -------------------------------------------------------
// Helpers: count children of a parent index
// -------------------------------------------------------

static int count_children(int parent_idx) {
    int count = 0;
    for (int i = 0; i < g_node_count; i++) {
        if (g_nodes[i].parent_idx == parent_idx) {
            count++;
        }
    }
    return count;
}

// Get nth child of parent_idx. Returns -1 if not found.
static int get_child_at(int parent_idx, int child_index) {
    int count = 0;
    for (int i = 0; i < g_node_count; i++) {
        if (g_nodes[i].parent_idx == parent_idx) {
            if (count == child_index) return i;
            count++;
        }
    }
    return -1;
}

// Get index-in-parent for node at idx.
static int get_index_in_parent(int idx) {
    if (idx < 0 || idx >= g_node_count) return -1;
    int pi = g_nodes[idx].parent_idx;
    int count = 0;
    for (int i = 0; i < g_node_count; i++) {
        if (g_nodes[i].parent_idx == pi) {
            if (i == idx) return count;
            count++;
        }
    }
    return -1;
}

// -------------------------------------------------------
// Helpers: D-Bus reply builders
// -------------------------------------------------------

static void reply_string(DBusMessage *msg,
        DBusConnection *bus, const char *s) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    const char *val = s ? s : "";
    dbus_message_append_args(reply,
        DBUS_TYPE_STRING, &val, DBUS_TYPE_INVALID);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

static void reply_int32(DBusMessage *msg,
        DBusConnection *bus, dbus_int32_t v) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    dbus_message_append_args(reply,
        DBUS_TYPE_INT32, &v, DBUS_TYPE_INVALID);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

static void reply_uint32(DBusMessage *msg,
        DBusConnection *bus, dbus_uint32_t v) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    dbus_message_append_args(reply,
        DBUS_TYPE_UINT32, &v, DBUS_TYPE_INVALID);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

static void reply_bool(DBusMessage *msg,
        DBusConnection *bus, dbus_bool_t v) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    dbus_message_append_args(reply,
        DBUS_TYPE_BOOLEAN, &v, DBUS_TYPE_INVALID);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

static void reply_double(DBusMessage *msg,
        DBusConnection *bus, double v) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    dbus_message_append_args(reply,
        DBUS_TYPE_DOUBLE, &v, DBUS_TYPE_INVALID);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

// Reply with an AT-SPI2 object reference (bus_name, path).
static void reply_ref(DBusMessage *msg,
        DBusConnection *bus,
        const char *name, const char *path) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    DBusMessageIter iter, st;
    dbus_message_iter_init_append(reply, &iter);
    dbus_message_iter_open_container(&iter,
        DBUS_TYPE_STRUCT, NULL, &st);
    dbus_message_iter_append_basic(&st, DBUS_TYPE_STRING, &name);
    dbus_message_iter_append_basic(&st, DBUS_TYPE_OBJECT_PATH, &path);
    dbus_message_iter_close_container(&iter, &st);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

// Reply with state as au (array of uint32, 2 elements).
static void reply_state(DBusMessage *msg,
        DBusConnection *bus, dbus_uint32_t state[2]) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    DBusMessageIter iter, arr;
    dbus_message_iter_init_append(reply, &iter);
    dbus_message_iter_open_container(&iter,
        DBUS_TYPE_ARRAY, DBUS_TYPE_UINT32_AS_STRING, &arr);
    dbus_message_iter_append_basic(&arr,
        DBUS_TYPE_UINT32, &state[0]);
    dbus_message_iter_append_basic(&arr,
        DBUS_TYPE_UINT32, &state[1]);
    dbus_message_iter_close_container(&iter, &arr);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

// Reply with a D-Bus Properties.Get variant wrapping a string.
static void reply_variant_string(DBusMessage *msg,
        DBusConnection *bus, const char *s) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    DBusMessageIter iter, var;
    const char *val = s ? s : "";
    dbus_message_iter_init_append(reply, &iter);
    dbus_message_iter_open_container(&iter,
        DBUS_TYPE_VARIANT, DBUS_TYPE_STRING_AS_STRING, &var);
    dbus_message_iter_append_basic(&var, DBUS_TYPE_STRING, &val);
    dbus_message_iter_close_container(&iter, &var);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

static void reply_variant_int32(DBusMessage *msg,
        DBusConnection *bus, dbus_int32_t v) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    DBusMessageIter iter, var;
    dbus_message_iter_init_append(reply, &iter);
    dbus_message_iter_open_container(&iter,
        DBUS_TYPE_VARIANT, DBUS_TYPE_INT32_AS_STRING, &var);
    dbus_message_iter_append_basic(&var, DBUS_TYPE_INT32, &v);
    dbus_message_iter_close_container(&iter, &var);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

static void reply_variant_uint32(DBusMessage *msg,
        DBusConnection *bus, dbus_uint32_t v) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    DBusMessageIter iter, var;
    dbus_message_iter_init_append(reply, &iter);
    dbus_message_iter_open_container(&iter,
        DBUS_TYPE_VARIANT, DBUS_TYPE_UINT32_AS_STRING, &var);
    dbus_message_iter_append_basic(&var, DBUS_TYPE_UINT32, &v);
    dbus_message_iter_close_container(&iter, &var);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

static void reply_variant_double(DBusMessage *msg,
        DBusConnection *bus, double v) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    DBusMessageIter iter, var;
    dbus_message_iter_init_append(reply, &iter);
    dbus_message_iter_open_container(&iter,
        DBUS_TYPE_VARIANT, DBUS_TYPE_DOUBLE_AS_STRING, &var);
    dbus_message_iter_append_basic(&var, DBUS_TYPE_DOUBLE, &v);
    dbus_message_iter_close_container(&iter, &var);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

// Reply with a variant wrapping an (so) struct (object ref).
static void reply_variant_ref(DBusMessage *msg,
        DBusConnection *bus,
        const char *name, const char *path) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    DBusMessageIter iter, var, st;
    dbus_message_iter_init_append(reply, &iter);
    dbus_message_iter_open_container(&iter,
        DBUS_TYPE_VARIANT, "(so)", &var);
    dbus_message_iter_open_container(&var,
        DBUS_TYPE_STRUCT, NULL, &st);
    dbus_message_iter_append_basic(&st, DBUS_TYPE_STRING, &name);
    dbus_message_iter_append_basic(&st,
        DBUS_TYPE_OBJECT_PATH, &path);
    dbus_message_iter_close_container(&var, &st);
    dbus_message_iter_close_container(&iter, &var);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

// Reply with a variant wrapping state (au).
static void reply_variant_state(DBusMessage *msg,
        DBusConnection *bus, dbus_uint32_t state[2]) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return;
    DBusMessageIter iter, var, arr;
    dbus_message_iter_init_append(reply, &iter);
    dbus_message_iter_open_container(&iter,
        DBUS_TYPE_VARIANT, "au", &var);
    dbus_message_iter_open_container(&var,
        DBUS_TYPE_ARRAY, DBUS_TYPE_UINT32_AS_STRING, &arr);
    dbus_message_iter_append_basic(&arr,
        DBUS_TYPE_UINT32, &state[0]);
    dbus_message_iter_append_basic(&arr,
        DBUS_TYPE_UINT32, &state[1]);
    dbus_message_iter_close_container(&var, &arr);
    dbus_message_iter_close_container(&iter, &var);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
}

// -------------------------------------------------------
// Parse node index from object path
// -------------------------------------------------------

// Returns -1 for root, -2 for unknown, >= 0 for node index.
static int parse_node_index(const char *path) {
    if (!path) return -2;
    if (strcmp(path, ROOT_PATH) == 0) return -1;
    size_t pfx_len = strlen(NODE_PREFIX);
    if (strncmp(path, NODE_PREFIX, pfx_len) != 0) return -2;
    const char *suffix = path + pfx_len;
    if (*suffix == '\0') return -2;
    char *end = NULL;
    long idx = strtol(suffix, &end, 10);
    if (end == suffix || *end != '\0') return -2;
    if (idx < 0 || idx >= g_node_count) return -2;
    return (int)idx;
}

// -------------------------------------------------------
// Emit AT-SPI2 signal
// -------------------------------------------------------

static void emit_signal(const char *path, const char *iface,
        const char *name, const char *detail,
        int idx1, int idx2,
        const char *ref_name, const char *ref_path) {
    if (!g_a11y_bus || !g_bus_name) return;
    DBusMessage *sig = dbus_message_new_signal(path, iface, name);
    if (!sig) return;
    if (detail) {
        dbus_message_set_member(sig, name);
        // AT-SPI2 signals carry detail as part of the path
    }
    DBusMessageIter iter;
    dbus_message_iter_init_append(sig, &iter);

    // Most AT-SPI2 signals: detail string, int, int, variant
    if (detail) {
        dbus_message_iter_append_basic(&iter,
            DBUS_TYPE_STRING, &detail);
    }
    dbus_int32_t i1 = idx1, i2 = idx2;
    dbus_message_iter_append_basic(&iter, DBUS_TYPE_INT32, &i1);
    dbus_message_iter_append_basic(&iter, DBUS_TYPE_INT32, &i2);

    // Variant: object ref or empty string
    DBusMessageIter var;
    if (ref_name && ref_path) {
        dbus_message_iter_open_container(&iter,
            DBUS_TYPE_VARIANT, "(so)", &var);
        DBusMessageIter st;
        dbus_message_iter_open_container(&var,
            DBUS_TYPE_STRUCT, NULL, &st);
        dbus_message_iter_append_basic(&st,
            DBUS_TYPE_STRING, &ref_name);
        dbus_message_iter_append_basic(&st,
            DBUS_TYPE_OBJECT_PATH, &ref_path);
        dbus_message_iter_close_container(&var, &st);
        dbus_message_iter_close_container(&iter, &var);
    } else {
        const char *empty = "";
        dbus_message_iter_open_container(&iter,
            DBUS_TYPE_VARIANT, DBUS_TYPE_STRING_AS_STRING, &var);
        dbus_message_iter_append_basic(&var,
            DBUS_TYPE_STRING, &empty);
        dbus_message_iter_close_container(&iter, &var);
    }

    dbus_connection_send(g_a11y_bus, sig, NULL);
    dbus_message_unref(sig);
}

// -------------------------------------------------------
// Handle Accessible interface
// -------------------------------------------------------

static DBusHandlerResult handle_accessible(DBusMessage *msg,
        DBusConnection *bus, int idx, const char *member) {
    if (strcmp(member, "GetChildAtIndex") == 0) {
        dbus_int32_t child_idx = 0;
        if (!dbus_message_get_args(msg, NULL,
                DBUS_TYPE_INT32, &child_idx, DBUS_TYPE_INVALID))
            return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
        int ci = get_child_at(idx, child_idx);
        char buf[128];
        if (ci >= 0) {
            reply_ref(msg, bus, g_bus_name, node_path(ci, buf, sizeof(buf)));
        } else {
            reply_ref(msg, bus, g_bus_name, ROOT_PATH);
        }
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetChildren") == 0) {
        DBusMessage *reply = dbus_message_new_method_return(msg);
        if (!reply) return DBUS_HANDLER_RESULT_HANDLED;
        DBusMessageIter iter, arr;
        dbus_message_iter_init_append(reply, &iter);
        dbus_message_iter_open_container(&iter,
            DBUS_TYPE_ARRAY, "(so)", &arr);
        char buf[128];
        for (int i = 0; i < g_node_count; i++) {
            if (g_nodes[i].parent_idx == idx) {
                DBusMessageIter st;
                dbus_message_iter_open_container(&arr,
                    DBUS_TYPE_STRUCT, NULL, &st);
                const char *p = node_path(i, buf, sizeof(buf));
                dbus_message_iter_append_basic(&st,
                    DBUS_TYPE_STRING, &g_bus_name);
                dbus_message_iter_append_basic(&st,
                    DBUS_TYPE_OBJECT_PATH, &p);
                dbus_message_iter_close_container(&arr, &st);
            }
        }
        dbus_message_iter_close_container(&iter, &arr);
        dbus_connection_send(bus, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetIndexInParent") == 0) {
        reply_int32(msg, bus, get_index_in_parent(idx));
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetState") == 0) {
        dbus_uint32_t state[2] = {0, 0};
        if (idx >= 0 && idx < g_node_count) {
            gui_a11y_build_state(&g_nodes[idx],
                idx == g_focused_idx, state);
        } else {
            // Root: ACTIVE, VISIBLE, SHOWING, ENABLED
            state[0] = (1u << ATSPI_STATE_ACTIVE)
                     | (1u << ATSPI_STATE_VISIBLE)
                     | (1u << ATSPI_STATE_SHOWING)
                     | (1u << ATSPI_STATE_ENABLED);
        }
        reply_state(msg, bus, state);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetRole") == 0) {
        dbus_uint32_t role;
        if (idx >= 0 && idx < g_node_count) {
            role = (dbus_uint32_t)gui_a11y_map_role(
                g_nodes[idx].role);
        } else {
            role = ATSPI_ROLE_APPLICATION;
        }
        reply_uint32(msg, bus, role);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetRoleName") == 0) {
        // Simplified role name; screen readers mostly use
        // the numeric role.
        reply_string(msg, bus, "widget");
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetLocalizedRoleName") == 0) {
        reply_string(msg, bus, "widget");
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetApplication") == 0) {
        reply_ref(msg, bus, g_bus_name, ROOT_PATH);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetInterfaces") == 0) {
        DBusMessage *reply = dbus_message_new_method_return(msg);
        if (!reply) return DBUS_HANDLER_RESULT_HANDLED;
        DBusMessageIter iter, arr;
        dbus_message_iter_init_append(reply, &iter);
        dbus_message_iter_open_container(&iter,
            DBUS_TYPE_ARRAY, DBUS_TYPE_STRING_AS_STRING, &arr);
        const char *ifaces[] = {
            ATSPI_ACCESSIBLE, ATSPI_COMPONENT,
            ATSPI_ACTION, ATSPI_VALUE
        };
        for (int i = 0; i < 4; i++) {
            dbus_message_iter_append_basic(&arr,
                DBUS_TYPE_STRING, &ifaces[i]);
        }
        // Root also implements Application
        if (idx < 0) {
            const char *app = ATSPI_APPLICATION;
            dbus_message_iter_append_basic(&arr,
                DBUS_TYPE_STRING, &app);
        }
        dbus_message_iter_close_container(&iter, &arr);
        dbus_connection_send(bus, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

// -------------------------------------------------------
// Handle Component interface
// -------------------------------------------------------

static DBusHandlerResult handle_component(DBusMessage *msg,
        DBusConnection *bus, int idx, const char *member) {
    if (idx < 0 || idx >= g_node_count)
        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

    const GuiA11yNode *n = &g_nodes[idx];

    if (strcmp(member, "GetExtents") == 0) {
        // coord_type argument ignored; return window-relative
        DBusMessage *reply = dbus_message_new_method_return(msg);
        if (!reply) return DBUS_HANDLER_RESULT_HANDLED;
        DBusMessageIter iter, st;
        dbus_message_iter_init_append(reply, &iter);
        dbus_message_iter_open_container(&iter,
            DBUS_TYPE_STRUCT, NULL, &st);
        dbus_int32_t x = (dbus_int32_t)n->x;
        dbus_int32_t y = (dbus_int32_t)n->y;
        dbus_int32_t w = (dbus_int32_t)n->w;
        dbus_int32_t h = (dbus_int32_t)n->h;
        dbus_message_iter_append_basic(&st, DBUS_TYPE_INT32, &x);
        dbus_message_iter_append_basic(&st, DBUS_TYPE_INT32, &y);
        dbus_message_iter_append_basic(&st, DBUS_TYPE_INT32, &w);
        dbus_message_iter_append_basic(&st, DBUS_TYPE_INT32, &h);
        dbus_message_iter_close_container(&iter, &st);
        dbus_connection_send(bus, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetPosition") == 0) {
        DBusMessage *reply = dbus_message_new_method_return(msg);
        if (!reply) return DBUS_HANDLER_RESULT_HANDLED;
        dbus_int32_t x = (dbus_int32_t)n->x;
        dbus_int32_t y = (dbus_int32_t)n->y;
        dbus_message_append_args(reply,
            DBUS_TYPE_INT32, &x,
            DBUS_TYPE_INT32, &y, DBUS_TYPE_INVALID);
        dbus_connection_send(bus, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetSize") == 0) {
        DBusMessage *reply = dbus_message_new_method_return(msg);
        if (!reply) return DBUS_HANDLER_RESULT_HANDLED;
        dbus_int32_t w = (dbus_int32_t)n->w;
        dbus_int32_t h = (dbus_int32_t)n->h;
        dbus_message_append_args(reply,
            DBUS_TYPE_INT32, &w,
            DBUS_TYPE_INT32, &h, DBUS_TYPE_INVALID);
        dbus_connection_send(bus, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "Contains") == 0) {
        dbus_int32_t cx = 0, cy = 0;
        dbus_uint32_t coord_type = 0;
        if (!dbus_message_get_args(msg, NULL,
                DBUS_TYPE_INT32, &cx, DBUS_TYPE_INT32, &cy,
                DBUS_TYPE_UINT32, &coord_type,
                DBUS_TYPE_INVALID))
            return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
        dbus_bool_t inside =
            (cx >= (dbus_int32_t)n->x &&
             cx < (dbus_int32_t)(n->x + n->w) &&
             cy >= (dbus_int32_t)n->y &&
             cy < (dbus_int32_t)(n->y + n->h));
        reply_bool(msg, bus, inside);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetLayer") == 0) {
        // LAYER_WIDGET = 3
        reply_uint32(msg, bus, 3);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetMDIZOrder") == 0) {
        reply_int32(msg, bus, 0);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

// -------------------------------------------------------
// Handle Action interface
// -------------------------------------------------------

static DBusHandlerResult handle_action(DBusMessage *msg,
        DBusConnection *bus, int idx, const char *member) {
    if (idx < 0 || idx >= g_node_count)
        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

    const GuiA11yNode *n = &g_nodes[idx];

    if (strcmp(member, "GetNActions") == 0) {
        dbus_int32_t count = 0;
        if (n->focus_id > 0) {
            int role = n->role;
            count = 1; // press
            if (role == 24 || role == 19) {
                // slider / progress_bar: +increment, +decrement
                count = 3;
            }
        }
        reply_int32(msg, bus, count);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "DoAction") == 0) {
        dbus_int32_t action_idx = 0;
        if (!dbus_message_get_args(msg, NULL,
                DBUS_TYPE_INT32, &action_idx,
                DBUS_TYPE_INVALID))
            return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
        if (g_action_fn && n->focus_id > 0) {
            int action;
            switch (action_idx) {
                case 0: action = GUI_A11Y_ACTION_PRESS; break;
                case 1: action = GUI_A11Y_ACTION_INCREMENT; break;
                case 2: action = GUI_A11Y_ACTION_DECREMENT; break;
                default: action = GUI_A11Y_ACTION_PRESS; break;
            }
            g_action_fn(action, n->focus_id, g_user_data);
            reply_bool(msg, bus, TRUE);
        } else {
            reply_bool(msg, bus, FALSE);
        }
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetDescription") == 0 ||
            strcmp(member, "GetName") == 0) {
        dbus_int32_t action_idx = 0;
        dbus_message_get_args(msg, NULL,
            DBUS_TYPE_INT32, &action_idx, DBUS_TYPE_INVALID);
        const char *name;
        switch (action_idx) {
            case 0: name = "press"; break;
            case 1: name = "increment"; break;
            case 2: name = "decrement"; break;
            default: name = ""; break;
        }
        reply_string(msg, bus, name);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetKeyBinding") == 0) {
        reply_string(msg, bus, "");
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetActions") == 0) {
        // Return array of action descriptions
        DBusMessage *reply = dbus_message_new_method_return(msg);
        if (!reply) return DBUS_HANDLER_RESULT_HANDLED;
        DBusMessageIter iter, arr;
        dbus_message_iter_init_append(reply, &iter);
        // a(sss) — array of (name, description, keybinding)
        dbus_message_iter_open_container(&iter,
            DBUS_TYPE_ARRAY, "(sss)", &arr);
        if (n->focus_id > 0) {
            const char *actions[][3] = {
                {"press", "Press", ""},
                {"increment", "Increment", ""},
                {"decrement", "Decrement", ""}
            };
            int nactions = 1;
            if (n->role == 24 || n->role == 19) nactions = 3;
            for (int i = 0; i < nactions; i++) {
                DBusMessageIter st;
                dbus_message_iter_open_container(&arr,
                    DBUS_TYPE_STRUCT, NULL, &st);
                dbus_message_iter_append_basic(&st,
                    DBUS_TYPE_STRING, &actions[i][0]);
                dbus_message_iter_append_basic(&st,
                    DBUS_TYPE_STRING, &actions[i][1]);
                dbus_message_iter_append_basic(&st,
                    DBUS_TYPE_STRING, &actions[i][2]);
                dbus_message_iter_close_container(&arr, &st);
            }
        }
        dbus_message_iter_close_container(&iter, &arr);
        dbus_connection_send(bus, reply, NULL);
        dbus_message_unref(reply);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

// -------------------------------------------------------
// Handle Value interface
// -------------------------------------------------------

static DBusHandlerResult handle_value(DBusMessage *msg,
        DBusConnection *bus, int idx, const char *member) {
    if (idx < 0 || idx >= g_node_count)
        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

    const GuiA11yNode *n = &g_nodes[idx];

    // Value interface methods
    if (strcmp(member, "SetCurrentValue") == 0) {
        // Read-only for now
        reply_bool(msg, bus, FALSE);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetCurrentValue") == 0) {
        reply_double(msg, bus, (double)n->value_num);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetMinimumValue") == 0) {
        reply_double(msg, bus, (double)n->value_min);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetMaximumValue") == 0) {
        reply_double(msg, bus, (double)n->value_max);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    if (strcmp(member, "GetMinimumIncrement") == 0) {
        double range = (double)(n->value_max - n->value_min);
        double incr = range > 0.0 ? range / 100.0 : 0.0;
        reply_double(msg, bus, incr);
        return DBUS_HANDLER_RESULT_HANDLED;
    }
    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

// -------------------------------------------------------
// Handle Properties.Get
// -------------------------------------------------------

static DBusHandlerResult handle_properties_get(DBusMessage *msg,
        DBusConnection *bus, int idx) {
    const char *iface = NULL, *prop = NULL;
    if (!dbus_message_get_args(msg, NULL,
            DBUS_TYPE_STRING, &iface,
            DBUS_TYPE_STRING, &prop, DBUS_TYPE_INVALID))
        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

    // Accessible properties
    if (strcmp(iface, ATSPI_ACCESSIBLE) == 0) {
        if (strcmp(prop, "Name") == 0) {
            if (idx >= 0 && idx < g_node_count) {
                reply_variant_string(msg, bus,
                    g_nodes[idx].label);
            } else {
                reply_variant_string(msg, bus, "V GUI Application");
            }
            return DBUS_HANDLER_RESULT_HANDLED;
        }
        if (strcmp(prop, "Description") == 0) {
            if (idx >= 0 && idx < g_node_count) {
                reply_variant_string(msg, bus,
                    g_nodes[idx].description);
            } else {
                reply_variant_string(msg, bus, "");
            }
            return DBUS_HANDLER_RESULT_HANDLED;
        }
        if (strcmp(prop, "Parent") == 0) {
            char buf[128];
            if (idx >= 0 && idx < g_node_count) {
                int pi = g_nodes[idx].parent_idx;
                reply_variant_ref(msg, bus, g_bus_name,
                    node_path(pi, buf, sizeof(buf)));
            } else {
                // Root's parent: the desktop (registry)
                reply_variant_ref(msg, bus,
                    ATSPI_BUS_NAME, ATSPI_REG_PATH);
            }
            return DBUS_HANDLER_RESULT_HANDLED;
        }
        if (strcmp(prop, "ChildCount") == 0) {
            reply_variant_int32(msg, bus,
                count_children(idx));
            return DBUS_HANDLER_RESULT_HANDLED;
        }
        if (strcmp(prop, "Role") == 0) {
            dbus_uint32_t role;
            if (idx >= 0 && idx < g_node_count) {
                role = (dbus_uint32_t)gui_a11y_map_role(
                    g_nodes[idx].role);
            } else {
                role = ATSPI_ROLE_APPLICATION;
            }
            reply_variant_uint32(msg, bus, role);
            return DBUS_HANDLER_RESULT_HANDLED;
        }
        if (strcmp(prop, "State") == 0) {
            dbus_uint32_t state[2] = {0, 0};
            if (idx >= 0 && idx < g_node_count) {
                gui_a11y_build_state(&g_nodes[idx],
                    idx == g_focused_idx, state);
            } else {
                state[0] = (1u << ATSPI_STATE_ACTIVE)
                         | (1u << ATSPI_STATE_VISIBLE)
                         | (1u << ATSPI_STATE_SHOWING)
                         | (1u << ATSPI_STATE_ENABLED);
            }
            reply_variant_state(msg, bus, state);
            return DBUS_HANDLER_RESULT_HANDLED;
        }
        if (strcmp(prop, "Interfaces") == 0) {
            // Return as variant wrapping as (array of string)
            DBusMessage *reply =
                dbus_message_new_method_return(msg);
            if (!reply) return DBUS_HANDLER_RESULT_HANDLED;
            DBusMessageIter iter, var, arr;
            dbus_message_iter_init_append(reply, &iter);
            dbus_message_iter_open_container(&iter,
                DBUS_TYPE_VARIANT, "as", &var);
            dbus_message_iter_open_container(&var,
                DBUS_TYPE_ARRAY,
                DBUS_TYPE_STRING_AS_STRING, &arr);
            const char *ifaces[] = {
                ATSPI_ACCESSIBLE, ATSPI_COMPONENT,
                ATSPI_ACTION, ATSPI_VALUE
            };
            for (int i = 0; i < 4; i++) {
                dbus_message_iter_append_basic(&arr,
                    DBUS_TYPE_STRING, &ifaces[i]);
            }
            if (idx < 0) {
                const char *app = ATSPI_APPLICATION;
                dbus_message_iter_append_basic(&arr,
                    DBUS_TYPE_STRING, &app);
            }
            dbus_message_iter_close_container(&var, &arr);
            dbus_message_iter_close_container(&iter, &var);
            dbus_connection_send(bus, reply, NULL);
            dbus_message_unref(reply);
            return DBUS_HANDLER_RESULT_HANDLED;
        }
    }

    // Application properties (root only)
    if (strcmp(iface, ATSPI_APPLICATION) == 0 && idx < 0) {
        if (strcmp(prop, "ToolkitName") == 0) {
            reply_variant_string(msg, bus, "v-gui");
            return DBUS_HANDLER_RESULT_HANDLED;
        }
        if (strcmp(prop, "Version") == 0) {
            reply_variant_string(msg, bus, "0.1");
            return DBUS_HANDLER_RESULT_HANDLED;
        }
        if (strcmp(prop, "Id") == 0) {
            reply_variant_int32(msg, bus, 0);
            return DBUS_HANDLER_RESULT_HANDLED;
        }
    }

    // Value properties
    if (strcmp(iface, ATSPI_VALUE) == 0 &&
            idx >= 0 && idx < g_node_count) {
        const GuiA11yNode *n = &g_nodes[idx];
        if (strcmp(prop, "CurrentValue") == 0) {
            reply_variant_double(msg, bus,
                (double)n->value_num);
            return DBUS_HANDLER_RESULT_HANDLED;
        }
        if (strcmp(prop, "MinimumValue") == 0) {
            reply_variant_double(msg, bus,
                (double)n->value_min);
            return DBUS_HANDLER_RESULT_HANDLED;
        }
        if (strcmp(prop, "MaximumValue") == 0) {
            reply_variant_double(msg, bus,
                (double)n->value_max);
            return DBUS_HANDLER_RESULT_HANDLED;
        }
        if (strcmp(prop, "MinimumIncrement") == 0) {
            double range =
                (double)(n->value_max - n->value_min);
            double incr = range > 0 ? range / 100.0 : 0.0;
            reply_variant_double(msg, bus, incr);
            return DBUS_HANDLER_RESULT_HANDLED;
        }
    }

    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

// -------------------------------------------------------
// Handle Properties.GetAll (minimal — returns empty dict)
// -------------------------------------------------------

static DBusHandlerResult handle_properties_getall(
        DBusMessage *msg, DBusConnection *bus) {
    DBusMessage *reply = dbus_message_new_method_return(msg);
    if (!reply) return DBUS_HANDLER_RESULT_HANDLED;
    DBusMessageIter iter, dict;
    dbus_message_iter_init_append(reply, &iter);
    dbus_message_iter_open_container(&iter,
        DBUS_TYPE_ARRAY, "{sv}", &dict);
    dbus_message_iter_close_container(&iter, &dict);
    dbus_connection_send(bus, reply, NULL);
    dbus_message_unref(reply);
    return DBUS_HANDLER_RESULT_HANDLED;
}

// -------------------------------------------------------
// D-Bus message filter (main dispatch)
// -------------------------------------------------------

static DBusHandlerResult a11y_filter(
        DBusConnection *bus, DBusMessage *msg, void *data) {
    (void)data;
    if (dbus_message_get_type(msg) != DBUS_MESSAGE_TYPE_METHOD_CALL)
        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

    const char *path = dbus_message_get_path(msg);
    const char *iface = dbus_message_get_interface(msg);
    const char *member = dbus_message_get_member(msg);
    if (!path || !member) return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

    int idx = parse_node_index(path);
    if (idx == -2) return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

    // Properties.Get / GetAll
    if (iface && strcmp(iface, DBUS_PROPERTIES) == 0) {
        if (strcmp(member, "Get") == 0)
            return handle_properties_get(msg, bus, idx);
        if (strcmp(member, "GetAll") == 0)
            return handle_properties_getall(msg, bus);
        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
    }

    // Accessible interface
    if (!iface || strcmp(iface, ATSPI_ACCESSIBLE) == 0) {
        DBusHandlerResult r =
            handle_accessible(msg, bus, idx, member);
        if (r == DBUS_HANDLER_RESULT_HANDLED) return r;
    }

    // Component interface
    if (!iface || strcmp(iface, ATSPI_COMPONENT) == 0) {
        DBusHandlerResult r =
            handle_component(msg, bus, idx, member);
        if (r == DBUS_HANDLER_RESULT_HANDLED) return r;
    }

    // Action interface
    if (!iface || strcmp(iface, ATSPI_ACTION) == 0) {
        DBusHandlerResult r =
            handle_action(msg, bus, idx, member);
        if (r == DBUS_HANDLER_RESULT_HANDLED) return r;
    }

    // Value interface
    if (!iface || strcmp(iface, ATSPI_VALUE) == 0) {
        DBusHandlerResult r =
            handle_value(msg, bus, idx, member);
        if (r == DBUS_HANDLER_RESULT_HANDLED) return r;
    }

    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

// -------------------------------------------------------
// Public C API
// -------------------------------------------------------

void gui_a11y_init(void *ns_window, GuiA11yActionFn cb,
        void *user_data) {
    (void)ns_window; // unused on Linux

    if (g_a11y_bus) return; // already initialized

    g_action_fn = cb;
    g_user_data = user_data;

    DBusError err;
    dbus_error_init(&err);

    // 1. Connect to session bus to find AT-SPI2 bus address
    DBusConnection *session = dbus_bus_get(
        DBUS_BUS_SESSION, &err);
    if (!session || dbus_error_is_set(&err)) {
        dbus_error_free(&err);
        return;
    }

    // 2. Call org.a11y.Bus.GetAddress
    DBusMessage *req = dbus_message_new_method_call(
        ATSPI_BUS_NAME, ATSPI_BUS_PATH,
        ATSPI_BUS_IFACE, "GetAddress");
    if (!req) {
        dbus_connection_unref(session);
        return;
    }

    DBusMessage *resp = dbus_connection_send_with_reply_and_block(
        session, req, 1000, &err);
    dbus_message_unref(req);
    dbus_connection_unref(session);

    if (!resp || dbus_error_is_set(&err)) {
        dbus_error_free(&err);
        if (resp) dbus_message_unref(resp);
        return;
    }

    const char *addr = NULL;
    if (!dbus_message_get_args(resp, &err,
            DBUS_TYPE_STRING, &addr, DBUS_TYPE_INVALID)
            || !addr || addr[0] == '\0') {
        dbus_error_free(&err);
        dbus_message_unref(resp);
        return;
    }

    // 3. Connect to AT-SPI2 bus
    g_a11y_bus = dbus_connection_open(addr, &err);
    dbus_message_unref(resp);
    if (!g_a11y_bus || dbus_error_is_set(&err)) {
        dbus_error_free(&err);
        g_a11y_bus = NULL;
        return;
    }

    if (!dbus_bus_register(g_a11y_bus, &err)) {
        dbus_error_free(&err);
        dbus_connection_unref(g_a11y_bus);
        g_a11y_bus = NULL;
        return;
    }

    // Store our unique name
    const char *name = dbus_bus_get_unique_name(g_a11y_bus);
    g_bus_name = name ? strdup(name) : strdup("");

    // 4. Install message filter
    dbus_connection_add_filter(g_a11y_bus, a11y_filter,
        NULL, NULL);

    // 5. Register with AT-SPI2 registry
    DBusMessage *reg = dbus_message_new_method_call(
        "org.a11y.atspi.Registry", ATSPI_REG_PATH,
        ATSPI_REG_IFACE, "RegisterApplication");
    if (reg) {
        DBusMessageIter iter, st;
        dbus_message_iter_init_append(reg, &iter);
        dbus_message_iter_open_container(&iter,
            DBUS_TYPE_STRUCT, NULL, &st);
        dbus_message_iter_append_basic(&st,
            DBUS_TYPE_STRING, &g_bus_name);
        const char *root = ROOT_PATH;
        dbus_message_iter_append_basic(&st,
            DBUS_TYPE_OBJECT_PATH, &root);
        dbus_message_iter_close_container(&iter, &st);

        // Fire and forget
        dbus_connection_send(g_a11y_bus, reg, NULL);
        dbus_message_unref(reg);
    }

    dbus_connection_flush(g_a11y_bus);
}

void gui_a11y_sync(GuiA11yNode *nodes, int count,
        int focused_idx) {
    if (!g_a11y_bus) return;

    // Drain pending D-Bus messages (non-blocking).
    // read_write with timeout=0 reads any available data
    // without blocking, then we dispatch queued messages.
    dbus_connection_read_write(g_a11y_bus, 0);
    while (dbus_connection_get_dispatch_status(g_a11y_bus)
            == DBUS_DISPATCH_DATA_REMAINS) {
        dbus_connection_dispatch(g_a11y_bus);
    }

    // Update tree snapshot
    g_nodes = nodes;
    g_node_count = count;
    g_focused_idx = focused_idx;

    // Emit children-changed on root to notify tree update
    emit_signal(ROOT_PATH,
        "org.a11y.atspi.Event.Object",
        "ChildrenChanged", "add",
        0, count, g_bus_name, ROOT_PATH);

    // Focus change
    int new_focused_id = -1;
    if (focused_idx >= 0 && focused_idx < count) {
        new_focused_id = nodes[focused_idx].focus_id;
    }
    if (new_focused_id != g_prev_focused_id) {
        g_prev_focused_id = new_focused_id;
        if (focused_idx >= 0 && focused_idx < count) {
            char buf[128];
            emit_signal(
                node_path(focused_idx, buf, sizeof(buf)),
                "org.a11y.atspi.Event.Object",
                "StateChanged", "focused",
                1, 0, NULL, NULL);
        }
    }

    dbus_connection_flush(g_a11y_bus);
}

void gui_a11y_destroy(void) {
    if (!g_a11y_bus) return;

    // Deregister from registry
    DBusMessage *dereg = dbus_message_new_method_call(
        "org.a11y.atspi.Registry", ATSPI_REG_PATH,
        ATSPI_REG_IFACE, "DeregisterApplication");
    if (dereg) {
        DBusMessageIter iter, st;
        dbus_message_iter_init_append(dereg, &iter);
        dbus_message_iter_open_container(&iter,
            DBUS_TYPE_STRUCT, NULL, &st);
        dbus_message_iter_append_basic(&st,
            DBUS_TYPE_STRING, &g_bus_name);
        const char *root = ROOT_PATH;
        dbus_message_iter_append_basic(&st,
            DBUS_TYPE_OBJECT_PATH, &root);
        dbus_message_iter_close_container(&iter, &st);
        dbus_connection_send(g_a11y_bus, dereg, NULL);
        dbus_message_unref(dereg);
        dbus_connection_flush(g_a11y_bus);
    }

    dbus_connection_remove_filter(g_a11y_bus, a11y_filter,
        NULL);
    dbus_connection_close(g_a11y_bus);
    dbus_connection_unref(g_a11y_bus);

    g_a11y_bus = NULL;
    g_action_fn = NULL;
    g_user_data = NULL;
    g_nodes = NULL;
    g_node_count = 0;
    g_focused_idx = -1;
    g_prev_focused_id = -1;
    if (g_bus_name) {
        free(g_bus_name);
        g_bus_name = NULL;
    }
}

void gui_a11y_announce(const char *msg) {
    if (!g_a11y_bus || !msg || msg[0] == '\0') return;

    // Emit object:announcement signal on root.
    // Requires AT-SPI2 >= 2.46. Older systems ignore it.
    DBusMessage *sig = dbus_message_new_signal(
        ROOT_PATH,
        "org.a11y.atspi.Event.Object",
        "Announcement");
    if (!sig) return;

    DBusMessageIter iter;
    dbus_message_iter_init_append(sig, &iter);

    // detail string
    const char *detail = "";
    dbus_message_iter_append_basic(&iter,
        DBUS_TYPE_STRING, &detail);

    // two int32 args (unused)
    dbus_int32_t zero = 0;
    dbus_message_iter_append_basic(&iter,
        DBUS_TYPE_INT32, &zero);
    dbus_message_iter_append_basic(&iter,
        DBUS_TYPE_INT32, &zero);

    // variant containing the announcement text
    DBusMessageIter var;
    dbus_message_iter_open_container(&iter,
        DBUS_TYPE_VARIANT, DBUS_TYPE_STRING_AS_STRING, &var);
    dbus_message_iter_append_basic(&var,
        DBUS_TYPE_STRING, &msg);
    dbus_message_iter_close_container(&iter, &var);

    dbus_connection_send(g_a11y_bus, sig, NULL);
    dbus_message_unref(sig);
    dbus_connection_flush(g_a11y_bus);
}
