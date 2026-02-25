#!/usr/bin/env -S v

fn sh(cmd string) {
	println('❯ ${cmd}')
	print(execute_or_exit(cmd).output)
}

unbuffer_stdout()
chdir(@DIR)!

sh('v fmt -w .')
sh('v run examples/_check.vsh')
sh('v test .')
sh('v check-md -w .')
