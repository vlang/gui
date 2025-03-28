module gui

import gg
import gx

pub struct InputCfg {
pub:
	id              string
	id_focus        int @[required] // !0 indicates input is focusable. Value indiciates tabbing order
	color           gx.Color = color_input
	sizing          Sizing
	spacing         f32
	padding         Padding = padding(5, 6, 6, 6)
	text            string
	text_style      gx.TextCfg = text_cfg
	width           f32
	min_width       f32
	max_width       f32
	fill            bool = true
	wrap            bool
	on_text_changed fn (&InputCfg, string, &Window) = unsafe { nil } @[required]
}

pub fn input(cfg InputCfg) &View {
	assert cfg.id_focus != 0
	mut text_view := text(
		text:        cfg.text
		style:       cfg.text_style
		id_focus:    cfg.id_focus
		wrap:        cfg.wrap
		keep_spaces: true
	)

	mut input := row(
		id:         cfg.id
		id_focus:   cfg.id_focus
		width:      cfg.width
		min_width:  cfg.min_width
		max_width:  cfg.max_width
		spacing:    cfg.spacing
		color:      cfg.color
		padding:    cfg.padding
		sizing:     cfg.sizing
		on_char:    cfg.on_char
		on_click:   cfg.on_click
		on_keydown: cfg.on_keydown
		fill:       cfg.fill
		children:   [text_view]
	)
	return input
}

const bsp_c = 0x08
const del_c = 0x7F
const space_c = 0x20

fn (cfg InputCfg) on_char(c u32, mut w Window) {
	if cfg.on_text_changed != unsafe { nil } {
		mut t := cfg.text
		cursor_pos := w.input_state[w.id_focus].cursor_pos
		match c {
			bsp_c, del_c {
				if cursor_pos < 0 {
					w.input_state[w.id_focus].cursor_pos = cfg.text.len
				} else if cursor_pos > 0 {
					t = cfg.text[..cursor_pos - 1] + cfg.text[cursor_pos..]
					w.input_state[w.id_focus].cursor_pos = cursor_pos - 1
				}
			}
			0...0x1F { // non-printables
				return
			}
			else {
				if !cfg.wrap && cfg.sizing.width == .fixed { // clamp max chars to width of box when single line.
					ctx := w.ui
					ctx.set_text_cfg(cfg.text_style)
					width := ctx.text_width(cfg.text + rune(c).str())
					if width > (cfg.width - cfg.padding.left - cfg.padding.right) {
						return
					}
				}
				if cursor_pos < 0 {
					t = cfg.text + rune(c).str()
					w.input_state[w.id_focus].cursor_pos = t.len
				} else {
					t = cfg.text[..cursor_pos] + rune(c).str() + cfg.text[cursor_pos..]
					w.input_state[w.id_focus].cursor_pos = cursor_pos + 1
				}
			}
		}
		cfg.on_text_changed(cfg, t, w)
	}
}

fn (cfg InputCfg) on_click(_ voidptr, me MouseEvent, mut w Window) {
	if me.mouse_button == gg.MouseButton.left {
		w.input_state[w.id_focus].cursor_pos = cfg.text.len
	}
}

fn (cfg InputCfg) on_keydown(c gg.KeyCode, m gg.Modifier, mut w Window) bool {
	mut cursor_pos := w.input_state[w.id_focus].cursor_pos
	match c {
		.left { cursor_pos = int_max(0, cursor_pos - 1) }
		.right { cursor_pos = int_min(cfg.text.len, cursor_pos + 1) }
		.home { cursor_pos = 0 }
		.end { cursor_pos = cfg.text.len }
		else { return false }
	}
	w.input_state[w.id_focus].cursor_pos = cursor_pos
	return true
}
