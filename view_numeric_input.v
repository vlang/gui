module gui

import math
import strconv

// NumericLocaleCfg defines symbols used for parse/format.
pub struct NumericLocaleCfg {
pub:
	decimal_sep rune  = `.`
	group_sep   rune  = `,`
	group_sizes []int = [3]
	minus_sign  rune  = `-`
	plus_sign   rune  = `+`
}

// NumericStepCfg configures stepping interactions.
pub struct NumericStepCfg {
pub:
	step             f64  = 1.0
	shift_multiplier f64  = 10.0
	alt_multiplier   f64  = 0.1
	mouse_wheel      bool = true
	keyboard         bool = true
	show_buttons     bool = true
}

pub enum NumericInputMode as u8 {
	number
	currency
	percent
}

pub enum NumericAffixPosition as u8 {
	prefix
	suffix
}

// NumericCurrencyModeCfg defines currency symbol placement.
pub struct NumericCurrencyModeCfg {
pub:
	symbol         string               = '$'
	position       NumericAffixPosition = .prefix
	symbol_spacing bool
}

// NumericPercentModeCfg defines percent symbol placement.
pub struct NumericPercentModeCfg {
pub:
	symbol         string               = '%'
	position       NumericAffixPosition = .suffix
	symbol_spacing bool
}

@[minify]
pub struct NumericInputCfg {
pub:
	id                    string
	id_focus              u32
	text                  string
	value                 ?f64
	placeholder           string
	locale                NumericLocaleCfg       = gui_locale.to_numeric_locale()
	step_cfg              NumericStepCfg         = NumericStepCfg{}
	mode                  NumericInputMode       = .number
	currency_mode         NumericCurrencyModeCfg = NumericCurrencyModeCfg{}
	percent_mode          NumericPercentModeCfg  = NumericPercentModeCfg{}
	decimals              int                    = 2
	min                   ?f64
	max                   ?f64
	width                 f32
	height                f32
	min_width             f32
	min_height            f32
	max_width             f32
	max_height            f32
	sizing                Sizing
	padding               Padding   = padding_two_four
	radius                f32       = gui_theme.input_style.radius
	radius_border         f32       = gui_theme.input_style.radius_border
	size_border           f32       = gui_theme.input_style.size_border
	color                 Color     = gui_theme.input_style.color
	color_hover           Color     = gui_theme.input_style.color_hover
	color_border          Color     = gui_theme.input_style.color_border
	color_border_focus    Color     = gui_theme.input_style.color_border_focus
	text_style            TextStyle = gui_theme.input_style.text_style
	placeholder_style     TextStyle = gui_theme.input_style.placeholder_style
	disabled              bool
	invisible             bool
	tooltip               &TooltipCfg                            = unsafe { nil }
	on_text_changed       fn (&Layout, string, mut Window)       = unsafe { nil }
	on_value_commit       fn (&Layout, ?f64, string, mut Window) = unsafe { nil }
	field_id              string
	form_sync_validators  []FormSyncValidator
	form_async_validators []FormAsyncValidator
	form_validate_on      FormValidateOn = .inherit
	form_initial_value    ?string
	a11y_label            string // override label for screen readers
	a11y_description      string // extended help text
}

// numeric_input creates a locale-aware numeric input with optional step controls.
pub fn numeric_input(cfg NumericInputCfg) View {
	locale := numeric_locale_normalize(cfg.locale)
	step_cfg := numeric_step_cfg_normalize(cfg.step_cfg)
	field := numeric_input_field(cfg, locale, step_cfg, step_cfg.show_buttons)
	if !step_cfg.show_buttons {
		return field
	}
	color_hover := cfg.color_hover
	color_border_focus := cfg.color_border_focus
	id_focus := cfg.id_focus
	ni_val := cfg.value or { 0.0 }
	return row(
		name:         'numeric_input'
		id:           cfg.id
		a11y_role:    .text_field
		a11y:         &AccessInfo{
			label:       a11y_label(cfg.a11y_label, cfg.placeholder)
			description: cfg.a11y_description
			value_text:  cfg.text
			value_num:   f32(ni_val)
			value_min:   f32(cfg.min or { 0.0 })
			value_max:   f32(cfg.max or { 0.0 })
		}
		tooltip:      cfg.tooltip
		width:        cfg.width
		height:       cfg.height
		min_width:    cfg.min_width
		min_height:   cfg.min_height
		max_width:    cfg.max_width
		max_height:   cfg.max_height
		sizing:       cfg.sizing
		clip:         true
		color:        cfg.color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		radius:       cfg.radius
		padding:      padding_none
		invisible:    cfg.invisible
		disabled:     cfg.disabled
		v_align:      .middle
		spacing:      0
		on_click:     fn [id_focus] (_ &Layout, mut _ Event, mut w Window) {
			if id_focus > 0 {
				w.set_id_focus(id_focus)
			}
		}
		on_hover:     fn [color_hover, id_focus] (mut layout Layout, mut _ Event, mut w Window) {
			if w.is_focus(id_focus) {
				w.set_mouse_cursor_ibeam()
			} else {
				layout.shape.color = color_hover
			}
		}
		amend_layout: fn [color_border_focus, id_focus] (mut layout Layout, mut w Window) {
			if layout.shape.disabled {
				return
			}
			if id_focus > 0 && id_focus == w.id_focus() {
				layout.shape.color_border = color_border_focus
			}
		}
		content:      [
			field,
			numeric_input_step_buttons(cfg, locale, step_cfg),
		]
	)
}

fn numeric_input_field(cfg NumericInputCfg, locale NumericLocaleCfg, step_cfg NumericStepCfg, fill_parent bool) View {
	sizing := if fill_parent { fill_fill } else { cfg.sizing }
	input_id := if fill_parent && cfg.id.len > 0 { '${cfg.id}_field' } else { cfg.id }
	tooltip := if fill_parent { unsafe { nil } } else { cfg.tooltip }
	color := if fill_parent { color_transparent } else { cfg.color }
	color_hover := if fill_parent { color_transparent } else { cfg.color_hover }
	color_border := if fill_parent { color_transparent } else { cfg.color_border }
	color_border_focus := if fill_parent { color_transparent } else { cfg.color_border_focus }
	input_size_border := if fill_parent { f32(0) } else { cfg.size_border }
	input_radius := if fill_parent { f32(0) } else { cfg.radius }
	input_radius_border := if fill_parent { f32(0) } else { cfg.radius_border }
	return input(
		id:                    input_id
		id_focus:              cfg.id_focus
		text:                  cfg.text
		placeholder:           cfg.placeholder
		tooltip:               tooltip
		sizing:                sizing
		width:                 if fill_parent { 0 } else { cfg.width }
		height:                if fill_parent { 0 } else { cfg.height }
		min_width:             if fill_parent { 0 } else { cfg.min_width }
		min_height:            if fill_parent { 0 } else { cfg.min_height }
		max_width:             if fill_parent { 0 } else { cfg.max_width }
		max_height:            if fill_parent { 0 } else { cfg.max_height }
		padding:               cfg.padding
		radius:                input_radius
		radius_border:         input_radius_border
		size_border:           input_size_border
		color:                 color
		color_hover:           color_hover
		color_border:          color_border
		color_border_focus:    color_border_focus
		text_style:            cfg.text_style
		placeholder_style:     cfg.placeholder_style
		disabled:              cfg.disabled
		invisible:             cfg.invisible
		pre_commit_transform:  fn [cfg, locale] (current string, proposed string) ?string {
			mode_cfg := numeric_mode_cfg(cfg)
			return numeric_input_pre_commit_transform_mode(current, proposed, cfg.decimals,
				locale, mode_cfg)
		}
		post_commit_normalize: fn [cfg, locale] (text string, _ InputCommitReason) string {
			mode_cfg := numeric_mode_cfg(cfg)
			_, committed := numeric_input_commit_result_mode(text, cfg.value, cfg.min,
				cfg.max, cfg.decimals, locale, mode_cfg)
			return committed
		}
		on_text_changed:       cfg.on_text_changed
		on_text_commit:        fn [cfg, locale] (layout &Layout, text string, _ InputCommitReason, mut w Window) {
			mode_cfg := numeric_mode_cfg(cfg)
			value, committed := numeric_input_commit_result_mode(text, cfg.value, cfg.min,
				cfg.max, cfg.decimals, locale, mode_cfg)
			numeric_input_emit_commit(layout, cfg, value, committed, false, mut w)
		}
		on_key_down:           fn [cfg, locale, step_cfg] (layout &Layout, mut e Event, mut w Window) {
			numeric_input_on_key_down(layout, mut e, mut w, cfg, locale, step_cfg)
		}
		on_mouse_scroll:       fn [cfg, locale, step_cfg] (layout &Layout, mut e Event, mut w Window) {
			numeric_input_on_mouse_scroll(layout, mut e, mut w, cfg, locale, step_cfg)
		}
		field_id:              cfg.field_id
		form_sync_validators:  cfg.form_sync_validators
		form_async_validators: cfg.form_async_validators
		form_validate_on:      cfg.form_validate_on
		form_initial_value:    cfg.form_initial_value
	)
}

fn numeric_input_step_buttons(cfg NumericInputCfg, locale NumericLocaleCfg, step_cfg NumericStepCfg) View {
	triangle_size := f32_max(cfg.text_style.size - 4, f32(8))
	triangle_style := TextStyle{
		...cfg.text_style
		size: triangle_size
	}
	base_color := cfg.color
	id_step_up := if cfg.id.len > 0 { '${cfg.id}_step_up' } else { '' }
	id_step_down := if cfg.id.len > 0 { '${cfg.id}_step_down' } else { '' }
	return column(
		name:      'numeric_input_steps'
		spacing:   0
		sizing:    fit_fill
		disabled:  cfg.disabled
		invisible: cfg.invisible
		padding:   padding(0, pad_small, 0, 0)
		content:   [
			button(
				id:           id_step_up
				sizing:       fill_fill
				padding:      padding_none
				color:        base_color
				color_hover:  cfg.color_hover
				color_focus:  cfg.color_hover
				color_click:  cfg.color_border_focus
				color_border: color_transparent
				size_border:  0
				radius:       0
				on_click:     fn [cfg, locale, step_cfg] (layout &Layout, mut e Event, mut w Window) {
					numeric_input_apply_step(layout, cfg, locale, step_cfg, 1.0, e.modifiers, mut
						e, mut w)
				}
				content:      [
					text(
						text:       '▲'
						text_style: triangle_style
					),
				]
			),
			button(
				id:           id_step_down
				sizing:       fill_fill
				padding:      padding_none
				color:        base_color
				color_hover:  cfg.color_hover
				color_focus:  cfg.color_hover
				color_click:  cfg.color_border_focus
				color_border: color_transparent
				size_border:  0
				radius:       0
				on_click:     fn [cfg, locale, step_cfg] (layout &Layout, mut e Event, mut w Window) {
					numeric_input_apply_step(layout, cfg, locale, step_cfg, -1.0, e.modifiers, mut
						e, mut w)
				}
				content:      [
					text(
						text:       '▼'
						text_style: triangle_style
					),
				]
			),
		]
	)
}

fn numeric_input_on_key_down(layout &Layout, mut e Event, mut w Window, cfg NumericInputCfg, locale NumericLocaleCfg, step_cfg NumericStepCfg) {
	if !step_cfg.keyboard || cfg.disabled {
		return
	}
	if e.modifiers.has_any(.ctrl, .super) {
		return
	}
	direction := match e.key_code {
		.up { f64(1.0) }
		.down { f64(-1.0) }
		else { return }
	}
	numeric_input_apply_step(layout, cfg, locale, step_cfg, direction, e.modifiers, mut
		e, mut w)
}

fn numeric_input_on_mouse_scroll(layout &Layout, mut e Event, mut w Window, cfg NumericInputCfg, locale NumericLocaleCfg, step_cfg NumericStepCfg) {
	if !step_cfg.mouse_wheel || cfg.disabled {
		return
	}
	if e.modifiers.has_any(.ctrl, .super) {
		return
	}
	if e.scroll_y == 0 {
		return
	}
	direction := if e.scroll_y > 0 { f64(1.0) } else { f64(-1.0) }
	numeric_input_apply_step(layout, cfg, locale, step_cfg, direction, e.modifiers, mut
		e, mut w)
}

fn numeric_input_apply_step(layout &Layout, cfg NumericInputCfg, locale NumericLocaleCfg, step_cfg NumericStepCfg, direction f64, modifiers Modifier, mut e Event, mut w Window) {
	mode_cfg := numeric_mode_cfg(cfg)
	next_value, next_text := numeric_input_step_result_mode(cfg.text, cfg.value, cfg.min,
		cfg.max, cfg.decimals, step_cfg, locale, direction, modifiers, mode_cfg)
	numeric_input_emit_commit(layout, cfg, next_value, next_text, true, mut w)
	e.is_handled = true
}

fn numeric_input_emit_commit(layout &Layout, cfg NumericInputCfg, value ?f64, text string, emit_text_change bool, mut w Window) {
	if emit_text_change && cfg.on_text_changed != unsafe { nil } && text != cfg.text {
		cfg.on_text_changed(layout, text, mut w)
	}
	if cfg.on_value_commit != unsafe { nil } {
		cfg.on_value_commit(layout, value, text, mut w)
	}
}

fn numeric_input_pre_commit_transform_mode(current string, proposed string, decimals int, locale NumericLocaleCfg, mode_cfg NumericModeCfg) ?string {
	if proposed == current {
		return proposed
	}
	trimmed := proposed.trim_space()
	if trimmed.len == 0 {
		return ''
	}
	if _ := numeric_mode_parse_value(trimmed, decimals, locale, mode_cfg) {
		return proposed
	}
	if numeric_mode_is_transient_input(proposed, locale, mode_cfg) {
		return proposed
	}
	return none
}

fn numeric_input_commit_result(text string, value ?f64, min ?f64, max ?f64, decimals int, locale NumericLocaleCfg) (?f64, string) {
	return numeric_input_commit_result_mode(text, value, min, max, decimals, locale, NumericModeCfg{})
}

fn numeric_input_commit_result_mode(text string, value ?f64, min ?f64, max ?f64, decimals int, locale NumericLocaleCfg, mode_cfg NumericModeCfg) (?f64, string) {
	trimmed := text.trim_space()
	if trimmed.len == 0 {
		return none, ''
	}
	if parsed := numeric_mode_parse_value(trimmed, decimals, locale, mode_cfg) {
		clamped := numeric_clamp(parsed, min, max)
		return clamped, numeric_mode_format_value(clamped, decimals, locale, mode_cfg)
	}
	if current := value {
		clamped := numeric_clamp(current, min, max)
		return clamped, numeric_mode_format_value(clamped, decimals, locale, mode_cfg)
	}
	return none, ''
}

fn numeric_input_step_result(text string, value ?f64, min ?f64, max ?f64, decimals int, step_cfg NumericStepCfg, locale NumericLocaleCfg, direction f64, modifiers Modifier) (?f64, string) {
	return numeric_input_step_result_mode(text, value, min, max, decimals, step_cfg, locale,
		direction, modifiers, NumericModeCfg{})
}

fn numeric_input_step_result_mode(text string, value ?f64, min ?f64, max ?f64, decimals int, step_cfg NumericStepCfg, locale NumericLocaleCfg, direction f64, modifiers Modifier, mode_cfg NumericModeCfg) (?f64, string) {
	if direction == 0 {
		return numeric_input_commit_result_mode(text, value, min, max, decimals, locale,
			mode_cfg)
	}
	step_display := numeric_step_delta(step_cfg, modifiers)
	delta := numeric_mode_step_delta(step_display, mode_cfg)
	seed := numeric_step_seed_mode(text, value, min, decimals, locale, mode_cfg)
	clamped := numeric_clamp(seed + (delta * direction), min, max)
	return clamped, numeric_mode_format_value(clamped, decimals, locale, mode_cfg)
}

fn numeric_step_seed(text string, value ?f64, min ?f64, locale NumericLocaleCfg) f64 {
	return numeric_step_seed_mode(text, value, min, 9, locale, NumericModeCfg{})
}

fn numeric_step_seed_mode(text string, value ?f64, min ?f64, decimals int, locale NumericLocaleCfg, mode_cfg NumericModeCfg) f64 {
	if current := value {
		return current
	}
	if parsed := numeric_mode_parse_value(text, decimals, locale, mode_cfg) {
		return parsed
	}
	if min_value := min {
		return min_value
	}
	return 0.0
}

fn numeric_step_delta(cfg NumericStepCfg, modifiers Modifier) f64 {
	mut step := cfg.step
	if modifiers.has(.shift) {
		step *= cfg.shift_multiplier
	}
	if modifiers.has(.alt) {
		step *= cfg.alt_multiplier
	}
	if step < 0 {
		return -step
	}
	return step
}

struct NumericModeCfg {
	mode               NumericInputMode = .number
	affix              string
	affix_position     NumericAffixPosition = .suffix
	affix_spacing      bool
	display_multiplier f64 = 1.0
}

fn numeric_mode_cfg(cfg NumericInputCfg) NumericModeCfg {
	return match cfg.mode {
		.currency {
			NumericModeCfg{
				mode:               .currency
				affix:              cfg.currency_mode.symbol.trim_space()
				affix_position:     cfg.currency_mode.position
				affix_spacing:      cfg.currency_mode.symbol_spacing
				display_multiplier: 1.0
			}
		}
		.percent {
			NumericModeCfg{
				mode:               .percent
				affix:              cfg.percent_mode.symbol.trim_space()
				affix_position:     cfg.percent_mode.position
				affix_spacing:      cfg.percent_mode.symbol_spacing
				display_multiplier: 100.0
			}
		}
		else {
			NumericModeCfg{
				mode:               .number
				display_multiplier: 1.0
			}
		}
	}
}

fn numeric_mode_to_display(value f64, mode_cfg NumericModeCfg) f64 {
	return value * mode_cfg.display_multiplier
}

fn numeric_mode_from_display(value f64, mode_cfg NumericModeCfg) f64 {
	if mode_cfg.display_multiplier == 0 {
		return value
	}
	return value / mode_cfg.display_multiplier
}

fn numeric_mode_step_delta(step_display f64, mode_cfg NumericModeCfg) f64 {
	return numeric_mode_from_display(step_display, mode_cfg)
}

fn numeric_mode_parse_value(raw string, decimals int, locale NumericLocaleCfg, mode_cfg NumericModeCfg) ?f64 {
	plain := numeric_strip_affix(raw.trim_space(), locale, mode_cfg) or { return none }
	display_scaled := numeric_parse_scaled(plain, decimals, locale) or { return none }
	display_value := numeric_scaled_to_value(display_scaled, decimals)
	return numeric_mode_from_display(display_value, mode_cfg)
}

fn numeric_mode_is_transient_input(raw string, locale NumericLocaleCfg, mode_cfg NumericModeCfg) bool {
	loc := numeric_locale_normalize(locale)
	mut text := raw.trim_space()
	if text.len == 0 {
		return true
	}
	minus := loc.minus_sign.str()
	plus := loc.plus_sign.str()
	if minus.len > 0 && text == minus {
		return true
	}
	if plus.len > 0 && text == plus {
		return true
	}
	if minus.len > 0 && text.starts_with(minus) {
		text = text[minus.len..].trim_left(' \t')
	} else if plus.len > 0 && text.starts_with(plus) {
		text = text[plus.len..].trim_left(' \t')
	}
	if text.len == 0 {
		return true
	}
	if mode_cfg.affix.len > 0 {
		match mode_cfg.affix_position {
			.prefix {
				if text == mode_cfg.affix {
					return true
				}
				if text.starts_with(mode_cfg.affix) {
					text = text[mode_cfg.affix.len..].trim_left(' \t')
					if text.len == 0 {
						return true
					}
				}
			}
			.suffix {
				if text == mode_cfg.affix {
					return true
				}
				mut right := text.trim_right(' \t')
				if right.ends_with(mode_cfg.affix) {
					right = right[..right.len - mode_cfg.affix.len].trim_right(' \t')
					text = right
					if text.len == 0 {
						return true
					}
				}
			}
		}
	}
	decimal_sep := loc.decimal_sep.str()
	if decimal_sep.len == 0 {
		return false
	}
	if text == decimal_sep {
		return true
	}
	if !text.ends_with(decimal_sep) {
		return false
	}
	prefix := text[..text.len - decimal_sep.len]
	if prefix.len == 0 {
		return true
	}
	if _ := numeric_parse(prefix, loc) {
		return true
	}
	return false
}

fn numeric_mode_format_value(value f64, decimals int, locale NumericLocaleCfg, mode_cfg NumericModeCfg) string {
	display_value := numeric_mode_to_display(value, mode_cfg)
	scaled := numeric_to_scaled(display_value, decimals)
	formatted := numeric_format_scaled(scaled, decimals, locale)
	return numeric_apply_affix(formatted, locale, mode_cfg)
}

fn numeric_strip_affix(raw string, locale NumericLocaleCfg, mode_cfg NumericModeCfg) ?string {
	mut text := raw.trim_space()
	if text.len == 0 {
		return none
	}
	mut sign := ''
	minus := locale.minus_sign.str()
	plus := locale.plus_sign.str()
	if minus.len > 0 && text.starts_with(minus) {
		sign = minus
		text = text[minus.len..].trim_left(' \t')
	} else if plus.len > 0 && text.starts_with(plus) {
		sign = plus
		text = text[plus.len..].trim_left(' \t')
	}
	if mode_cfg.affix.len > 0 {
		match mode_cfg.affix_position {
			.prefix {
				if text.starts_with(mode_cfg.affix) {
					text = text[mode_cfg.affix.len..].trim_left(' \t')
				}
			}
			.suffix {
				mut right := text.trim_right(' \t')
				if right.ends_with(mode_cfg.affix) {
					right = right[..right.len - mode_cfg.affix.len].trim_right(' \t')
				}
				text = right
			}
		}
	}
	text = text.trim_space()
	if text.len == 0 {
		return none
	}
	return sign + text
}

fn numeric_apply_affix(formatted string, locale NumericLocaleCfg, mode_cfg NumericModeCfg) string {
	if mode_cfg.affix.len == 0 {
		return formatted
	}
	minus := locale.minus_sign.str()
	plus := locale.plus_sign.str()
	mut sign := ''
	mut number := formatted
	if minus.len > 0 && number.starts_with(minus) {
		sign = minus
		number = number[minus.len..]
	} else if plus.len > 0 && number.starts_with(plus) {
		sign = plus
		number = number[plus.len..]
	}
	space := if mode_cfg.affix_spacing { ' ' } else { '' }
	return match mode_cfg.affix_position {
		.prefix { sign + mode_cfg.affix + space + number }
		.suffix { sign + number + space + mode_cfg.affix }
	}
}

fn numeric_step_cfg_normalize(cfg NumericStepCfg) NumericStepCfg {
	return NumericStepCfg{
		step:             if cfg.step > 0 { cfg.step } else { 1.0 }
		shift_multiplier: if cfg.shift_multiplier > 0 { cfg.shift_multiplier } else { 10.0 }
		alt_multiplier:   if cfg.alt_multiplier > 0 { cfg.alt_multiplier } else { 0.1 }
		mouse_wheel:      cfg.mouse_wheel
		keyboard:         cfg.keyboard
		show_buttons:     cfg.show_buttons
	}
}

fn numeric_clamp(value f64, min ?f64, max ?f64) f64 {
	mut low := min or { math.inf(-1) }
	mut high := max or { math.inf(1) }
	if low > high {
		low, high = high, low
	}
	if value < low {
		return low
	}
	if value > high {
		return high
	}
	return value
}

fn numeric_parse(raw string, locale NumericLocaleCfg) ?f64 {
	loc := numeric_locale_normalize(locale)
	if raw.len == 0 {
		return none
	}
	rs := raw.runes()
	mut start := 0
	mut normalized := []rune{}
	mut seen_digit := false
	mut seen_decimal := false
	mut prev_group := false
	mut saw_group_sep := false
	mut decimal_index := -1

	if rs[0] == loc.minus_sign {
		normalized << `-`
		start = 1
	} else if rs[0] == loc.plus_sign {
		start = 1
	}
	for i in start .. rs.len {
		ch := rs[i]
		if ch >= `0` && ch <= `9` {
			normalized << ch
			seen_digit = true
			prev_group = false
			continue
		}
		if ch == loc.decimal_sep {
			if seen_decimal || prev_group {
				return none
			}
			normalized << `.`
			seen_decimal = true
			prev_group = false
			decimal_index = i
			continue
		}
		if loc.group_sep != rune(0) && ch == loc.group_sep {
			if seen_decimal || !seen_digit || prev_group {
				return none
			}
			prev_group = true
			saw_group_sep = true
			continue
		}
		return none
	}

	if !seen_digit || prev_group {
		return none
	}

	if loc.group_sep != rune(0) && saw_group_sep {
		integer_end := if decimal_index >= 0 { decimal_index } else { rs.len }
		if integer_end < start {
			return none
		}
		integer_segment := rs[start..integer_end]
		if integer_segment.len == 0 {
			return none
		}
		if !numeric_integer_groups_valid(integer_segment, loc.group_sep, loc.group_sizes) {
			return none
		}
	}

	number := strconv.atof64(normalized.string()) or { return none }
	return number
}

fn numeric_parse_scaled(raw string, decimals int, locale NumericLocaleCfg) ?i64 {
	if parsed := numeric_parse(raw, locale) {
		return numeric_to_scaled(parsed, decimals)
	}
	return none
}

fn numeric_integer_groups_valid(integer_segment []rune, group_sep rune, group_sizes []int) bool {
	mut group_lengths := []int{}
	mut count := 0
	for i := integer_segment.len - 1; i >= 0; i-- {
		ch := integer_segment[i]
		if ch == group_sep {
			if count == 0 {
				return false
			}
			group_lengths << count
			count = 0
			continue
		}
		if ch < `0` || ch > `9` {
			return false
		}
		count++
	}
	if count == 0 {
		return false
	}
	group_lengths << count
	for idx := 0; idx < group_lengths.len; idx++ {
		length := group_lengths[idx]
		expected := numeric_group_size(group_sizes, idx)
		if idx == group_lengths.len - 1 {
			if length <= expected {
				continue
			}
			return false
		}
		if length != expected {
			return false
		}
	}
	return true
}

fn numeric_format(value f64, decimals int, locale NumericLocaleCfg) string {
	scaled := numeric_to_scaled(value, decimals)
	return numeric_format_scaled(scaled, decimals, locale)
}

fn numeric_format_scaled(scaled i64, decimals int, locale NumericLocaleCfg) string {
	loc := numeric_locale_normalize(locale)
	d := numeric_decimals_clamped(decimals)
	scale := numeric_scale_factor(d)
	mut magnitude := scaled
	mut sign := ''
	if scaled < 0 {
		magnitude = -scaled
		sign = loc.minus_sign.str()
	}
	int_part := (magnitude / scale).str()
	grouped := numeric_group_integer_part(int_part, loc.group_sep, loc.group_sizes)
	if d == 0 {
		return sign + grouped
	}
	mut frac_part := (magnitude % scale).str()
	if frac_part.len < d {
		frac_part = '0'.repeat(d - frac_part.len) + frac_part
	}
	return sign + grouped + loc.decimal_sep.str() + frac_part
}

fn numeric_scale_factor(decimals int) i64 {
	d := numeric_decimals_clamped(decimals)
	mut factor := i64(1)
	for _ in 0 .. d {
		factor *= 10
	}
	return factor
}

fn numeric_to_scaled(value f64, decimals int) i64 {
	factor := f64(numeric_scale_factor(decimals))
	return i64(math.round(value * factor))
}

fn numeric_scaled_to_value(scaled i64, decimals int) f64 {
	factor := f64(numeric_scale_factor(decimals))
	return f64(scaled) / factor
}

fn numeric_decimals_clamped(decimals int) int {
	if decimals < 0 {
		return 0
	}
	if decimals > 9 {
		return 9
	}
	return decimals
}

fn numeric_group_integer_part(raw string, group_sep rune, group_sizes []int) string {
	if group_sep == rune(0) {
		return raw
	}
	digits := raw.runes()
	if digits.len <= 3 {
		return raw
	}
	mut reversed := []rune{}
	mut count := 0
	mut group_idx := 0
	mut group_size := numeric_group_size(group_sizes, group_idx)
	for i := digits.len - 1; i >= 0; i-- {
		reversed << digits[i]
		count++
		if i > 0 && count == group_size {
			reversed << group_sep
			count = 0
			if group_idx + 1 < group_sizes.len {
				group_idx++
			}
			group_size = numeric_group_size(group_sizes, group_idx)
		}
	}
	reversed.reverse_in_place()
	return reversed.string()
}

fn numeric_group_size(group_sizes []int, idx int) int {
	if idx >= 0 && idx < group_sizes.len && group_sizes[idx] > 0 {
		return group_sizes[idx]
	}
	return 3
}

fn numeric_locale_normalize(cfg NumericLocaleCfg) NumericLocaleCfg {
	mut sizes := []int{}
	for size in cfg.group_sizes {
		if size > 0 {
			sizes << size
		}
	}
	if sizes.len == 0 {
		sizes << 3
	}
	mut group_sep := if cfg.group_sep != rune(0) { cfg.group_sep } else { rune(`,`) }
	decimal_sep := if cfg.decimal_sep != rune(0) { cfg.decimal_sep } else { rune(`.`) }
	if group_sep == decimal_sep {
		group_sep = rune(0)
	}
	return NumericLocaleCfg{
		decimal_sep: decimal_sep
		group_sep:   group_sep
		group_sizes: sizes
		minus_sign:  if cfg.minus_sign != rune(0) { cfg.minus_sign } else { rune(`-`) }
		plus_sign:   if cfg.plus_sign != rune(0) { cfg.plus_sign } else { rune(`+`) }
	}
}
