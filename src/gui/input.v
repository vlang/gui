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

const bsp = 0x08
const del = 0x7F
const ret = 0x0D

fn on_char(cfg &InputCfg, c u32, mut window Window) {
	if cfg.on_text_changed != unsafe { nil } {
		match c {
			ret { return }
			else {}
		}

		mut t := ''
		match c {
			bsp, del {
				if window.cursor_offset < 0 {
					window.cursor_offset = cfg.text.len
				} else if window.cursor_offset > 0 {
					t = cfg.text[..window.cursor_offset - 1] + cfg.text[window.cursor_offset..]
					window.cursor_offset -= 1
				}
			}
			else {
				if window.cursor_offset < 0 {
					t = cfg.text + rune(c).str()
					window.cursor_offset = t.len
				} else {
					t = cfg.text[..window.cursor_offset] + rune(c).str() +
						cfg.text[window.cursor_offset..]
					window.cursor_offset += 1
				}
			}
		}
		cfg.on_text_changed(cfg, t, window)
	}
}

fn on_click(cfg &InputCfg, id string, me MouseEvent, mut w Window) {
	println(cfg.focus_id)
}

fn on_keydown(cfg &InputCfg, c gg.KeyCode, m gg.Modifier, mut w Window) {
	match c {
		.left { w.cursor_offset = int_max(0, w.cursor_offset - 1) }
		.right { w.cursor_offset = int_min(cfg.text.len, w.cursor_offset + 1) }
		.home { w.cursor_offset = 0 }
		.end { w.cursor_offset = -1 }
		else { return }
	}
	w.ui.refresh_ui()
}
