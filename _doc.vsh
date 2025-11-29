#!/usr/bin/env -S v

fn sh(cmd string) {
	println('❯ ${cmd}')
	print(execute_or_exit(cmd).output)
}

unbuffer_stdout()
chdir(@DIR)!
sh('v doc -f html -inline-assets -readme -o ./doc/html .')
mkdir_all('doc/html/assets')!
cp('assets/get-started.png', 'doc/html/assets') or {}
cp('assets/showcase.png', 'doc/html/assets') or {}
