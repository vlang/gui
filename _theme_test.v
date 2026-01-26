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

// ------------------------------
// Tests for with_* theme modification methods
// ------------------------------

fn test_with_button_style() {
	t := theme_dark
	new_style := ButtonStyle{
		...t.button_style
		color:       red
		color_hover: green
	}
	modified := t.with_button_style(new_style)

	// Button style should be updated
	assert modified.button_style.color == red
	assert modified.button_style.color_hover == green
	// Other styles should remain unchanged
	assert modified.input_style == t.input_style
	assert modified.name == t.name
}

fn test_with_input_style() {
	t := theme_dark
	new_style := InputStyle{
		...t.input_style
		color:        blue
		color_border: yellow
	}
	modified := t.with_input_style(new_style)

	assert modified.input_style.color == blue
	assert modified.input_style.color_border == yellow
	// Button style unchanged
	assert modified.button_style == t.button_style
}

fn test_with_colors_single_override() {
	t := theme_dark
	new_hover := rgb(200, 100, 50)
	modified := t.with_colors(ColorOverrides{
		color_hover: new_hover
	})

	// Top-level color should be updated
	assert modified.color_hover == new_hover
	// Widget styles should have new hover color
	assert modified.button_style.color_hover == new_hover
	assert modified.input_style.color_hover == new_hover
	assert modified.select_style.color_hover == new_hover
	// Non-overridden colors should remain
	assert modified.color_background == t.color_background
	assert modified.color_panel == t.color_panel
}

fn test_with_colors_multiple_overrides() {
	t := theme_dark
	new_interior := rgb(50, 50, 80)
	new_border := rgb(100, 100, 150)
	new_select := rgb(80, 120, 200)

	modified := t.with_colors(ColorOverrides{
		color_interior: new_interior
		color_border:   new_border
		color_select:   new_select
	})

	// Top-level colors updated
	assert modified.color_interior == new_interior
	assert modified.color_border == new_border
	assert modified.color_select == new_select

	// Widget styles updated
	assert modified.button_style.color == new_interior
	assert modified.button_style.color_border == new_border
	assert modified.list_box_style.color_select == new_select
}

fn test_with_colors_no_overrides() {
	t := theme_dark
	modified := t.with_colors(ColorOverrides{})

	// With no overrides, theme should be functionally identical
	assert modified.color_background == t.color_background
	assert modified.color_hover == t.color_hover
	assert modified.button_style.color_hover == t.button_style.color_hover
}

fn test_chained_modifications() {
	t := theme_dark

	// Chain multiple with_* calls
	modified := t
		.with_button_style(ButtonStyle{
			...t.button_style
			color: red
		})
		.with_input_style(InputStyle{
			...t.input_style
			color: blue
		})

	assert modified.button_style.color == red
	assert modified.input_style.color == blue
	// Other styles unchanged
	assert modified.select_style == t.select_style
}
