module gui

import time

// locale_fmt replaces {key} placeholders in a template string.
pub fn locale_fmt(template string, params map[string]string) string {
	mut result := template
	for key, val in params {
		result = result.replace('{${key}}', val)
	}
	return result
}

// locale_format_date formats a date using locale-aware month
// substitution. MMMM → full month, MMM → short month.
// Other tokens delegated to time.Time.custom_format().
//
// Month tokens are replaced with placeholders before calling
// custom_format so that characters in month names (e.g. the
// 'M' in "March") are not reinterpreted as format tokens.
pub fn locale_format_date(t time.Time, fmt string) string {
	month_idx := t.month - 1
	if month_idx < 0 || month_idx >= 12 {
		return t.custom_format(fmt)
	}
	mut result := fmt
	mut has_full := result.contains('MMMM')
	mut has_short := !has_full && result.contains('MMM')
	if has_full {
		result = result.replace('MMMM', '\x01\x01\x01\x01')
	} else if has_short {
		result = result.replace('MMM', '\x01\x01\x01')
	}
	result = t.custom_format(result)
	if has_full {
		result = result.replace('\x01\x01\x01\x01', gui_locale.months_full[month_idx])
	} else if has_short {
		result = result.replace('\x01\x01\x01', gui_locale.months_short[month_idx])
	}
	return result
}

// locale_rows_fmt formats "Rows start-end/total".
fn locale_rows_fmt(start int, end int, total int) string {
	return '${gui_locale.str_rows} ${start}-${end}/${total}'
}

// locale_page_fmt formats "Page current/total".
fn locale_page_fmt(page int, total int) string {
	return '${gui_locale.str_page} ${page}/${total}'
}

// locale_matches_fmt formats "Matches count/total".
fn locale_matches_fmt(count int, total string) string {
	return '${gui_locale.str_matches} ${count}/${total}'
}
