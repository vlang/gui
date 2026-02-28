// notification_linux.c — Linux native notifications via D-Bus
// org.freedesktop.Notifications.Notify.
// libdbus-1 is already linked for AT-SPI2 a11y and portal.
// Compiled via #flag linux ... notification_linux.c in c_bindings.v.

#include <dbus/dbus.h>

#include "notification_bridge.h"

#define NOTIF_BUS_NAME "org.freedesktop.Notifications"
#define NOTIF_PATH     "/org/freedesktop/Notifications"
#define NOTIF_IFACE    "org.freedesktop.Notifications"

GuiNativeNotificationResult gui_native_send_notification(
    const char* title,
    const char* body
) {
    if (title == NULL || title[0] == '\0') {
        return gui_notif_result_error(
            "invalid_cfg", "title is required");
    }

    DBusError err;
    dbus_error_init(&err);

    DBusConnection* bus = dbus_bus_get(
        DBUS_BUS_SESSION, &err);
    if (dbus_error_is_set(&err) || bus == NULL) {
        dbus_error_free(&err);
        return gui_notif_result_error(
            "dbus", "could not connect to session bus");
    }

    // Build Notify method call:
    // Notify(app_name, replaces_id, app_icon,
    //        summary, body, actions, hints,
    //        expire_timeout)
    DBusMessage* msg = dbus_message_new_method_call(
        NOTIF_BUS_NAME, NOTIF_PATH,
        NOTIF_IFACE, "Notify");
    if (msg == NULL) {
        dbus_connection_unref(bus);
        return gui_notif_result_error(
            "dbus", "could not create Notify message");
    }

    const char* app_name = "";
    dbus_uint32_t replaces_id = 0;
    const char* app_icon = "";
    const char* summary = title;
    const char* body_str = (body != NULL) ? body : "";
    dbus_int32_t expire_timeout = -1;

    DBusMessageIter iter;
    dbus_message_iter_init_append(msg, &iter);

    dbus_message_iter_append_basic(
        &iter, DBUS_TYPE_STRING, &app_name);
    dbus_message_iter_append_basic(
        &iter, DBUS_TYPE_UINT32, &replaces_id);
    dbus_message_iter_append_basic(
        &iter, DBUS_TYPE_STRING, &app_icon);
    dbus_message_iter_append_basic(
        &iter, DBUS_TYPE_STRING, &summary);
    dbus_message_iter_append_basic(
        &iter, DBUS_TYPE_STRING, &body_str);

    // actions: empty array of strings
    DBusMessageIter actions_iter;
    dbus_message_iter_open_container(
        &iter, DBUS_TYPE_ARRAY,
        DBUS_TYPE_STRING_AS_STRING,
        &actions_iter);
    dbus_message_iter_close_container(
        &iter, &actions_iter);

    // hints: empty dict a{sv}
    DBusMessageIter hints_iter;
    dbus_message_iter_open_container(
        &iter, DBUS_TYPE_ARRAY, "{sv}",
        &hints_iter);
    dbus_message_iter_close_container(
        &iter, &hints_iter);

    dbus_message_iter_append_basic(
        &iter, DBUS_TYPE_INT32, &expire_timeout);

    // Send with timeout (5 seconds).
    DBusMessage* reply =
        dbus_connection_send_with_reply_and_block(
            bus, msg, 5000, &err);
    dbus_message_unref(msg);

    if (dbus_error_is_set(&err) || reply == NULL) {
        const char* detail = dbus_error_is_set(&err)
            ? err.message : "no reply";
        GuiNativeNotificationResult r =
            gui_notif_result_error("dbus", detail);
        dbus_error_free(&err);
        if (reply != NULL) dbus_message_unref(reply);
        dbus_connection_unref(bus);
        return r;
    }

    dbus_message_unref(reply);
    dbus_connection_unref(bus);
    return gui_notif_result_ok();
}

void gui_native_notification_result_free(
    GuiNativeNotificationResult result
) {
    gui_notif_result_free(result);
}
