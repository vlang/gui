module gui

import nativebridge

fn native_notification_impl(mut w Window, cfg NativeNotificationCfg) {
	// Spawn background thread — send_notification blocks
	// (semaphores, Sleep, D-Bus) and must not stall the
	// render thread.
	spawn fn [cfg] (mut w Window) {
		bridge_result := nativebridge.send_notification(nativebridge.BridgeNotificationCfg{
			title: cfg.title
			body:  cfg.body
		})
		result := native_notification_result_from_bridge(bridge_result)
		native_dispatch_notification_done(mut w, cfg.on_done, result)
	}(mut w)
}

fn native_notification_result_from_bridge(br nativebridge.BridgeNotificationResult) NativeNotificationResult {
	status := match br.status {
		.ok { NativeNotificationStatus.ok }
		.denied { NativeNotificationStatus.denied }
		.error { NativeNotificationStatus.error }
	}
	return NativeNotificationResult{
		status:        status
		error_code:    br.error_code
		error_message: br.error_message
	}
}

fn native_dispatch_notification_done(mut w Window,
	on_done fn (NativeNotificationResult, mut Window),
	result NativeNotificationResult) {
	result_cpy := result
	w.queue_command(fn [on_done, result_cpy] (mut w Window) {
		on_done(result_cpy, mut w)
	})
}
