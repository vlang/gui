module gui

import gg
import gx

pub struct InputCfg {
pub:
	id              string
	id_focus        int @[required] // !0 indicates input is focusable. Value indiciates tabbing order
	color           gx.Color = gx.rgb(0x40, 0x40, 0x40)
	sizing          Sizing
	spacing         f32
	text            string
	text_style      gx.TextCfg
	width           f32 = 50
	wrap            bool
	on_text_changed fn (&InputCfg, string, &Window) = unsafe { nil } @[required]
}

pub fn input(cfg InputCfg) &View {
	assert cfg.id_focus != 0
	mut input := row(
		id:         cfg.id
		id_focus:   cfg.id_focus
		width:      cfg.width
		spacing:    cfg.spacing
		color:      cfg.color
		fill:       true
		padding:    padding(5, 6, 6, 6)
		sizing:     cfg.sizing
		on_char:    cfg.on_char
		on_click:   cfg.on_click
		on_keydown: cfg.on_keydown
		children:   [
			text(
				text:        cfg.text
				style:       cfg.text_style
				id_focus:    cfg.id_focus
				wrap:        cfg.wrap
				keep_spaces: true
			),
		]
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
			0...0x1F {
				return
			}
			else {
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

fn (cfg InputCfg) on_click(id string, me MouseEvent, mut w Window) {
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
