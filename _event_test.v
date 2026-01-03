module gui

fn test_modifier_has() {
	// none
	assert Modifier.none.has(.none)
	assert !Modifier.none.has(.shift)

	// single modifier
	assert Modifier.shift.has(.shift)
	assert !Modifier.shift.has(.ctrl)

	// combined bitmask
	unsafe {
		combined := Modifier(u32(Modifier.shift) | u32(Modifier.ctrl))
		assert combined.has(.shift)
		assert combined.has(.ctrl)
		assert !combined.has(.alt)
	}
}

fn test_modifier_has_any() {
	assert Modifier.none.has_any(.none)
	assert !Modifier.none.has_any(.shift)
	assert Modifier.shift.has_any(.shift)
	assert !Modifier.shift.has_any(.ctrl, .alt)
	unsafe {
		assert Modifier(u32(Modifier.shift) | u32(Modifier.ctrl)).has_any(.shift)
		assert Modifier(u32(Modifier.shift) | u32(Modifier.ctrl)).has_any(.ctrl)
		assert Modifier(u32(Modifier.shift) | u32(Modifier.ctrl)).has_any(.shift, .alt)
	}
}
