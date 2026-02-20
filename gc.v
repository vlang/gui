module gui

// gc.v provides GC safety helpers for the Boehm conservative collector.
// array.clear() only sets len=0 — it does NOT zero backing memory, so the GC
// scans stale pointer-sized words and causes false retention. gc_clear() calls
// vmemset first to zero the full allocated block before resetting len.
// Use gc_clear() for any array holding pointers or pointer-containing structs.

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
