module winsetup

fn test_text_system_message_maps_missing_vglyph_module() {
	message := text_system_message('builder error: module vglyph not found')

	assert message.contains('Failed to initialize text rendering system on Windows.')
	assert message.contains('`vglyph` is not installed')
	assert message.contains('v install vglyph')
	assert message.contains('module vglyph not found')
}

fn test_text_system_message_maps_pango_header() {
	message := text_system_message('fatal error C1083: cannot open include file: pango/pango.h')

	assert message.contains('Pango headers are missing')
	assert message.contains('vcpkg install pango freetype')
	assert message.contains('native Windows shell')
}

fn test_text_system_message_maps_freetype_header() {
	message := text_system_message('fatal error: ft2build.h: No such file or directory')

	assert message.contains('Freetype headers are missing')
	assert message.contains('vcpkg install freetype pango')
	assert message.contains('MSVC/vcpkg')
}

fn test_text_system_message_maps_unresolved_text_symbols() {
	message :=
		text_system_message('LNK2019: unresolved external symbol pango_layout_new referenced in function')

	assert message.contains('Pango/Freetype libraries are not linked')
	assert message.contains('matching vcpkg `x64-windows` packages')
	assert message.contains('do not mix MSVC objects with MSYS2 libraries')
}

fn test_text_system_message_maps_missing_dll() {
	message :=
		text_system_message('The code execution cannot proceed because libpango-1.0-0.dll was not found.')

	assert message.contains('runtime DLL is missing')
	assert message.contains('setup blocker')
	assert message.contains('should not rely on random DLL copying')
	assert !message.contains('vglyph' + ' runtime DLL')
}

fn test_text_system_message_maps_vcpkg_setup() {
	message := text_system_message('vcpkg missing required packages: pango')

	assert message.contains('vcpkg is not visible or the required text packages are not installed')
	assert message.contains('vcpkg install pango freetype')
	assert message.contains('MSVC triplet')
}

fn test_text_system_message_maps_msvc_setup() {
	message := text_system_message('cl.exe was not found; Windows SDK is missing')

	assert message.contains('MSVC compiler or Windows SDK is not visible')
	assert message.contains('x64 Developer PowerShell')
	assert message.contains('x64 Native Tools shell')
}

fn test_text_system_message_maps_msys2_mingw_setup() {
	message := text_system_message('msys2 mingw64 pkg-config could not find pango')

	assert message.contains('MSYS2/MinGW dependency discovery is being used')
	assert message.contains('MSYS2/GCC is exploratory')
	assert message.contains('MINGW64')
	assert message.contains('mingw-w64-x86_64-pango')
	assert message.contains('mingw-w64-x86_64-freetype')
}

fn test_text_system_message_maps_generic_fallback() {
	message := text_system_message('backend returned unknown text init failure')

	assert message.contains('The text stack did not initialize')
	assert message.contains('Use native Windows with MSVC and vcpkg')
	assert message.contains('vcpkg install pango freetype')
	assert message.contains('backend returned unknown text init failure')
}

fn test_script_message_uses_same_rules_with_script_prefix() {
	message := script_message('cl.exe was not found; Windows SDK is missing')

	assert message.contains('Failed Windows setup preflight.')
	assert message.contains('MSVC compiler or Windows SDK is not visible')
	assert message.contains('x64 Developer PowerShell')
	assert !message.contains('Failed to initialize text rendering system')
}

fn test_script_message_maps_empty_detail() {
	message := script_message('')

	assert message.contains('Failed Windows setup preflight.')
	assert message.contains('No lower-level error was provided.')
}
