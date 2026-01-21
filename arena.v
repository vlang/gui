module gui

// LayoutArena provides frame-scoped memory for Shape structs.
// Reset at the start of each frame in do_update_window().
struct LayoutArena {
mut:
	shapes     []Shape // backing storage
	next_index int     // next available slot
}

// reset prepares the arena for a new frame. Does not deallocate memory,
// allowing stable layouts to reuse capacity.
fn (mut a LayoutArena) reset() {
	a.next_index = 0
}

// alloc_shape returns a zeroed Shape from the arena. Grows backing storage
// if needed.
fn (mut a LayoutArena) alloc_shape() &Shape {
	if a.next_index >= a.shapes.len {
		a.shapes << Shape{}
	}
	idx := a.next_index
	a.next_index++
	a.shapes[idx] = Shape{}
	return &a.shapes[idx]
}
