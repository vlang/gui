module gui

// gc.v provides GC safety helpers for the Boehm conservative collector.
// array.clear() only sets len=0 — it does NOT zero backing memory, so the GC
// scans stale pointer-sized words and causes false retention. array_clear() calls
// vmemset first to zero the full allocated block before resetting len.
// Use array_clear() for any array holding pointers or pointer-containing structs.

// array_clear resets an array's length to zero and zeros backing
// memory to prevent Boehm GC false retention from stale
// pointers. Use instead of .clear() for arrays containing
// pointers or types with pointer fields.
@[inline]
fn array_clear[T](mut a []T) {
	unsafe {
		vmemset(a.data, 0, a.cap * int(sizeof(T)))
		a.len = 0
	}
}

// layout_clear recursively zeros a Layout tree to prevent Boehm
// GC false retention of stale Shape and Layout pointers in the
// children backing arrays.
fn layout_clear(mut layout Layout) {
	for i in 0 .. layout.children.len {
		layout_clear(mut layout.children[i])
	}
	layout.shape = unsafe { nil }
	layout.parent = unsafe { nil }
	array_clear(mut layout.children)
}

// view_clear recursively zeros a View tree to prevent Boehm GC
// false retention of stale View interface pointers in the
// content backing arrays.
fn view_clear(mut view View) {
	for i in 0 .. view.content.len {
		view_clear(mut view.content[i])
	}
	array_clear(mut view.content)
}
