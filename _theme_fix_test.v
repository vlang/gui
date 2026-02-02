module gui

fn test_toggle_radius_override() {
	// Create a theme config with specific radius
	cfg := ThemeCfg{
		name:          'test_toggle'
		radius:        10.0
		radius_border: 12.0
	}

	theme := theme_maker(cfg)

	// Verify toggle style picked up the config values
	// (Prior to fix, this would have been 3.5 or 0 based on logic, ignoring the 10.0)
	assert theme.toggle_style.radius == 10.0
	assert theme.toggle_style.radius_border == 12.0
}
