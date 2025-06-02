#!/usr/bin/env -S v

chdir(dir(@FILE))!
unbuffer_stdout()

dir_files := ls('.') or { [] }
files := dir_files.filter(file_ext(it) == '.v').sorted()
if files.len == 0 {
	println('no .v files found')
	return
}
for i, file in files {
	p := 'v -check ${file} '
	print('(${i + 1:02}/${files.len:02}) ${p:-30}')
	result := execute('v -check ${file}')
	if result.exit_code == 0 {
		println(' ✅')
	} else {
		println(' ⭕')
		println(result.output)
		return
	}
}
