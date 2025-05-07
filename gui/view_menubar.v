module gui

pub struct MenubarCfg {
pub:
	id        string
	id_menu   u32 @[required]
	disabled  bool
	invisible bool
	sizing    Sizing  = fill_fit
	padding   Padding = padding_none
	spacing   f32     = gui_theme.spacing_medium
	items     []View
}

pub fn menubar(cfg MenubarCfg) View {
	return row(
		id:        cfg.id
		disabled:  cfg.disabled
		invisible: cfg.invisible
		padding:   cfg.padding
		sizing:    cfg.sizing
		spacing:   cfg.spacing
		content:   cfg.items
	)
}
