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

$if !macos {
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
