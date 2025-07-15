#!/usr/bin/env -S v

unbuffer_stdout()
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

dir_files := ls('.') or { [] }.map(join_path_single(@DIR, it))
files := dir_files.filter(file_ext(it) == '.v').sorted()
if files.len == 0 {
	println('no .v files found')
	return
}

mut errors := []string{}
for file in files {
	_, name, _ := split_path(file)
	output_file := join_path(output_dir, name)
	cmd := 'v -no-parallel -prod -o ${output_file:-22s} ${file:-50s}'
	print(cmd)
	result := execute(cmd)
	if result.exit_code == 0 {
		println('\t✅')
	} else {
		println('\t⭕')
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
