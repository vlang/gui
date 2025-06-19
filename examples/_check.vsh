#!/usr/bin/env -S v

unbuffer_stdout()

dir_files := ls(dir(@FILE)) or { [] }.map(join_path_single(dir(@FILE), it))
files := dir_files.filter(file_ext(it) == '.v').sorted()
if files.len == 0 {
	println('no .v files found')
	return
}
mut errors := []string{}
for i, file in files {
	p := 'v -check ${file} '
	print('(${i + 1:02}/${files.len:02}) ${p:-70}')
	result := execute('v -check ${file}')
	if result.exit_code == 0 {
		println(' ✅')
	} else {
		println(' ⭕')
		println(result.output)
		errors << file
	}
}
if errors.len > 0 {
	println('Encountered ${errors.len} error(s).')
	for i, efile in errors {
		println('   error ${i + 1}/${errors.len} for: `v -check ${efile}`')
	}
	exit(1)
}
