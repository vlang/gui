module gui

// gc_clear resets an array's length to zero and zeros backing
// memory to prevent Boehm GC false retention from stale
// pointers. Use instead of .clear() for arrays containing
// pointers or types with pointer fields.
@[inline]
fn gc_clear[T](mut a []T) {
	unsafe {
		vmemset(a.data, 0, a.cap * int(sizeof(T)))
		a.len = 0
	}
}
