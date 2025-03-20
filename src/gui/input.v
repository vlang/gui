module gui

import gg
import gx

pub struct InputCfg {
pub:
	id              string
	focus_id        int @[required] // >0 indicates input is focusable. Value indiciates tabbing order
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
	mut input := row(
		id:         cfg.id
		focus_id:   cfg.focus_id
		width:      cfg.width
		spacing:    cfg.spacing
		color:      cfg.color
		fill:       true
		padding:    padding(5, 6, 6, 6)
		sizing:     cfg.sizing
		on_char:    fn [cfg] (c u32, mut w Window) bool {
			return on_char(cfg, c, mut w)
		}
		on_click:   fn [cfg] (id string, me MouseEvent, mut w Window) bool {
			return on_click(cfg, id, me, mut w)
		}
		on_keydown: fn [cfg] (c gg.KeyCode, m gg.Modifier, mut w Window) bool {
			return on_keydown(cfg, c, m, mut w)
		}
		children:   [
			text(
				text:        cfg.text
				style:       cfg.text_style
				focus_id:    cfg.focus_id
				wrap:        cfg.wrap
				keep_spaces: true
			),
		]
	)
	return input
}

const bsp_c = 0x08
const del_c = 0x7F
const ret_c = 0x0D
const tab_c = 0x09
const space_c = 0x20

fn on_char(cfg &InputCfg, c u32, mut w Window) bool {
	if cfg.on_text_changed != unsafe { nil } {
		mut t := cfg.text
		cursor_pos := w.input_state[w.focus_id].cursor_pos
		match c {
			ret_c, tab_c {
				return false
			}
			bsp_c, del_c {
				if cursor_pos < 0 {
					w.input_state[w.focus_id].cursor_pos = cfg.text.len
				} else if cursor_pos > 0 {
					t = cfg.text[..cursor_pos - 1] + cfg.text[cursor_pos..]
					w.input_state[w.focus_id].cursor_pos = cursor_pos - 1
				}
			}
			else {
				if cursor_pos < 0 {
					t = cfg.text + rune(c).str()
					w.input_state[w.focus_id].cursor_pos = t.len
				} else {
					t = cfg.text[..cursor_pos] + rune(c).str() + cfg.text[cursor_pos..]
					w.input_state[w.focus_id].cursor_pos = cursor_pos + 1
				}
			}
		}
		cfg.on_text_changed(cfg, t, w)
		return true
	}
	return false
}

fn on_click(cfg &InputCfg, id string, me MouseEvent, mut w Window) bool {
	if me.mouse_button == gg.MouseButton.left {
		w.input_state[w.focus_id].cursor_pos = cfg.text.len
		return true
	}
	return false
}

fn on_keydown(cfg &InputCfg, c gg.KeyCode, m gg.Modifier, mut w Window) bool {
	mut cursor_pos := w.input_state[w.focus_id].cursor_pos
	match c {
		.left { cursor_pos = int_max(0, cursor_pos - 1) }
		.right { cursor_pos = int_min(cfg.text.len, cursor_pos + 1) }
		.home { cursor_pos = 0 }
		.end { cursor_pos = cfg.text.len }
		else { return false }
	}
	w.input_state[w.focus_id].cursor_pos = cursor_pos
	return true
}
