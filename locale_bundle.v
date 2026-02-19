module gui

import json
import os

// JSON-friendly intermediate structs for locale bundle decoding.
// String types used where Locale uses rune/enum so json.decode
// works directly.

struct NumberBundle {
	decimal_sep string
	group_sep   string
	group_sizes []int
	minus_sign  string
	plus_sign   string
}

struct DateBundle {
	short_date        string
	long_date         string
	month_year        string
	first_day_of_week int = -1
	use_24h           ?bool
}

struct CurrencyBundle {
	symbol   string
	code     string
	position string
	spacing  ?bool
	decimals int = -1
}

struct LocaleBundle {
	id             string
	text_dir       string
	number         ?NumberBundle
	date           ?DateBundle
	currency       ?CurrencyBundle
	strings        map[string]string
	weekdays_short []string
	weekdays_med   []string
	weekdays_full  []string
	months_short   []string
	months_full    []string
	translations   map[string]string
}

// locale_parse decodes a JSON string into a Locale struct.
// Missing keys fall back to en-US defaults.
pub fn locale_parse(content string) !Locale {
	bundle := json.decode(LocaleBundle, content) or { return error('invalid JSON: ${err}') }
	return bundle.to_locale()
}

// locale_load reads a JSON bundle file and returns a Locale.
pub fn locale_load(path string) !Locale {
	content := os.read_file(path) or { return error('cannot read file: ${path}') }
	return locale_parse(content)
}

fn (b LocaleBundle) to_locale() Locale {
	d := Locale{}
	return Locale{
		id:       if b.id.len > 0 { b.id } else { d.id }
		text_dir: parse_text_dir(b.text_dir)
		number:   b.to_number_format(d.number)
		date:     b.to_date_format(d.date)
		currency: b.to_currency_format(d.currency)
		// Dialog
		str_ok:     str_or(b.strings, 'ok', d.str_ok)
		str_yes:    str_or(b.strings, 'yes', d.str_yes)
		str_no:     str_or(b.strings, 'no', d.str_no)
		str_cancel: str_or(b.strings, 'cancel', d.str_cancel)
		// CRUD / common actions
		str_save:   str_or(b.strings, 'save', d.str_save)
		str_delete: str_or(b.strings, 'delete', d.str_delete)
		str_add:    str_or(b.strings, 'add', d.str_add)
		str_clear:  str_or(b.strings, 'clear', d.str_clear)
		str_search: str_or(b.strings, 'search', d.str_search)
		str_filter: str_or(b.strings, 'filter', d.str_filter)
		str_jump:   str_or(b.strings, 'jump', d.str_jump)
		str_reset:  str_or(b.strings, 'reset', d.str_reset)
		str_submit: str_or(b.strings, 'submit', d.str_submit)
		// Status
		str_loading:         str_or(b.strings, 'loading', d.str_loading)
		str_loading_diagram: str_or(b.strings, 'loading_diagram', d.str_loading_diagram)
		str_saving:          str_or(b.strings, 'saving', d.str_saving)
		str_save_failed:     str_or(b.strings, 'save_failed', d.str_save_failed)
		str_load_error:      str_or(b.strings, 'load_error', d.str_load_error)
		str_error:           str_or(b.strings, 'error', d.str_error)
		str_clean:           str_or(b.strings, 'clean', d.str_clean)
		// Data grid
		str_columns:  str_or(b.strings, 'columns', d.str_columns)
		str_selected: str_or(b.strings, 'selected', d.str_selected)
		str_draft:    str_or(b.strings, 'draft', d.str_draft)
		str_dirty:    str_or(b.strings, 'dirty', d.str_dirty)
		str_matches:  str_or(b.strings, 'matches', d.str_matches)
		str_page:     str_or(b.strings, 'page', d.str_page)
		str_rows:     str_or(b.strings, 'rows', d.str_rows)
		// Arrays
		weekdays_short: to_fixed_7(b.weekdays_short, d.weekdays_short)
		weekdays_med:   to_fixed_7(b.weekdays_med, d.weekdays_med)
		weekdays_full:  to_fixed_7(b.weekdays_full, d.weekdays_full)
		months_short:   to_fixed_12(b.months_short, d.months_short)
		months_full:    to_fixed_12(b.months_full, d.months_full)
		// App translations
		translations: b.translations.clone()
	}
}

fn (b LocaleBundle) to_number_format(d NumberFormat) NumberFormat {
	nb := b.number or { return d }
	return NumberFormat{
		decimal_sep: first_rune(nb.decimal_sep, d.decimal_sep)
		group_sep:   first_rune(nb.group_sep, d.group_sep)
		group_sizes: if nb.group_sizes.len > 0 {
			nb.group_sizes
		} else {
			d.group_sizes
		}
		minus_sign:  first_rune(nb.minus_sign, d.minus_sign)
		plus_sign:   first_rune(nb.plus_sign, d.plus_sign)
	}
}

fn (b LocaleBundle) to_date_format(d DateFormat) DateFormat {
	db := b.date or { return d }
	return DateFormat{
		short_date:        if db.short_date.len > 0 {
			db.short_date
		} else {
			d.short_date
		}
		long_date:         if db.long_date.len > 0 {
			db.long_date
		} else {
			d.long_date
		}
		month_year:        if db.month_year.len > 0 {
			db.month_year
		} else {
			d.month_year
		}
		first_day_of_week: if db.first_day_of_week >= 0 {
			u8(db.first_day_of_week)
		} else {
			d.first_day_of_week
		}
		use_24h:           if v := db.use_24h { v } else { d.use_24h }
	}
}

fn (b LocaleBundle) to_currency_format(d CurrencyFormat) CurrencyFormat {
	cb := b.currency or { return d }
	return CurrencyFormat{
		symbol:   if cb.symbol.len > 0 { cb.symbol } else { d.symbol }
		code:     if cb.code.len > 0 { cb.code } else { d.code }
		position: parse_affix_position(cb.position, d.position)
		spacing:  if v := cb.spacing { v } else { d.spacing }
		decimals: if cb.decimals >= 0 { cb.decimals } else { d.decimals }
	}
}

fn str_or(m map[string]string, key string, fallback string) string {
	return m[key] or { fallback }
}

fn to_fixed_7(src []string, fallback [7]string) [7]string {
	if src.len != 7 {
		return fallback
	}
	mut out := [7]string{}
	for i in 0 .. 7 {
		out[i] = src[i]
	}
	return out
}

fn to_fixed_12(src []string, fallback [12]string) [12]string {
	if src.len != 12 {
		return fallback
	}
	mut out := [12]string{}
	for i in 0 .. 12 {
		out[i] = src[i]
	}
	return out
}

fn parse_text_dir(s string) TextDirection {
	return match s {
		'ltr' { .ltr }
		'rtl' { .rtl }
		else { .auto }
	}
}

fn parse_affix_position(s string, fallback NumericAffixPosition) NumericAffixPosition {
	return match s {
		'prefix' { .prefix }
		'suffix' { .suffix }
		else { fallback }
	}
}

fn first_rune(s string, fallback rune) rune {
	if s.len == 0 {
		return fallback
	}
	return s.runes()[0]
}
