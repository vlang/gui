module gui

pub enum TextDirection as u8 {
	ltr
	rtl
}

pub struct NumberFormat {
pub:
	decimal_sep rune  = `.`
	group_sep   rune  = `,`
	group_sizes []int = [3]
	minus_sign  rune  = `-`
	plus_sign   rune  = `+`
}

pub struct DateFormat {
pub:
	short_date        string = 'M/D/YYYY'
	long_date         string = 'MMMM D, YYYY'
	month_year        string = 'MMMM YYYY'
	first_day_of_week u8 // 0=Sunday, 1=Monday
	use_24h           bool
}

pub struct CurrencyFormat {
pub:
	symbol   string               = '$'
	code     string               = 'USD'
	position NumericAffixPosition = .prefix
	spacing  bool
	decimals int = 2
}

pub struct Locale {
pub:
	id       string        = 'en-US'
	text_dir TextDirection = .ltr

	number   NumberFormat   = NumberFormat{}
	date     DateFormat     = DateFormat{}
	currency CurrencyFormat = CurrencyFormat{}

	// Dialog
	str_ok     string = 'OK'
	str_yes    string = 'Yes'
	str_no     string = 'No'
	str_cancel string = 'Cancel'

	// CRUD / common actions
	str_save   string = 'Save'
	str_delete string = 'Delete'
	str_add    string = 'Add'
	str_clear  string = 'Clear'
	str_search string = 'Search'
	str_filter string = 'Filter'
	str_jump   string = 'Jump'

	// Status
	str_loading         string = 'Loading...'
	str_loading_diagram string = 'Loading diagram...'
	str_saving          string = 'Saving...'
	str_save_failed     string = 'Save failed'
	str_load_error      string = 'Load error'
	str_error           string = 'Error'
	str_clean           string = 'Clean'

	// Data grid
	str_columns  string = 'Columns'
	str_selected string = 'Selected'
	str_draft    string = 'Draft'
	str_dirty    string = 'Dirty'
	str_matches  string = 'Matches'
	str_page     string = 'Page'
	str_rows     string = 'Rows'

	// Weekday names (0=Sun..6=Sat)
	weekdays_short [7]string = ['S', 'M', 'T', 'W', 'T', 'F', 'S']!
	weekdays_med   [7]string = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']!
	weekdays_full  [7]string = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
	'Saturday']!

	// Month names (0=Jan..11=Dec)
	months_short [12]string = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
	'Nov', 'Dec']!
	months_full  [12]string = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
	'September', 'October', 'November', 'December']!
}

pub fn (l Locale) to_numeric_locale() NumericLocaleCfg {
	return NumericLocaleCfg{
		decimal_sep: l.number.decimal_sep
		group_sep:   l.number.group_sep
		group_sizes: l.number.group_sizes
		minus_sign:  l.number.minus_sign
		plus_sign:   l.number.plus_sign
	}
}
