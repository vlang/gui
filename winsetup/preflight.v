module winsetup

const text_system_prefix = 'Failed to initialize text rendering system on Windows.'
const script_prefix = 'Failed Windows setup preflight.'
const text_system_default_cause = 'The text stack did not initialize before the GUI could start.'
const script_default_cause = 'The Windows text setup probe failed before the GUI build could be validated.'

pub fn text_system_message(raw_error string) string {
	return message(raw_error, text_system_prefix, text_system_default_cause)
}

pub fn script_message(raw_error string) string {
	return message(raw_error, script_prefix, script_default_cause)
}

pub fn message(raw_error string, prefix string, default_cause string) string {
	detail := raw_error.trim_space()
	lower := detail.to_lower()
	mut cause := default_cause
	mut action := 'Use native Windows with MSVC and vcpkg. Run `vcpkg install pango freetype` and `v install vglyph` from the same x64 Developer PowerShell or Native Tools shell that runs `v`.'

	if mentions_vglyph_module(lower) {
		cause = '`vglyph` is not installed or is not visible to this V toolchain.'
		action = 'Run `v install vglyph`, then retry the same command with the same V executable.'
	} else if mentions_pango_header(lower) {
		cause = 'Pango headers are missing or not discoverable.'
		action = 'Run `vcpkg install pango freetype` for the active MSVC/vcpkg triplet, then retry from the same native Windows shell.'
	} else if mentions_freetype_header(lower) {
		cause = 'Freetype headers are missing or not discoverable.'
		action = 'Run `vcpkg install freetype pango` for the active MSVC/vcpkg triplet, then retry from the same native Windows shell.'
	} else if mentions_unresolved_text_symbol(lower) {
		cause = 'Pango/Freetype libraries are not linked for the compiler that is building the app.'
		action = 'Keep one Windows toolchain at a time. For the supported path, use MSVC plus matching vcpkg `x64-windows` packages; do not mix MSVC objects with MSYS2 libraries.'
	} else if mentions_missing_dll(lower) {
		cause = 'A Pango/Freetype/HarfBuzz/FriBidi/Fontconfig runtime DLL is missing when the executable starts.'
		action = 'Treat this as a setup blocker. The final user path should not rely on random DLL copying or global PATH edits; validate dependency deployment through the Windows smoke path.'
	} else if mentions_vcpkg(lower) {
		cause = 'vcpkg is not visible or the required text packages are not installed.'
		action = 'Install or expose vcpkg in the same native Windows shell, then run `vcpkg install pango freetype` for the active MSVC triplet.'
	} else if mentions_msvc(lower) {
		cause = 'The MSVC compiler or Windows SDK is not visible to the build.'
		action = 'Open an x64 Developer PowerShell or x64 Native Tools shell with the Desktop C++ workload installed, then rerun `v`.'
	} else if mentions_msys2(lower) {
		cause = 'MSYS2/MinGW dependency discovery is being used.'
		action = 'MSYS2/GCC is exploratory for this project. Prefer MSVC/vcpkg; if validating MinGW, run inside MINGW64 with matching `mingw-w64-x86_64-pango` and `mingw-w64-x86_64-freetype` packages.'
	}

	return '${prefix}\n\nLikely cause: ${cause}\n\nAction: ${action}\n\nDetails: ${detail_text(detail)}'
}

fn detail_text(detail string) string {
	if detail == '' {
		return 'No lower-level error was provided.'
	}
	return detail
}

fn mentions_vglyph_module(lower string) bool {
	return (lower.contains('module vglyph') && lower.contains('not found'))
		|| lower.contains('cannot import module "vglyph"')
		|| lower.contains("cannot import module 'vglyph'")
}

fn mentions_pango_header(lower string) bool {
	return lower.contains('pango/pango.h') || lower.contains('pango.h')
		|| (lower.contains('pango') && lower.contains('no such file or directory'))
}

fn mentions_freetype_header(lower string) bool {
	return lower.contains('ft2build.h') || lower.contains('freetype.h')
		|| lower.contains('freetype/freetype.h')
}

fn mentions_unresolved_text_symbol(lower string) bool {
	has_text_symbol := lower.contains('pango_') || lower.contains('ft_') || lower.contains('hb_')
		|| lower.contains('fribidi') || lower.contains('fontconfig')
	return (lower.contains('unresolved external symbol') && has_text_symbol)
		|| (lower.contains('undefined reference') && has_text_symbol)
}

fn mentions_missing_dll(lower string) bool {
	return lower.contains('.dll') && (lower.contains('was not found')
		|| lower.contains('could not be found') || lower.contains('missing')
		|| lower.contains('cannot find'))
}

fn mentions_vcpkg(lower string) bool {
	return lower.contains('vcpkg') && (lower.contains('not found')
		|| lower.contains('missing') || lower.contains('not installed')
		|| lower.contains('failed'))
}

fn mentions_msvc(lower string) bool {
	return lower.contains('cl.exe') || lower.contains('msvc') || lower.contains('link.exe')
		|| lower.contains('windows sdk')
}

fn mentions_msys2(lower string) bool {
	return lower.contains('msys2') || lower.contains('mingw') || lower.contains('ucrt64')
		|| lower.contains('mingw64')
}
