module gui

fn test_expand_panel_defaults() {
	cfg := ExpandPanelCfg{
		id:      'test'
		head:    column(ContainerCfg{})
		content: column(ContainerCfg{})
	}
	assert cfg.id == 'test'
	assert cfg.open == false
}

fn test_expand_panel_layout() {
	mut val := 0
	_ := expand_panel(
		id:        'ep1'
		head:      text(text: 'Header')
		content:   text(text: 'Content')
		on_toggle: fn [mut val] (mut w Window) {
			val = 1
		}
	)
}
