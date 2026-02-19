module gui

import os

fn test_locale_parse_minimal() {
	loc := locale_parse('{"id": "xx-XX"}') or {
		assert false, err.str()
		return
	}
	assert loc.id == 'xx-XX'
	// Defaults match en-US
	defaults := Locale{}
	assert loc.text_dir == .auto
	assert loc.number.decimal_sep == defaults.number.decimal_sep
	assert loc.date.short_date == defaults.date.short_date
	assert loc.currency.symbol == defaults.currency.symbol
	assert loc.str_ok == defaults.str_ok
	assert loc.weekdays_short == defaults.weekdays_short
	assert loc.months_full == defaults.months_full
	assert loc.translations.len == 0
}

fn test_locale_parse_full() {
	content := '{
		"id": "ja-JP",
		"text_dir": "ltr",
		"number": {
			"decimal_sep": ".",
			"group_sep": ",",
			"group_sizes": [3],
			"minus_sign": "-",
			"plus_sign": "+"
		},
		"date": {
			"short_date": "YYYY/M/D",
			"long_date": "YYYY年M月D日",
			"month_year": "YYYY年M月",
			"first_day_of_week": 0,
			"use_24h": true
		},
		"currency": {
			"symbol": "¥",
			"code": "JPY",
			"position": "prefix",
			"decimals": 0
		},
		"strings": {
			"ok": "OK",
			"yes": "はい",
			"cancel": "キャンセル"
		},
		"weekdays_short": ["日","月","火","水","木","金","土"],
		"weekdays_med":   ["日曜","月曜","火曜","水曜","木曜","金曜","土曜"],
		"weekdays_full":  ["日曜日","月曜日","火曜日","水曜日","木曜日","金曜日","土曜日"],
		"months_short": ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"],
		"months_full":  ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"],
		"translations": {
			"greeting": "こんにちは",
			"cart": "カート"
		}
	}'
	loc := locale_parse(content) or {
		assert false, err.str()
		return
	}
	assert loc.id == 'ja-JP'
	assert loc.text_dir == .ltr
	assert loc.number.decimal_sep == `.`
	assert loc.number.group_sep == `,`
	assert loc.date.short_date == 'YYYY/M/D'
	assert loc.date.use_24h == true
	assert loc.currency.symbol == '¥'
	assert loc.currency.code == 'JPY'
	assert loc.currency.position == .prefix
	assert loc.currency.decimals == 0
	assert loc.str_ok == 'OK'
	assert loc.str_yes == 'はい'
	assert loc.str_cancel == 'キャンセル'
	assert loc.weekdays_short[0] == '日'
	assert loc.weekdays_short[6] == '土'
	assert loc.weekdays_full[0] == '日曜日'
	assert loc.months_short[0] == '1月'
	assert loc.months_full[11] == '12月'
	greeting := loc.translations['greeting'] or { '' }
	assert greeting == 'こんにちは'
	cart := loc.translations['cart'] or { '' }
	assert cart == 'カート'
}

fn test_locale_parse_strings_mapping() {
	content := '{
		"id": "test",
		"strings": {
			"save": "Guardar",
			"delete": "Eliminar",
			"loading": "Cargando...",
			"columns": "Columnas",
			"reset": "Restablecer",
			"submit": "Enviar"
		}
	}'
	loc := locale_parse(content) or {
		assert false, err.str()
		return
	}
	assert loc.str_save == 'Guardar'
	assert loc.str_delete == 'Eliminar'
	assert loc.str_loading == 'Cargando...'
	assert loc.str_columns == 'Columnas'
	assert loc.str_reset == 'Restablecer'
	assert loc.str_submit == 'Enviar'
}

fn test_locale_parse_bad_json() {
	locale_parse('not json') or { return }
	assert false, 'expected error for bad JSON'
}

fn test_locale_parse_wrong_array_length() {
	content := '{
		"id": "bad-arrays",
		"weekdays_short": ["A","B","C"],
		"months_short": ["J"]
	}'
	loc := locale_parse(content) or {
		assert false, err.str()
		return
	}
	defaults := Locale{}
	// Wrong length → defaults preserved
	assert loc.weekdays_short == defaults.weekdays_short
	assert loc.months_short == defaults.months_short
}

fn test_locale_registry() {
	// Built-in locales registered by init()
	en := locale_get('en-US') or {
		assert false, 'en-US not found'
		return
	}
	assert en.id == 'en-US'

	de := locale_get('de-DE') or {
		assert false, 'de-DE not found'
		return
	}
	assert de.str_yes == 'Ja'

	// Register custom locale
	custom := Locale{
		id:     'test-XX'
		str_ok: 'Okay!'
	}
	locale_register(custom)
	got := locale_get('test-XX') or {
		assert false, 'test-XX not found'
		return
	}
	assert got.str_ok == 'Okay!'

	// Overwrite
	locale_register(Locale{
		id:     'test-XX'
		str_ok: 'Overwritten'
	})
	got2 := locale_get('test-XX') or {
		assert false, 'test-XX not found after overwrite'
		return
	}
	assert got2.str_ok == 'Overwritten'

	// Missing id → error
	locale_get('zz-ZZ') or { return }
	assert false, 'expected error for missing id'
}

fn test_locale_t() {
	old := gui_locale
	defer {
		gui_locale = old
	}
	gui_locale = Locale{
		translations: {
			'greeting': 'Hello'
			'farewell': 'Goodbye'
		}
	}
	assert locale_t('greeting') == 'Hello'
	assert locale_t('farewell') == 'Goodbye'
	// Missing key → returns key
	assert locale_t('unknown_key') == 'unknown_key'
}

fn test_locale_load_dir() {
	tmp := os.join_path(os.temp_dir(), 'gui_test_locales')
	os.mkdir_all(tmp) or {}
	defer {
		os.rmdir_all(tmp) or {}
	}
	// Write two test bundles
	os.write_file(os.join_path(tmp, 'fr-FR.json'), '{
		"id": "fr-FR",
		"strings": { "yes": "Oui" }
	}') or {
		assert false, err.str()
		return
	}
	os.write_file(os.join_path(tmp, 'es-ES.json'), '{
		"id": "es-ES",
		"strings": { "yes": "Sí" }
	}') or {
		assert false, err.str()
		return
	}
	locale_load_dir(tmp) or {
		assert false, err.str()
		return
	}
	fr := locale_get('fr-FR') or {
		assert false, 'fr-FR not found'
		return
	}
	assert fr.str_yes == 'Oui'

	es := locale_get('es-ES') or {
		assert false, 'es-ES not found'
		return
	}
	assert es.str_yes == 'Sí'
}
