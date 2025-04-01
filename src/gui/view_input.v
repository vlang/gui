module gui

import gg
import gx

pub struct InputCfg {
pub:
	id              string
	id_focus        u32 @[required] // !0 indicates input is focusable. Value indiciates tabbing order
	color           gx.Color   = gui_theme.color_input
	padding         Padding    = padding(5, 6, 6, 6)
	text_style      gx.TextCfg = gui_theme.text_cfg
	fill            bool       = true
	sizing          Sizing
	spacing         f32
	text            string
	width           f32
	min_width       f32
	max_width       f32
	wrap            bool
	radius          f32 = gui_theme.radius_input
	on_text_changed fn (&InputCfg, string, &Window) = unsafe { nil } @[required]
}

pub fn input(cfg InputCfg) View {
	assert cfg.id_focus != 0
	return row(
		id:         cfg.id
		id_focus:   cfg.id_focus
		width:      cfg.width
		min_width:  cfg.min_width
		max_width:  cfg.max_width
		spacing:    cfg.spacing
		color:      cfg.color
		padding:    cfg.padding
		sizing:     cfg.sizing
		cfg:        &InputCfg{
			...cfg
		}
		on_char:    on_char_input
		on_click:   on_click_input
		on_keydown: on_keydown_input
		fill:       cfg.fill
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
}

const bsp_c = 0x08
const del_c = 0x7F
const space_c = 0x20

fn on_char_input(cfg &InputCfg, event &gg.Event, mut w Window) bool {
	c := event.char_code
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
				return false
			}
			else {
				if !cfg.wrap && cfg.sizing.width == .fixed { // clamp max chars to width of box when single line.
					ctx := w.ui
					ctx.set_text_cfg(cfg.text_style)
					width := ctx.text_width(cfg.text + rune(c).str())
					if width > (cfg.width - cfg.padding.left - cfg.padding.right) {
						return true
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
		return true
	}
	return false
}

fn on_click_input(cfg &InputCfg, e &gg.Event, mut w Window) bool {
	if e.mouse_button == .left {
		w.input_state[w.id_focus].cursor_pos = cfg.text.len
		return true
	}
	return false
}

fn on_keydown_input(cfg &InputCfg, e &gg.Event, mut w Window) bool {
	mut cursor_pos := w.input_state[w.id_focus].cursor_pos
	match e.key_code {
		.left { cursor_pos = int_max(0, cursor_pos - 1) }
		.right { cursor_pos = int_min(cfg.text.len, cursor_pos + 1) }
		.home { cursor_pos = 0 }
		.end { cursor_pos = cfg.text.len }
		else { return false }
	}
	w.input_state[w.id_focus].cursor_pos = cursor_pos
	return true
}
