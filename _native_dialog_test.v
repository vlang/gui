module gui

import nativebridge

fn test_nativebridge_module_loads() {
	_ = nativebridge.BridgeDialogStatus.ok
}

fn test_native_extensions_from_filters_normalizes_and_dedupes() {
	extensions := native_extensions_from_filters([
		NativeFileFilter{
			extensions: ['.PNG', ' jpg ', '', 'png']
		},
		NativeFileFilter{
			extensions: ['txt', 'TXT']
		},
	]) or { panic(err.msg()) }
	assert extensions == ['png', 'jpg', 'txt']
}

fn test_native_normalize_extension_rejects_invalid_chars() {
	_ := native_normalize_extension('tar.gz') or {
		assert err.msg().contains('invalid extension')
		return
	}
	assert false
}

fn test_native_save_extensions_appends_default_once() {
	extensions := native_save_extensions([
		NativeFileFilter{
			extensions: ['jpg', '.JPG']
		},
	], '.png') or { panic(err.msg()) }
	assert extensions == ['jpg', 'png']
}

fn test_native_filter_specs_from_filters_preserves_names_and_groups() {
	specs := native_filter_specs_from_filters([
		NativeFileFilter{
			name:       'Images: raster, raw'
			extensions: ['.PNG', ' jpg ', 'png']
		},
		NativeFileFilter{
			name:       'Docs'
			extensions: ['txt', 'md']
		},
	], '') or { panic(err.msg()) }

	assert specs == native_dialog_filter_spec_prefix +
		'19:Images: raster, raw7:png,jpg4:Docs6:txt,md'
}

fn test_native_filter_specs_from_filters_uses_legacy_when_no_names() {
	specs := native_filter_specs_from_filters([
		NativeFileFilter{
			extensions: ['png', 'jpg']
		},
	], '') or { panic(err.msg()) }

	assert specs == ''
}

fn test_native_filter_specs_from_filters_appends_save_default_when_named() {
	specs := native_filter_specs_from_filters([
		NativeFileFilter{
			name:       'Images'
			extensions: ['png']
		},
	], '.txt') or { panic(err.msg()) }

	assert specs == native_dialog_filter_spec_prefix + '6:Images3:png0:3:txt'
}

fn test_native_result_from_bridge_ex_maps_ok_paths_without_native_ui() {
	mut w := Window{}
	result := native_result_from_bridge_ex(nativebridge.BridgeDialogResultEx{
		status:  .ok
		entries: [
			nativebridge.BridgeBookmarkEntry{
				path: 'C:/tmp/example.txt'
			},
		]
	}, mut w)

	assert result.status == .ok
	assert result.paths.len == 1
	assert result.paths[0].path == 'C:/tmp/example.txt'
	assert result.error_code == ''
	assert result.error_message == ''
}

fn test_native_result_from_bridge_ex_maps_cancel_without_native_ui() {
	mut w := Window{}
	result := native_result_from_bridge_ex(nativebridge.BridgeDialogResultEx{
		status: .cancel
	}, mut w)

	assert result.status == .cancel
	assert result.paths.len == 0
	assert result.error_code == ''
	assert result.error_message == ''
}

fn test_native_result_from_bridge_ex_maps_error_without_native_ui() {
	mut w := Window{}
	result := native_result_from_bridge_ex(nativebridge.BridgeDialogResultEx{
		status:        .error
		error_code:    'windows_dialog'
		error_message: 'dialog failed'
	}, mut w)

	assert result.status == .error
	assert result.paths.len == 0
	assert result.error_code == 'windows_dialog'
	assert result.error_message == 'dialog failed'
}

fn test_native_alert_result_from_bridge_maps_ok_without_native_ui() {
	result := native_alert_result_from_bridge(nativebridge.BridgeAlertResult{
		status: .ok
	})

	assert result.status == .ok
	assert result.error_code == ''
	assert result.error_message == ''
}

fn test_native_alert_result_from_bridge_maps_cancel_without_native_ui() {
	result := native_alert_result_from_bridge(nativebridge.BridgeAlertResult{
		status: .cancel
	})

	assert result.status == .cancel
	assert result.error_code == ''
	assert result.error_message == ''
}

fn test_native_alert_result_from_bridge_maps_error_without_native_ui() {
	result := native_alert_result_from_bridge(nativebridge.BridgeAlertResult{
		status:        .error
		error_code:    'message_box'
		error_message: 'message box failed'
	})

	assert result.status == .error
	assert result.error_code == 'message_box'
	assert result.error_message == 'message box failed'
}

$if !(macos || linux || windows) {
	fn test_nativebridge_stub_returns_unsupported() {
		open_result := nativebridge.open_dialog(nativebridge.BridgeOpenCfg{})
		assert open_result.status == .error
		assert open_result.error_code == 'unsupported'

		save_result := nativebridge.save_dialog(nativebridge.BridgeSaveCfg{})
		assert save_result.status == .error
		assert save_result.error_code == 'unsupported'

		folder_result := nativebridge.folder_dialog(nativebridge.BridgeFolderCfg{})
		assert folder_result.status == .error
		assert folder_result.error_code == 'unsupported'
	}
}
