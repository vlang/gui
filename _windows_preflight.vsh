#!/usr/bin/env -S v

import os
import time
import winsetup

const windows_preflight_prefix = 'Failed Windows setup preflight.'
const windows_preflight_temp_prefix = 'gui_windows_preflight_'

fn main() {
	$if !windows {
		eprintln('${windows_preflight_prefix}\n\nLikely cause: this command is not running on native Windows.\n\nAction: run `v run _windows_preflight.vsh` from native Windows, not WSL or Wine.\n\nDetails: ${os.user_os()} is not a Windows validation gate.')
		exit(1)
	}

	println('Windows setup preflight: native Windows detected.')
	v_version := os.execute('v version')
	if v_version.exit_code == 0 {
		println(v_version.output.trim_space())
	}

	temp_dir := windows_preflight_create_temp_dir() or {
		eprintln('${windows_preflight_prefix}\n\nLikely cause: unable to create a temporary probe directory.\n\nAction: check that the Windows temp directory is writable, then rerun the preflight.\n\nDetails: ${err}')
		exit(1)
	}

	compiler := windows_preflight_compiler()
	if !windows_preflight_check_compiler(compiler) {
		windows_preflight_cleanup_then_exit(temp_dir)
	}
	if compiler == 'msvc' && !windows_preflight_check_vcpkg_packages() {
		windows_preflight_cleanup_then_exit(temp_dir)
	}
	if !windows_preflight_check_vglyph_import(temp_dir) {
		windows_preflight_cleanup_then_exit(temp_dir)
	}
	if !windows_preflight_check_text_probe(compiler, temp_dir) {
		windows_preflight_cleanup_then_exit(temp_dir)
	}

	windows_preflight_remove_temp_dir(temp_dir)
	println('Windows setup preflight passed.')
}

fn windows_preflight_compiler() string {
	raw := os.getenv('GUI_WINDOWS_PREFLIGHT_CC')
	if raw == '' {
		return 'msvc'
	}
	return raw.trim_space().to_lower()
}

fn windows_preflight_check_compiler(compiler string) bool {
	match compiler {
		'msvc' {
			return
				windows_preflight_run('MSVC compiler', 'where.exe cl.exe', 'cl.exe was not found; Windows SDK may be missing')
				&& windows_preflight_run('MSVC linker', 'where.exe link.exe', 'link.exe was not found; Windows SDK may be missing')
		}
		'gcc' {
			return
				windows_preflight_run('MinGW GCC compiler', 'where.exe gcc.exe', 'msys2 mingw64 gcc.exe was not found')
				&& windows_preflight_run('MinGW pkg-config text packages', 'pkg-config --exists pango freetype2', 'msys2 mingw64 pkg-config could not find pango or freetype2')
		}
		'clang' {
			return windows_preflight_run('Clang compiler', 'where.exe clang.exe',
				'clang.exe was not found; MSVC/vcpkg remains the supported path')
		}
		else {
			windows_preflight_report_failure('compiler selection',
				'unsupported compiler selection `${compiler}`. supported values are msvc, clang, gcc')
			return false
		}
	}
}

fn windows_preflight_check_vcpkg_packages() bool {
	if !windows_preflight_run('vcpkg command', 'where.exe vcpkg.exe', 'vcpkg was not found') {
		return false
	}
	result := os.execute('vcpkg list')
	if result.exit_code != 0 {
		windows_preflight_report_failure('vcpkg package list',
			'vcpkg list failed\n${result.output}')
		return false
	}
	lower := result.output.to_lower()
	mut missing := []string{}
	if !lower.contains('pango') {
		missing << 'pango'
	}
	if !lower.contains('freetype') {
		missing << 'freetype'
	}
	if missing.len > 0 {
		windows_preflight_report_failure('vcpkg packages',
			'vcpkg missing required packages: ${missing.join(', ')}')
		return false
	}
	println('vcpkg packages ... ok')
	return true
}

fn windows_preflight_check_vglyph_import(temp_dir string) bool {
	probe_path := windows_preflight_probe_path(temp_dir, 'vglyph_import.v')
	os.write_file(probe_path, 'import vglyph\n\nfn main() {\n\t_ := vglyph.TextConfig{}\n}\n') or {
		eprintln('failed to write temporary preflight probe: ${err}')
		return false
	}
	return windows_preflight_run('vglyph import',
		'v -check ${windows_preflight_quote(probe_path)}', 'module vglyph not found')
}

fn windows_preflight_check_text_probe(compiler string, temp_dir string) bool {
	probe_path := windows_preflight_probe_path(temp_dir, 'text_stack_probe.v')
	exe_path := windows_preflight_probe_path(temp_dir, 'text_stack_probe.exe')
	os.write_file(probe_path, 'import vglyph\n\nfn main() {\n\t_ := vglyph.TextConfig{}\n}\n') or {
		eprintln('failed to write temporary preflight probe: ${err}')
		return false
	}
	if !windows_preflight_run('Pango/Freetype compile probe',
		'v -no-parallel -cc ${compiler} -o ${windows_preflight_quote(exe_path)} ${windows_preflight_quote(probe_path)}',
		'Pango/Freetype compile probe failed') {
		return false
	}
	return windows_preflight_run('Pango/Freetype startup probe', windows_preflight_quote(exe_path),
		'Pango/Freetype startup probe failed')
}

fn windows_preflight_run(label string, cmd string, failure_hint string) bool {
	print('${label} ... ')
	result := os.execute(cmd)
	if result.exit_code == 0 {
		println('ok')
		return true
	}
	println('failed')
	windows_preflight_report_failure(label, '${failure_hint}\n${result.output}')
	return false
}

fn windows_preflight_report_failure(label string, raw_error string) {
	eprintln('\n${label} failed:')
	eprintln(winsetup.script_message(raw_error))
}

fn windows_preflight_cleanup_then_exit(temp_dir string) {
	windows_preflight_remove_temp_dir(temp_dir)
	exit(1)
}

fn windows_preflight_create_temp_dir() !string {
	base := os.temp_dir()
	pid := os.getpid()
	for attempt in 0 .. 20 {
		name := '${windows_preflight_temp_prefix}${pid}_${time.now().unix_micro()}_${attempt}'
		path := os.join_path(base, name)
		os.mkdir(path) or { continue }
		return path
	}
	return error('could not create ${windows_preflight_temp_prefix}* under ${base}')
}

fn windows_preflight_remove_temp_dir(path string) {
	if !windows_preflight_is_own_temp_dir(path) {
		eprintln('not removing unexpected preflight temp path: ${path}')
		return
	}
	os.rmdir_all(path) or { eprintln('failed to remove preflight temp directory ${path}: ${err}') }
}

fn windows_preflight_is_own_temp_dir(path string) bool {
	if path == '' || !os.exists(path) || !os.is_dir(path) {
		return false
	}
	return os.dir(path) == os.temp_dir() && os.base(path).starts_with(windows_preflight_temp_prefix)
}

fn windows_preflight_probe_path(temp_dir string, name string) string {
	return os.join_path(temp_dir, name)
}

fn windows_preflight_quote(path string) string {
	return '"${path.replace('"', '\\"')}"'
}
