module gui

import os

fn init() {
	locale_register(locale_en_us)
	locale_register(locale_de_de)
	locale_register(locale_ar_sa)
	theme_register(theme_dark)
	theme_register(theme_dark_no_padding)
	theme_register(theme_dark_bordered)
	theme_register(theme_light)
	theme_register(theme_light_no_padding)
	theme_register(theme_light_bordered)
	theme_register(theme_blue_bordered)
}

// locale_register adds a locale to the global registry
// by its id. Overwrites any existing entry with the same id.
pub fn locale_register(locale Locale) {
	gui_locale_registry[locale.id] = locale
}

// locale_get retrieves a registered locale by id.
pub fn locale_get(id string) !Locale {
	return gui_locale_registry[id] or { return error('locale not found: ${id}') }
}

// locale_load_dir loads all *.json files from a directory
// and registers each as a locale.
pub fn locale_load_dir(dir string) ! {
	files := os.glob('${dir}/*.json') or { return error('cannot read dir: ${dir}') }
	for f in files {
		locale := locale_load(f)!
		locale_register(locale)
	}
}
