#!/usr/bin/env -S v

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
	cmd := 'v -check -N -W ${file}'
	print('(${i + 1:02}/${files.len:02}) ${cmd:-70}')
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
