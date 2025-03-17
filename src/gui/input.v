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
	on_text_changed fn (&InputCfg, string, &Window) = unsafe { nil }
}

pub fn input(cfg InputCfg) &View {
	mut input := canvas(
		id:         cfg.id
		width:      cfg.width
		spacing:    cfg.spacing
		color:      cfg.color
		fill:       true
		padding:    padding(5, 6, 6, 6)
		sizing:     cfg.sizing
		on_char:    fn [cfg] (c u32, mut w Window) {
			on_char(cfg, c, mut w)
		}
		on_click:   fn [cfg] (id string, me MouseEvent, mut w Window) {
			on_click(cfg, id, me, mut w)
		}
		on_keydown: fn [cfg] (c gg.KeyCode, m gg.Modifier, mut w Window) {
			on_keydown(cfg, c, m, mut w)
		}
		children:   [
			text(
				text:     cfg.text
				style:    cfg.text_style
				focus_id: cfg.focus_id
				wrap:     cfg.wrap
			),
		]
	)
	return input
}

const bsp_c = 0x08
const del_c = 0x7F
const ret_c = 0x0D
const space_c = 0x20

fn on_char(cfg &InputCfg, c u32, mut w Window) {
	if cfg.on_text_changed != unsafe { nil } {
		match c {
			ret_c { return }
			else {}
		}

		mut t := ''
		match c {
			bsp_c, del_c {
				if w.get_cursor_offset() < 0 {
					w.set_cursor_offset(cfg.text.len)
				} else if w.get_cursor_offset() > 0 {
					t = cfg.text[..w.get_cursor_offset() - 1] + cfg.text[w.get_cursor_offset()..]
					w.set_cursor_offset(w.get_cursor_offset() - 1)
				}
			}
			else {
				if w.get_cursor_offset() < 0 {
					t = cfg.text + rune(c).str()
					w.set_cursor_offset(t.len)
				} else {
					t = cfg.text[..w.get_cursor_offset()] + rune(c).str() +
						cfg.text[w.get_cursor_offset()..]
					w.set_cursor_offset(w.get_cursor_offset() + 1)
				}
			}
		}
		cfg.on_text_changed(cfg, t, w)
	}
}

fn on_click(cfg &InputCfg, id string, me MouseEvent, mut w Window) {
	println(cfg.focus_id)
}

fn on_keydown(cfg &InputCfg, c gg.KeyCode, m gg.Modifier, mut w Window) {
	match c {
		.left { w.set_cursor_offset(int_max(0, w.cursor_offset - 1)) }
		.right { w.set_cursor_offset(int_min(cfg.text.len, w.cursor_offset + 1)) }
		.home { w.set_cursor_offset(0) }
		.end { w.set_cursor_offset(-1) }
		else { return }
	}
	w.ui.refresh_ui()
}
