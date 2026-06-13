#!/usr/bin/env -S v

import os

const sqlite_marker = 'vtest build: present_sqlite3?'

fn sqlite_available() bool {
	mut dir := os.dir(@VEXE)
	for dir.len > 0 {
		sqlite_c := os.join_path(dir, 'thirdparty', 'sqlite', 'sqlite3.c')
		sqlite_cpp := os.join_path(dir, 'thirdparty', 'sqlite', 'sqlite3.cpp')
		if os.exists(sqlite_c) || os.exists(sqlite_cpp) {
			return true
		}
		parent := os.dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return false
}

fn sqlite_conditioned(file string) bool {
	content := os.read_file(file) or { return false }
	return content.contains(sqlite_marker)
}

fn normalize_path(base_dir string, file string) string {
	if os.is_abs_path(file) {
		return file
	}
	return os.join_path(base_dir, file)
}

unbuffer_stdout()

mut warn := true
mut skip_missing_sqlite := false
mut input_files := []string{}
base_dir := os.getwd()
for arg in os.args[1..] {
	if arg == '--' {
		continue
	}
	if arg == '--no-warnings' {
		warn = false
		continue
	}
	if arg == '--skip-missing-sqlite' {
		skip_missing_sqlite = true
		continue
	}
	input_files << normalize_path(base_dir, arg)
}

chdir(@DIR)!

output_dir := 'bin'
if exists(output_dir) {
	bin_files := ls(output_dir) or { [] }
	if bin_files.len > 0 {
		println('deleted:')
	}
	for file in bin_files.sorted() {
		file_path := join_path(output_dir, file)
		if is_file(file_path) {
			rm(file_path) or {
				println(err)
				continue
			}
			println('\t${file_path}')
		}
	}
} else {
	mkdir(output_dir) or {
		println(err)
		return
	}
}

mut files := if input_files.len > 0 {
	input_files
} else {
	ls('.') or { [] }.map(join_path_single(@DIR, it))
}
files = files.filter(file_ext(it) == '.v').sorted()
if files.len == 0 {
	println('no .v files found')
	return
}

skip_sqlite_examples := skip_missing_sqlite && !sqlite_available()
mut errors := []string{}
for i, file in files {
	progress := '(${i + 1:02}/${files.len:02})'
	if skip_sqlite_examples && sqlite_conditioned(file) {
		println('${progress} skipped sqlite-conditioned example: ${os.file_name(file)}')
		continue
	}
	_, name, _ := split_path(file)
	output_file := join_path(output_dir, name)
	warn_flag := if warn { '-W ' } else { '' }
	cmd := 'v -no-parallel ${warn_flag}-o ${output_file:-22s} ${file}'
	dsp := 'v -no-parallel ${warn_flag}-o ${output_file:-22s} ${os.file_name(file):-26s}'
	print('${progress} ${dsp}')
	result := execute(cmd)
	if result.exit_code == 0 {
		println('✅')
	} else {
		println('⭕')
		println(result.output)
		errors << cmd
	}
}
if errors.len > 0 {
	println('Encountered ${errors.len} error(s).')
	for i, ecmd in errors {
		println('   error ${i + 1}/${errors.len} for: `${ecmd}`')
	}
	exit(1)
}
