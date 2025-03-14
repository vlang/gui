module gui

import gx

pub struct InputCfg {
pub:
	id              string
	text            string
	sizing          Sizing
	spacing         f32
	wrap            bool
	text_style      gx.TextCfg
	width           f32 = 50
	on_text_changed fn (&InputCfg, string, &Window) = unsafe { nil }
}

pub fn input(cfg InputCfg) &View {
	mut input := canvas(
		id:       cfg.id
		width:    cfg.width
		spacing:  cfg.spacing
		color:    rgb(0x40, 0x40, 0x40)
		fill:     true
		on_char:  fn [cfg] (c u32, mut w Window) {
			on_char(cfg, c, mut w)
		}
		children: [
			text(
				text:  cfg.text
				style: cfg.text_style
			),
		]
	)
	return input
}

fn on_char(cfg &InputCfg, c u32, mut window Window) {
	if cfg.on_text_changed != unsafe { nil } {
		t := cfg.text + rune(c).str()
		cfg.on_text_changed(cfg, t, window)
	}
}
