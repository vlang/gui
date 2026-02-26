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
	str_reset:  'Zurücksetzen'
	str_submit: 'Absenden'

	str_loading:         'Laden...'
	str_loading_diagram: 'Diagramm laden...'
	str_saving:          'Speichern...'
	str_save_failed:     'Speichern fehlgeschlagen'
	str_load_error:      'Ladefehler'
	str_error:           'Fehler'
	str_clean:           'Sauber'

	str_open_link:    'Link öffnen'
	str_go_to_target: 'Zum Ziel'
	str_copy_link:    'Link kopieren'

	str_horizontal_scrollbar: 'Horizontale Bildlaufleiste'
	str_vertical_scrollbar:   'Vertikale Bildlaufleiste'

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

pub const locale_ar_sa = Locale{
	id:       'ar-SA'
	text_dir: .rtl

	number: NumberFormat{
		decimal_sep: `.`
		group_sep:   `,`
		group_sizes: [3]
		minus_sign:  `-`
		plus_sign:   `+`
	}

	date: DateFormat{
		short_date:        'D/M/YYYY'
		long_date:         'D MMMM YYYY'
		month_year:        'MMMM YYYY'
		first_day_of_week: 6 // Saturday
	}

	currency: CurrencyFormat{
		symbol:   'ر.س'
		code:     'SAR'
		position: .suffix
		spacing:  true
		decimals: 2
	}

	str_ok:     'موافق'
	str_yes:    'نعم'
	str_no:     'لا'
	str_cancel: 'إلغاء'

	str_save:   'حفظ'
	str_delete: 'حذف'
	str_add:    'إضافة'
	str_clear:  'مسح'
	str_search: 'بحث'
	str_filter: 'تصفية'
	str_jump:   'انتقال'
	str_reset:  'إعادة تعيين'
	str_submit: 'إرسال'

	str_loading:         'جارٍ التحميل...'
	str_loading_diagram: 'جارٍ تحميل المخطط...'
	str_saving:          'جارٍ الحفظ...'
	str_save_failed:     'فشل الحفظ'
	str_load_error:      'خطأ في التحميل'
	str_error:           'خطأ'
	str_clean:           'نظيف'

	str_open_link:    'فتح الرابط'
	str_go_to_target: 'الذهاب إلى الهدف'
	str_copy_link:    'نسخ الرابط'

	str_horizontal_scrollbar: 'شريط التمرير الأفقي'
	str_vertical_scrollbar:   'شريط التمرير العمودي'

	str_columns:  'الأعمدة'
	str_selected: 'محدد'
	str_draft:    'مسودة'
	str_dirty:    'معدّل'
	str_matches:  'تطابق'
	str_page:     'صفحة'
	str_rows:     'صفوف'

	// Weekday names (0=Sun..6=Sat)
	weekdays_short: ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س']!
	weekdays_med:   ['أحد', 'اثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت']!
	weekdays_full:  ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء',
		'الخميس', 'الجمعة', 'السبت']!

	// Month names (Gregorian, 0=Jan..11=Dec)
	months_short: ['ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون', 'يول', 'أغس',
		'سبت', 'أكت', 'نوف', 'ديس']!
	months_full:  ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
		'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر']!
}
