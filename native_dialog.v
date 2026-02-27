module gui

// NativeDialogStatus reports native dialog outcome.
pub enum NativeDialogStatus as u8 {
	ok
	cancel
	error
}

// NativeDialogResult contains native dialog completion data.
// paths contains AccessiblePath entries with optional
// security-scoped grants for sandbox persistence.
pub struct NativeDialogResult {
pub:
	status        NativeDialogStatus
	paths         []AccessiblePath
	error_code    string
	error_message string
}

// path_strings returns just the path strings, discarding
// grants. Convenience for code that does not need sandbox
// persistence.
pub fn (r NativeDialogResult) path_strings() []string {
	mut out := []string{cap: r.paths.len}
	for p in r.paths {
		out << p.path
	}
	return out
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

// NativeAlertLevel controls the severity icon of a native
// message or confirm dialog.
pub enum NativeAlertLevel as u8 {
	info
	warning
	critical
}

// NativeAlertResult contains native alert dialog outcome.
pub struct NativeAlertResult {
pub:
	status        NativeDialogStatus
	error_code    string
	error_message string
}

// NativeMessageDialogCfg configures a native message dialog.
pub struct NativeMessageDialogCfg {
pub:
	title   string
	body    string
	level   NativeAlertLevel
	on_done fn (NativeAlertResult, mut Window) = fn (_ NativeAlertResult, mut _ Window) {}
}

// NativeConfirmDialogCfg configures a native confirm dialog.
pub struct NativeConfirmDialogCfg {
pub:
	title   string
	body    string
	level   NativeAlertLevel
	on_done fn (NativeAlertResult, mut Window) = fn (_ NativeAlertResult, mut _ Window) {}
}

// native_message_dialog opens a native OS message box.
pub fn (mut w Window) native_message_dialog(cfg NativeMessageDialogCfg) {
	cfg_cpy := cfg
	w.queue_command(fn [cfg_cpy] (mut w Window) {
		native_message_dialog_impl(mut w, cfg_cpy)
	})
}

// native_confirm_dialog opens a native OS Yes/No dialog.
pub fn (mut w Window) native_confirm_dialog(cfg NativeConfirmDialogCfg) {
	cfg_cpy := cfg
	w.queue_command(fn [cfg_cpy] (mut w Window) {
		native_confirm_dialog_impl(mut w, cfg_cpy)
	})
}
