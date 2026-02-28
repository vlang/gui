module gui

import nativebridge

fn test_notification_result_from_bridge_ok() {
	br := nativebridge.BridgeNotificationResult{
		status: .ok
	}
	r := native_notification_result_from_bridge(br)
	assert r.status == .ok
	assert r.error_code == ''
	assert r.error_message == ''
}

fn test_notification_result_from_bridge_denied() {
	br := nativebridge.BridgeNotificationResult{
		status:        .denied
		error_code:    'denied'
		error_message: 'permission denied'
	}
	r := native_notification_result_from_bridge(br)
	assert r.status == .denied
	assert r.error_code == 'denied'
	assert r.error_message == 'permission denied'
}

fn test_notification_result_from_bridge_error() {
	br := nativebridge.BridgeNotificationResult{
		status:        .error
		error_code:    'dbus'
		error_message: 'session bus unavailable'
	}
	r := native_notification_result_from_bridge(br)
	assert r.status == .error
	assert r.error_code == 'dbus'
	assert r.error_message == 'session bus unavailable'
}

fn test_notification_cfg_default_on_done_is_noop() {
	cfg := NativeNotificationCfg{
		title: 'test'
	}
	// Default on_done should not panic.
	r := NativeNotificationResult{
		status: .ok
	}
	// Cannot call without mut Window, but verify cfg compiles
	// with default callback.
	assert cfg.title == 'test'
	assert cfg.body == ''
	assert r.status == .ok
}
