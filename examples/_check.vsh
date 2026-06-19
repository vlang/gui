#!/usr/bin/env -S v

import os

unbuffer_stdout()
chdir(@DIR)!

dir_files := ls(@DIR) or { [] }.map(join_path_single(@DIR, it))
files := dir_files.filter(file_ext(it) == '.v').sorted()
if files.len == 0 {
	println('no .v files found')
	return
}
mut errors := []string{}
for i, file in files {
	if os.file_name(file) == 'showcase.v' {
		println('(${i + 1:02}/${files.len:02}) Skipping showcase.v syntax lint; it is covered by compilation checks.')
		continue
	}
	cmd := 'v -check -N -W ${file}'
	dsp := 'v -check -N -W ${os.file_name(file)}'
	print('(${i + 1:02}/${files.len:02}) ${dsp:-40}')
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
