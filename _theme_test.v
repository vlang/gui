module gui

// ------------------------------
// Tests for theme.v (themes and helpers)
// ------------------------------

fn test_adjust_font_size_increase_within_bounds() {
	// Arrange
	old_theme := theme()
	cfg := old_theme.cfg
	base := cfg.text_style.size
	// Act
	if t := old_theme.adjust_font_size(2, 1, 200) {
		// Assert
		assert t.cfg.text_style.size == base + 2
		assert t.cfg.size_text_tiny == cfg.size_text_tiny + 2
		assert t.cfg.size_text_x_small == cfg.size_text_x_small + 2
		assert t.cfg.size_text_small == cfg.size_text_small + 2
		assert t.cfg.size_text_medium == cfg.size_text_medium + 2
		assert t.cfg.size_text_large == cfg.size_text_large + 2
		assert t.cfg.size_text_x_large == cfg.size_text_x_large + 2
	} else {
		assert false, 'adjust_font_size should not error for valid bounds'
	}
}

fn test_adjust_font_size_decrease_within_bounds() {
	old_theme := theme()
	cfg := old_theme.cfg
	base := cfg.text_style.size
	// Ensure min bound allows decreasing by 1
	if t := old_theme.adjust_font_size(-1, 1, 200) {
		assert t.cfg.text_style.size == base - 1
		assert t.cfg.size_text_small == cfg.size_text_small - 1
	} else {
		assert false, 'adjust_font_size should not error when decreasing within bounds'
	}
}

fn test_adjust_font_size_errors_on_invalid_min_size() {
	if _ := theme().adjust_font_size(0, 0, 10) {
		assert false, 'Expected error when min_size < 1'
	} else {
		// Check error message
		// Note: V error messages are strings; match key phrase
		// Casting err to string is implicit in assertion via interpolation
		// but we just ensure it contains the expected text.
		// Can't access err here directly in test, so just rely on error returned.
		// If control reaches else, it means there was an error as expected.
		assert true
	}
}

fn test_adjust_font_size_errors_on_out_of_range() {
	old_theme := theme()
	cfg := old_theme.cfg
	s := cfg.text_style.size
	// Set min greater than current size so new size (delta 0) is out of range
	if _ := old_theme.adjust_font_size(0, s + 1, s + 10) {
		assert false, 'Expected out-of-range error when new size < min_size'
	} else {
		assert true
	}
}

fn test_theme_maker_applies_cfg_and_invariants() {
	// Build a custom cfg with distinct values
	custom_cfg := ThemeCfg{
		name:               'unit-test-theme'
		color_background:   white
		color_panel:        purple
		color_interior:     red
		color_hover:        green
		color_focus:        yellow
		color_active:       magenta
		color_border:       blue
		color_border_focus: cyan
		color_select:       orange
		titlebar_dark:      true
		// Ensure dialog title uses this "large" size
		size_text_large: 22
		text_style:      TextStyle{
			color:        black
			size:         17
			family:       base_font_name
			line_spacing: text_line_spacing
		}
	}

	t := theme_maker(&custom_cfg)

	// Top-level fields match
	assert t.name == 'unit-test-theme'
	assert t.color_background == white
	assert t.color_panel == purple
	assert t.color_interior == red
	assert t.color_hover == green
	assert t.color_focus == yellow
	assert t.color_active == magenta
	assert t.color_border == blue
	assert t.color_select == orange
	assert t.titlebar_dark

	// Container invariant: transparent color
	assert t.container_style.color == color_transparent
	// Padding/radius/spacings derived from cfg defaults
	assert t.container_style.padding == custom_cfg.padding
	assert t.container_style.radius == custom_cfg.radius

	// Button style picks key colors and radius's
	assert t.button_style.color == red
	assert t.button_style.color_border == blue
	assert t.button_style.color_hover == green
	assert t.button_style.color_focus == magenta
	assert t.button_style.color_click == yellow
	assert t.button_style.radius == custom_cfg.radius
	assert t.button_style.radius_border == custom_cfg.radius_border

	// Dialog title size should use size_text_large from cfg
	assert t.dialog_style.title_text_style.size == 22

	// Text styles propagate
	assert t.input_style.text_style.size == 17
	assert t.input_style.text_style.color == black
}

fn test_theme_returns_current_theme() {
	// theme() should return the current global theme value
	t := theme()
	// Sanity checks: non-empty name and cfg consistency
	assert t.name.len > 0
	assert t.cfg.name == t.name
	// Ensure some styles and colors are set sensibly
	assert t.text_style.size > 0
	assert t.color_interior.r >= 0 // basic access test for Color
}
