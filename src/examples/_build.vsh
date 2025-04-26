#!/usr/bin/env -S v

output_dir := 'bin'
if exists(output_dir) {
	bin_files := ls(output_dir) or { [] }
	for file in bin_files {
		file_path := join_path(output_dir, file)
		if is_file(file_path) {
			rm(file_path) or {
				println(err)
				continue
			}
			println('Deleted: ${file_path}')
		}
	}
} else {
	mkdir(output_dir) or {
		println(err)
		return
	}
}

dir_files := ls('.') or { [] }
files := dir_files.filter(file_ext(it) == '.v').sorted()
if files.len == 0 {
	println('no .v files found')
	return
}

for file in files {
	_, name, _ := split_path(file)
	output_file := join_path(output_dir, name)
	println('v -prod ${file} -> ${output_file}')
	result := execute('v -prod -o ${output_file} ${file}')
	if result.exit_code != 0 {
		println(result.output)
		return
	}
}
