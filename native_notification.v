module gui

// NativeNotificationStatus reports notification outcome.
pub enum NativeNotificationStatus as u8 {
	ok
	denied
	error
}

// NativeNotificationResult contains notification delivery data.
pub struct NativeNotificationResult {
pub:
	status        NativeNotificationStatus
	error_code    string
	error_message string
}

// NativeNotificationCfg configures an OS-level notification.
pub struct NativeNotificationCfg {
pub:
	title   string
	body    string
	on_done fn (NativeNotificationResult, mut Window) = fn (_ NativeNotificationResult, mut _ Window) {}
}

// native_notification posts an OS-level notification.
// macOS: UNUserNotificationCenter (permission requested
// lazily on first call). Windows: Shell_NotifyIcon balloon.
// Linux: D-Bus org.freedesktop.Notifications.
pub fn (mut w Window) native_notification(cfg NativeNotificationCfg) {
	cfg_cpy := cfg
	w.queue_command(fn [cfg_cpy] (mut w Window) {
		native_notification_impl(mut w, cfg_cpy)
	})
}
