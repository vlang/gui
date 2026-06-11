module gui

import os
import winsetup

fn test_windows_text_system_wrapper_uses_shared_winsetup_message() {
	raw_error := 'builder error: module vglyph not found'

	assert windows_text_system_setup_message(raw_error) == winsetup.text_system_message(raw_error)
}

fn test_windows_text_system_wrapper_keeps_msvc_actionable_message() {
	message := windows_text_system_setup_message('cl.exe was not found; Windows SDK is missing')

	assert message.contains('Failed to initialize text rendering system on Windows.')
	assert message.contains('x64 Developer PowerShell')
	assert message.contains('x64 Native Tools shell')
}

fn test_windows_preflight_script_imports_winsetup_source_of_truth() {
	script := os.read_file('_windows_preflight.vsh') or { panic(err) }

	assert script.contains('import winsetup')
	assert script.contains('winsetup.script_message')
	assert !script.contains('windows_setup_preflight.v')
	assert !script.contains('windows_script_setup_message')
	assert !script.contains('windows_preflight_shared_actionable_message')
	assert !script.contains('Pango headers are missing')
	assert !script.contains('Freetype headers are missing')
	assert !script.contains('MSYS2/GCC is exploratory')
	assert !script.contains('Pango/Freetype/HarfBuzz/FriBidi/Fontconfig runtime DLL')
}
