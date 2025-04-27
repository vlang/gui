#!/usr/bin/env -S v

dir_files := ls('.') or { [] }
files := dir_files.filter(file_ext(it) == '.v').sorted()
if files.len == 0 {
	println('no .v files found')
	return
}
for file in files {
	p := 'v -check ${file} '
	print('${p:-30}')
	flush()
	result := execute('v -check ${file}')
	if result.exit_code == 0 {
		println(' ✅')
	} else {
		println(' ⭕')
		println(result.output)
		return
	}
}
