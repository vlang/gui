module gui

// NativeDialogStatus reports native dialog outcome.
pub enum NativeDialogStatus as u8 {
	ok
	cancel
	error
}

// NativeDialogResult contains native dialog completion data.
pub struct NativeDialogResult {
pub:
	status        NativeDialogStatus
	paths         []string
	error_code    string
	error_message string
}

// NativeFileFilter groups file extensions for native dialogs.
pub struct NativeFileFilter {
pub:
	name       string
	extensions []string
}

// NativeOpenDialogCfg configures the native open-file dialog.
pub struct NativeOpenDialogCfg {
pub:
	title          string
	start_dir      string
	filters        []NativeFileFilter
	allow_multiple bool
	on_done        fn (NativeDialogResult, mut Window) = fn (_ NativeDialogResult, mut _ Window) {}
}

// NativeSaveDialogCfg configures the native save-file dialog.
pub struct NativeSaveDialogCfg {
pub:
	title             string
	start_dir         string
	default_name      string
	default_extension string
	filters           []NativeFileFilter
	confirm_overwrite bool = true
	on_done           fn (NativeDialogResult, mut Window) = fn (_ NativeDialogResult, mut _ Window) {}
}

// NativeFolderDialogCfg configures the native folder dialog.
pub struct NativeFolderDialogCfg {
pub:
	title                  string
	start_dir              string
	can_create_directories bool = true
	on_done                fn (NativeDialogResult, mut Window) = fn (_ NativeDialogResult, mut _ Window) {}
}

// native_open_dialog opens a native file picker dialog.
pub fn (mut w Window) native_open_dialog(cfg NativeOpenDialogCfg) {
	cfg_cpy := cfg
	w.queue_command(fn [cfg_cpy] (mut w Window) {
		native_open_dialog_impl(mut w, cfg_cpy)
	})
}

// native_save_dialog opens a native save-as dialog.
pub fn (mut w Window) native_save_dialog(cfg NativeSaveDialogCfg) {
	cfg_cpy := cfg
	w.queue_command(fn [cfg_cpy] (mut w Window) {
		native_save_dialog_impl(mut w, cfg_cpy)
	})
}

// native_folder_dialog opens a native folder picker dialog.
pub fn (mut w Window) native_folder_dialog(cfg NativeFolderDialogCfg) {
	cfg_cpy := cfg
	w.queue_command(fn [cfg_cpy] (mut w Window) {
		native_folder_dialog_impl(mut w, cfg_cpy)
	})
}
