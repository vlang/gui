module gui

struct QueueTestState {
mut:
	count int
}

fn test_flush_commands_runs_all_and_clears() {
	mut state := &QueueTestState{}
	mut w := Window{
		state: state
	}
	w.commands_mutex.lock()
	w.commands << fn (mut win Window) {
		mut s := win.state[QueueTestState]()
		s.count++
	}
	w.commands << fn (mut win Window) {
		mut s := win.state[QueueTestState]()
		s.count++
	}
	w.commands_mutex.unlock()

	w.flush_commands()

	assert state.count == 2
	assert w.commands.len == 0
}

fn test_flush_commands_empty_queue_is_noop() {
	mut w := Window{}
	w.flush_commands()
	assert w.commands.len == 0
}
