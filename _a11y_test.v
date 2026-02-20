module gui

// Unit tests for AccessState bitfield, AccessRole enum,
// AccessInfo nil guard, and make_a11y helpers.

fn test_access_state_has_single_flag() {
	s := AccessState.checked
	assert s.has(.checked)
	assert !s.has(.expanded)
	assert !s.has(.selected)
}

fn test_access_state_has_none() {
	s := AccessState.none
	assert s.has(.none)
	assert !s.has(.checked)
}

fn test_access_state_has_combined() {
	s := unsafe { AccessState(u16(AccessState.checked) | u16(AccessState.selected)) }
	assert s.has(.checked)
	assert s.has(.selected)
	assert !s.has(.expanded)
	assert !s.has(.modal)
}

fn test_access_state_all_flags_distinct() {
	flags := [
		AccessState.expanded,
		AccessState.selected,
		AccessState.checked,
		AccessState.required,
		AccessState.invalid,
		AccessState.busy,
		AccessState.read_only,
		AccessState.modal,
		AccessState.live,
	]
	for i, a in flags {
		for j, b in flags {
			if i != j {
				assert u16(a) & u16(b) == 0, '${a} and ${b} overlap'
			}
		}
	}
}

fn test_access_role_none_is_zero() {
	assert u8(AccessRole.none) == 0
}

fn test_access_role_values_fit_u8() {
	// Ensure the last enum value fits in u8.
	assert u8(AccessRole.tree_item) < 255
}

fn test_access_role_count() {
	// 35 roles per plan (none + 34 named)
	assert u8(AccessRole.tree_item) == 34
}

fn test_has_a11y_nil() {
	s := Shape{}
	assert !s.has_a11y()
}

fn test_has_a11y_allocated() {
	s := Shape{
		a11y: &AccessInfo{
			label: 'test'
		}
	}
	assert s.has_a11y()
	assert s.a11y.label == 'test'
}

fn test_make_a11y_info_both_empty() {
	info := make_a11y_info('', '')
	assert info == unsafe { nil }
}

fn test_make_a11y_info_label_only() {
	info := make_a11y_info('Save', '')
	assert info != unsafe { nil }
	assert info.label == 'Save'
	assert info.description == ''
}

fn test_make_a11y_info_both_set() {
	info := make_a11y_info('Save', 'Save changes to disk')
	assert info != unsafe { nil }
	assert info.label == 'Save'
	assert info.description == 'Save changes to disk'
}

fn test_a11y_label_override() {
	// Explicit a11y_label takes priority over fallback
	result := a11y_label('Custom', 'Fallback')
	assert result == 'Custom'
}

fn test_a11y_label_fallback() {
	// Empty a11y_label falls back
	result := a11y_label('', 'Fallback')
	assert result == 'Fallback'
}

fn test_a11y_label_both_empty() {
	result := a11y_label('', '')
	assert result == ''
}

// --- Shape role defaults ---

fn test_shape_default_role_none() {
	s := Shape{}
	assert s.a11y_role == .none
}

fn test_shape_default_state_none() {
	s := Shape{}
	assert s.a11y_state == .none
}

fn test_access_info_defaults() {
	info := AccessInfo{}
	assert info.label == ''
	assert info.description == ''
	assert info.value_text == ''
	assert info.value_num == 0.0
	assert info.value_min == 0.0
	assert info.value_max == 0.0
	assert info.heading_level == 0
}
