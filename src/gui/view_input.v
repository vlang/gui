module gui

import gg
import gx

@[heap]
pub struct InputCfg {
pub:
	id              string
	id_focus        u32 @[required] // !0 indicates input is focusable. Value indiciates tabbing order
	text            string
	spacing         f32
	width           f32
	min_width       f32
	max_width       f32
	height          f32
	min_height      f32
	max_height      f32
	sizing          Sizing
	wrap            bool
	padding         Padding                         = padding(5, 6, 6, 6)
	color           gx.Color                        = gui_theme.input_style.color
	color_border    gx.Color                        = gui_theme.input_style.color_border
	fill            bool                            = gui_theme.input_style.fill
	fill_border     bool                            = gui_theme.input_style.fill_border
	padding_border  Padding                         = gui_theme.input_style.padding_border
	radius          f32                             = gui_theme.input_style.radius
	radius_border   f32                             = gui_theme.input_style.radius_border
	text_cfg        gx.TextCfg                      = gui_theme.input_style.text_cfg
	on_text_changed fn (&InputCfg, string, &Window) = unsafe { nil } @[required]
}

// input is a text input field.
// Example:
// ```v
// gui.input(
// 	id_focus:        1
// 	text:            app.input_a
// 	min_width:       100
// 	max_width:       100
// 	on_text_changed: fn (_ &gui.InputCfg, s string, mut w gui.Window) {
// 		mut state := w.state[App]()
// 		state.input_a = s
// 	}
// )
// ```
pub fn input(cfg InputCfg) View {
	assert cfg.id_focus != 0
	return row(
		id:         cfg.id
		id_focus:   cfg.id_focus
		width:      cfg.width
		height:     cfg.height
		min_width:  cfg.min_width
		max_width:  cfg.max_width
		min_height: cfg.min_height
		max_height: cfg.max_height
		padding:    cfg.padding_border
		color:      cfg.color_border
		fill:       cfg.fill_border
		sizing:     cfg.sizing
		radius:     cfg.radius_border
		on_char:    on_char_input
		on_click:   on_click_input
		on_keydown: on_keydown_input
		cfg:        &cfg
		content:    [
			row(
				color:      cfg.color
				padding:    cfg.padding
				spacing:    cfg.spacing
				fill:       cfg.fill
				sizing:     flex_flex
				radius:     cfg.radius
				min_width:  cfg.min_width - cfg.padding_border.left - cfg.padding_border.right
				max_width:  cfg.max_width - cfg.padding_border.left - cfg.padding_border.right
				min_height: cfg.min_height - cfg.padding_border.top - cfg.padding_border.bottom
				max_height: cfg.max_height - cfg.padding_border.top - cfg.padding_border.bottom
				content:    [
					text(
						id_focus:    cfg.id_focus
						text:        cfg.text
						style:       cfg.text_cfg
						wrap:        cfg.wrap
						keep_spaces: true
					),
				]
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
					ctx.set_text_cfg(cfg.text_cfg)
					width := ctx.text_width(cfg.text + rune(c).str())
					if width > (cfg.width - cfg.padding.left - cfg.padding.right) {
						return true
					}
				}
				if cursor_pos < 0 {
					t = cfg.text + rune(c).str()
					w.input_state[w.id_focus].cursor_pos = t.len
				} else {
					t = cfg.text[..cursor_pos] + rune(c).str() + cfg.text[cursor_pos..] or {
						w.input_state[w.id_focus].cursor_pos = cfg.text.len - 1
						return true
					}
					w.input_state[w.id_focus].cursor_pos = int_min(cursor_pos + 1, t.len)
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
