module gui

// AccessRole identifies a shape's semantic role for assistive
// technology. Maps 1:1 to NSAccessibilityRole (macOS) and
// UIA Control Type (Windows). Zero value .none means the shape
// is invisible to the accessibility tree.
pub enum AccessRole as u8 {
	none
	button
	checkbox
	color_well
	combo_box
	date_field
	dialog
	disclosure
	grid
	grid_cell
	group
	heading
	image
	link
	list
	list_item
	menu
	menu_bar
	menu_item
	progress_bar
	radio_button
	radio_group
	scroll_area
	scroll_bar
	slider
	splitter
	static_text
	switch_toggle
	tab
	tab_item
	text_field
	text_area
	toolbar
	tree
	tree_item
}

// AccessState is a bitmask of dynamic accessibility states.
// Follows the Modifier pattern from event.v. Uses u16 to
// save space; disabled is excluded because Shape.disabled
// already exists.
pub enum AccessState as u16 {
	none      = 0
	expanded  = 1   // disclosure/expand_panel open
	selected  = 2   // tab, list item, menu item
	checked   = 4   // toggle, checkbox
	required  = 8   // form validation
	invalid   = 16  // form validation error
	busy      = 32  // async loading / progress
	read_only = 64  // non-editable text field
	modal     = 128 // dialog
}

// has checks if the state bitmask contains the given flag.
pub fn (s AccessState) has(flag AccessState) bool {
	return u16(s) & u16(flag) > 0 || s == flag
}

// AccessInfo holds string and numeric accessibility data.
// Heap-allocated, nil on Shape when unused. Same lazy-alloc
// pattern as EventHandlers / ShapeTextConfig / ShapeEffects.
@[heap]
pub struct AccessInfo {
pub mut:
	label         string // primary screen-reader label
	description   string // extended help text
	value_text    string // current value as text (live buffer)
	value_num     f32    // numeric value (slider, progress)
	value_min     f32    // range minimum
	value_max     f32    // range maximum
	heading_level u8     // 1-6 for headings, 0 otherwise
}

// has_a11y returns true if the shape has allocated AccessInfo.
@[inline]
pub fn (shape &Shape) has_a11y() bool {
	return shape.a11y != unsafe { nil }
}

// make_a11y_info creates an AccessInfo with label and
// description, returning nil when both are empty.
fn make_a11y_info(label string, description string) &AccessInfo {
	if label.len > 0 || description.len > 0 {
		return &AccessInfo{
			label:       label
			description: description
		}
	}
	return unsafe { nil }
}

// a11y_label returns the effective label: explicit a11y_label
// if set, otherwise the fallback.
fn a11y_label(a11y_label string, fallback string) string {
	if a11y_label.len > 0 {
		return a11y_label
	}
	return fallback
}
