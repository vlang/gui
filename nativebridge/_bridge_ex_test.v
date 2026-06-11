module nativebridge

fn test_bridge_result_ex_from_legacy_ok() {
	legacy := BridgeDialogResult{
		status: .ok
		paths:  ['/a', '/b']
	}
	ex := bridge_result_ex_from_legacy(legacy)
	assert ex.status == .ok
	assert ex.entries.len == 2
	assert ex.entries[0].path == '/a'
	assert ex.entries[1].path == '/b'
	assert ex.entries[0].data.len == 0
	assert ex.entries[1].data.len == 0
}

fn test_bridge_result_ex_from_legacy_cancel() {
	legacy := BridgeDialogResult{
		status: .cancel
	}
	ex := bridge_result_ex_from_legacy(legacy)
	assert ex.status == .cancel
	assert ex.entries.len == 0
}

fn test_bridge_result_ex_from_legacy_error() {
	legacy := BridgeDialogResult{
		status:        .error
		error_code:    'test_code'
		error_message: 'test msg'
	}
	ex := bridge_result_ex_from_legacy(legacy)
	assert ex.status == .error
	assert ex.error_code == 'test_code'
	assert ex.error_message == 'test msg'
	assert ex.entries.len == 0
}

fn test_bridge_dialog_unsupported_result_ex() {
	ex := bridge_dialog_unsupported_result_ex()
	assert ex.status == .error
	assert ex.error_code == 'unsupported'
}

fn test_bridge_print_unsupported_result() {
	result := bridge_print_unsupported_result()
	assert result.status == .error
	assert result.error_code == 'unsupported'
	assert result.warnings.len == 0
}

fn test_bridge_alert_unsupported_result() {
	result := bridge_alert_unsupported_result()
	assert result.status == .error
	assert result.error_code == 'unsupported'
}

fn test_bridge_notification_status_from_int() {
	assert bridge_notification_status_from_int(0) == .ok
	assert bridge_notification_status_from_int(1) == .denied
	assert bridge_notification_status_from_int(2) == .error
	assert bridge_notification_status_from_int(999) == .error
}

fn test_bridge_notification_unsupported_result() {
	result := bridge_notification_unsupported_result()
	assert result.status == .error
	assert result.error_code == 'unsupported'
}
