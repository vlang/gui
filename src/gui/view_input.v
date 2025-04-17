module gui

@[heap]
pub struct InputCfg {
	CommonCfg
pub:
	id_focus u32 @[required] // !0 indicates input is focusable. Value indiciates tabbing order
	text     string
	// spacing            f32
	wrap               bool
	padding            Padding                         = gui_theme.input_style.padding
	padding_border     Padding                         = gui_theme.input_style.padding_border
	color              Color                           = gui_theme.input_style.color
	color_border       Color                           = gui_theme.input_style.color_border
	color_border_focus Color                           = gui_theme.input_style.color_border_focus
	fill               bool                            = gui_theme.input_style.fill
	fill_border        bool                            = gui_theme.input_style.fill_border
	radius             f32                             = gui_theme.input_style.radius
	radius_border      f32                             = gui_theme.input_style.radius_border
	text_style         TextStyle                       = gui_theme.input_style.text_style
	on_text_changed    fn (&InputCfg, string, &Window) = unsafe { nil } @[required]
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
		id:           cfg.id
		id_focus:     cfg.id_focus
		width:        cfg.width
		height:       cfg.height
		min_width:    cfg.min_width
		max_width:    cfg.max_width
		min_height:   cfg.min_height
		max_height:   cfg.max_height
		padding:      cfg.padding_border
		color:        cfg.color_border
		fill:         cfg.fill_border
		sizing:       cfg.sizing
		radius:       cfg.radius_border
		disabled:     cfg.disabled
		invisible:    cfg.invisible
		on_char:      on_char_input
		amend_layout: cfg.amend_layout
		cfg:          &cfg
		content:      [
			row(
				color:   cfg.color
				padding: cfg.padding
				// spacing: cfg.spacing
				fill:    cfg.fill
				sizing:  fill_fill
				radius:  cfg.radius
				content: [
					text(
						id_focus:    cfg.id_focus
						text:        cfg.text
						text_style:  cfg.text_style
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

fn on_char_input(cfg &InputCfg, event &Event, mut w Window) bool {
	c := event.char_code
	if cfg.on_text_changed != unsafe { nil } {
		mut t := cfg.text
		input_state := w.input_state[w.id_focus]
		mut cursor_pos := input_state.cursor_pos
		match c {
			bsp_c, del_c {
				if cursor_pos < 0 {
					cursor_pos = cfg.text.len
				} else if cursor_pos > 0 {
					t = cfg.text[..cursor_pos - 1] + cfg.text[cursor_pos..]
					cursor_pos -= 1
				}
			}
			0...0x1F { // non-printables
				return false
			}
			else {
				if !cfg.wrap && cfg.sizing.width == .fixed { // clamp max chars to width of box when single line.
					ctx := w.ui
					ctx.set_text_cfg(cfg.text_style.to_text_cfg())
					width := ctx.text_width(cfg.text + rune(c).str())
					if width > (cfg.width - cfg.padding.left - cfg.padding.right) {
						return true
					}
				}
				if cursor_pos < 0 {
					t = cfg.text + rune(c).str()
					cursor_pos = t.len
				} else {
					t = cfg.text[..cursor_pos] + rune(c).str() + cfg.text[cursor_pos..] or {
						w.input_state[w.id_focus] = InputState{
							...input_state
							cursor_pos: cfg.text.len - 1
						}
						return true
					}
					cursor_pos = int_min(cursor_pos + 1, t.len)
				}
			}
		}
		w.input_state[w.id_focus] = InputState{
			...input_state
			cursor_pos: cursor_pos
		}
		cfg.on_text_changed(cfg, t, w)
		return true
	}
	return false
}

fn (cfg InputCfg) amend_layout(mut node Layout, mut w Window) {
	if node.shape.disabled {
		return
	}
	if node.shape.id_focus > 0 && node.shape.id_focus == w.id_focus() {
		node.shape.color = cfg.color_border_focus
	}
}
