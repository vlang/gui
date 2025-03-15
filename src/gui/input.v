module gui

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
		id:       cfg.id
		width:    cfg.width
		spacing:  cfg.spacing
		color:    cfg.color
		fill:     true
		padding:  padding(5, 6, 6, 6)
		on_char:  fn [cfg] (c u32, mut w Window) {
			on_char(cfg, c, mut w)
		}
		children: [
			text(
				text:     cfg.text
				style:    cfg.text_style
				focus_id: cfg.focus_id
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

		t := match c {
			bsp, del { cfg.text#[0..-1].clone() }
			else { cfg.text + rune(c).str() }
		}
		cfg.on_text_changed(cfg, t, window)
	}
}
