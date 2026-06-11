module gui

import winsetup

fn windows_text_system_setup_message(raw_error string) string {
	return winsetup.text_system_message(raw_error)
}
