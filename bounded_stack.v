module gui

// BoundedStack is a stack with maximum size. When full, oldest entries are
// dropped (FIFO eviction). Used for undo/redo to prevent unbounded memory.
struct BoundedStack[T] {
mut:
	elements []T
	max_size int = 50
}

// push adds element to stack. Drops oldest if at capacity.
fn (mut s BoundedStack[T]) push(elem T) {
	if s.elements.len >= s.max_size {
		s.elements.delete(0)
	}
	s.elements << elem
}

// pop removes and returns top element. Returns none if empty.
fn (mut s BoundedStack[T]) pop() ?T {
	if s.elements.len == 0 {
		return none
	}
	elem := s.elements.last()
	s.elements.delete(s.elements.len - 1)
	return elem
}

// len returns number of elements in stack.
fn (s &BoundedStack[T]) len() int {
	return s.elements.len
}

// is_empty returns true if stack has no elements.
fn (s &BoundedStack[T]) is_empty() bool {
	return s.elements.len == 0
}

// clear removes all elements from stack.
fn (mut s BoundedStack[T]) clear() {
	s.elements.clear()
}
