module gui

import math

fn test_numeric_parse_en_locale() {
	value := numeric_parse('1,234.50', NumericLocaleCfg{}) or {
		assert false
		return
	}
	assert math.abs(value - 1234.5) < 0.000001
}

fn test_numeric_parse_de_locale() {
	locale := NumericLocaleCfg{
		decimal_sep: `,`
		group_sep:   `.`
	}
	value := numeric_parse('1.234,50', locale) or {
		assert false
		return
	}
	assert math.abs(value - 1234.5) < 0.000001
}

fn test_numeric_parse_invalid_string() {
	assert numeric_parse('1,,234', NumericLocaleCfg{}) == none
	assert numeric_parse('abc', NumericLocaleCfg{}) == none
}

fn test_numeric_parse_invalid_grouping() {
	locale := NumericLocaleCfg{
		group_sizes: [3, 2]
	}
	assert numeric_parse('12,345,67', locale) == none
}

fn test_numeric_format_en_locale() {
	assert numeric_format(1234.5, 2, NumericLocaleCfg{}) == '1,234.50'
}

fn test_numeric_format_de_locale() {
	locale := NumericLocaleCfg{
		decimal_sep: `,`
		group_sep:   `.`
	}
	assert numeric_format(1234.5, 2, locale) == '1.234,50'
}

fn test_numeric_format_group_sizes() {
	locale := NumericLocaleCfg{
		group_sep:   `,`
		group_sizes: [3, 2]
	}
	assert numeric_format(1234567, 0, locale) == '12,34,567'
}

fn test_numeric_clamp_unbounded_allows_large_values() {
	value := 1.0e308
	assert numeric_clamp(value, none, none) == value
}

fn test_numeric_commit_result_clamps() {
	value, text := numeric_input_commit_result('1,250.30', none, 0.0, 1000.0, 2, NumericLocaleCfg{})
	assert text == '1,000.00'
	if parsed := value {
		assert math.abs(parsed - 1000.0) < 0.000001
	} else {
		assert false
	}
}

fn test_numeric_commit_result_invalid_fallback_to_value() {
	value, text := numeric_input_commit_result('abc', 12.5, none, none, 1, NumericLocaleCfg{})
	assert text == '12.5'
	if parsed := value {
		assert math.abs(parsed - 12.5) < 0.000001
	} else {
		assert false
	}
}

fn test_numeric_commit_result_invalid_without_value() {
	value, text := numeric_input_commit_result('abc', none, none, none, 2, NumericLocaleCfg{})
	assert value == none
	assert text == ''
}

fn test_numeric_step_result_uses_min_seed() {
	value, text := numeric_input_step_result('', none, 10.0, none, 2, NumericStepCfg{},
		NumericLocaleCfg{}, 1.0, .none)
	assert text == '11.00'
	if parsed := value {
		assert math.abs(parsed - 11.0) < 0.000001
	} else {
		assert false
	}
}

fn test_numeric_step_result_modifiers() {
	cfg := NumericStepCfg{
		step:             1.0
		shift_multiplier: 10.0
		alt_multiplier:   0.1
	}
	value_shift, text_shift := numeric_input_step_result('5', none, none, none, 2, cfg,
		NumericLocaleCfg{}, 1.0, .shift)
	assert text_shift == '15.00'
	if parsed := value_shift {
		assert math.abs(parsed - 15.0) < 0.000001
	} else {
		assert false
	}

	value_alt, text_alt := numeric_input_step_result('5', none, none, none, 2, cfg, NumericLocaleCfg{},
		1.0, .alt)
	assert text_alt == '5.10'
	if parsed := value_alt {
		assert math.abs(parsed - 5.1) < 0.000001
	} else {
		assert false
	}
}

fn test_numeric_currency_commit_result_prefix_symbol() {
	mode_cfg := NumericModeCfg{
		mode:               .currency
		affix:              '$'
		affix_position:     .prefix
		display_multiplier: 1.0
	}
	value, text := numeric_input_commit_result_mode('-$1,234.5', none, none, none, 2,
		NumericLocaleCfg{}, mode_cfg)
	assert text == '-$1,234.50'
	if parsed := value {
		assert math.abs(parsed - (-1234.5)) < 0.000001
	} else {
		assert false
	}
}

fn test_numeric_currency_commit_result_suffix_symbol() {
	locale := NumericLocaleCfg{
		decimal_sep: `,`
		group_sep:   `.`
	}
	mode_cfg := NumericModeCfg{
		mode:               .currency
		affix:              'EUR'
		affix_position:     .suffix
		affix_spacing:      true
		display_multiplier: 1.0
	}
	value, text := numeric_input_commit_result_mode('1.234,5 EUR', none, none, none, 2,
		locale, mode_cfg)
	assert text == '1.234,50 EUR'
	if parsed := value {
		assert math.abs(parsed - 1234.5) < 0.000001
	} else {
		assert false
	}
}

fn test_numeric_percent_commit_ratio_value() {
	mode_cfg := NumericModeCfg{
		mode:               .percent
		affix:              '%'
		affix_position:     .suffix
		display_multiplier: 100.0
	}
	value, text := numeric_input_commit_result_mode('12.5%', none, none, none, 2, NumericLocaleCfg{},
		mode_cfg)
	assert text == '12.50%'
	if parsed := value {
		assert math.abs(parsed - 0.125) < 0.000001
	} else {
		assert false
	}
}

fn test_numeric_percent_step_result_uses_display_units() {
	mode_cfg := NumericModeCfg{
		mode:               .percent
		affix:              '%'
		affix_position:     .suffix
		display_multiplier: 100.0
	}
	value, text := numeric_input_step_result_mode('12.50%', none, none, none, 2, NumericStepCfg{},
		NumericLocaleCfg{}, 1.0, .none, mode_cfg)
	assert text == '13.50%'
	if parsed := value {
		assert math.abs(parsed - 0.135) < 0.000001
	} else {
		assert false
	}
}

fn test_numeric_percent_round_trip_is_canonical() {
	mode_cfg := NumericModeCfg{
		mode:               .percent
		affix:              '%'
		affix_position:     .suffix
		display_multiplier: 100.0
	}
	source := '-0.125'
	formatted := numeric_mode_format_value(source.f64(), 2, NumericLocaleCfg{}, mode_cfg)
	assert formatted == '-12.50%'
	parsed := numeric_mode_parse_value(formatted, 2, NumericLocaleCfg{}, mode_cfg) or {
		assert false
		return
	}
	assert math.abs(parsed - source.f64()) < 0.000001
}
