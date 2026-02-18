module gui

pub const locale_en_us = Locale{}

pub const locale_de_de = Locale{
	id: 'de-DE'

	number: NumberFormat{
		decimal_sep: `,`
		group_sep:   `.`
		group_sizes: [3]
		minus_sign:  `-`
		plus_sign:   `+`
	}

	date: DateFormat{
		short_date:        'D.M.YYYY'
		long_date:         'D. MMMM YYYY'
		month_year:        'MMMM YYYY'
		first_day_of_week: 1
	}

	currency: CurrencyFormat{
		symbol:   '€'
		code:     'EUR'
		position: .suffix
		spacing:  true
		decimals: 2
	}

	str_ok:     'OK'
	str_yes:    'Ja'
	str_no:     'Nein'
	str_cancel: 'Abbrechen'

	str_save:   'Speichern'
	str_delete: 'Löschen'
	str_add:    'Hinzufügen'
	str_clear:  'Löschen'
	str_search: 'Suche'
	str_filter: 'Filter'
	str_jump:   'Springen'

	str_loading:         'Laden...'
	str_loading_diagram: 'Diagramm laden...'
	str_saving:          'Speichern...'
	str_save_failed:     'Speichern fehlgeschlagen'
	str_load_error:      'Ladefehler'
	str_error:           'Fehler'
	str_clean:           'Sauber'

	str_columns:  'Spalten'
	str_selected: 'Ausgewählt'
	str_draft:    'Entwurf'
	str_dirty:    'Geändert'
	str_matches:  'Treffer'
	str_page:     'Seite'
	str_rows:     'Zeilen'

	weekdays_short: ['S', 'M', 'D', 'M', 'D', 'F', 'S']!
	weekdays_med:   ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa']!
	weekdays_full:  ['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag']!

	months_short: ['Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov',
		'Dez']!
	months_full:  ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August',
		'September', 'Oktober', 'November', 'Dezember']!
}
