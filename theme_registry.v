module gui

import os

// theme_register adds a theme to the global registry
// by its name. Overwrites any existing entry with the
// same name.
pub fn theme_register(t Theme) {
	gui_theme_registry[t.name] = t
}

// theme_get retrieves a registered theme by name.
pub fn theme_get(name string) !Theme {
	return gui_theme_registry[name] or { return error('theme not found: ${name}') }
}

// theme_load_dir loads all *.json files from a directory
// and registers each as a theme.
pub fn theme_load_dir(dir string) ! {
	files := os.glob('${dir}/*.json') or { return error('cannot read dir: ${dir}') }
	for f in files {
		t := theme_load(f)!
		theme_register(t)
	}
}
