module gui

fn test_bounded_stack_push_pop() {
	mut stack := BoundedStack[int]{
		max_size: 3
	}
	stack.push(1)
	stack.push(2)
	stack.push(3)

	assert stack.len() == 3
	assert stack.pop()? == 3
	assert stack.pop()? == 2
	assert stack.pop()? == 1
	assert stack.is_empty()
}

fn test_bounded_stack_overflow_evicts_oldest() {
	mut stack := BoundedStack[int]{
		max_size: 3
	}
	stack.push(1)
	stack.push(2)
	stack.push(3)
	stack.push(4) // should evict 1

	assert stack.len() == 3
	assert stack.pop()? == 4
	assert stack.pop()? == 3
	assert stack.pop()? == 2
	assert stack.pop() == none
}

fn test_bounded_stack_pop_empty() {
	mut stack := BoundedStack[int]{
		max_size: 3
	}
	assert stack.pop() == none
	assert stack.is_empty()
}

fn test_bounded_stack_clear() {
	mut stack := BoundedStack[int]{
		max_size: 3
	}
	stack.push(1)
	stack.push(2)
	stack.clear()
	assert stack.is_empty()
	assert stack.len() == 0
}

fn test_bounded_stack_default_size() {
	stack := BoundedStack[int]{}
	assert stack.max_size == 50
}

fn test_bounded_stack_many_pushes() {
	mut stack := BoundedStack[int]{
		max_size: 5
	}
	for i in 0 .. 100 {
		stack.push(i)
	}
	// should only have last 5: 95,96,97,98,99
	assert stack.len() == 5
	assert stack.pop()? == 99
	assert stack.pop()? == 98
	assert stack.pop()? == 97
	assert stack.pop()? == 96
	assert stack.pop()? == 95
}
