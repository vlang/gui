// Starting the filename with _ causes it to be
// parsed first. V is working on this issue but
// it may be sometime before it is resolved.
//
@[has_globals]
module gui

__global gui_theme = theme_dark_no_padding
__global gui_locale = Locale{}

pub const version = '0.1.0'
pub const app_title = 'v-gui'
