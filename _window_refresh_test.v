module gui

fn test_mark_layout_refresh_clears_render_only() {
	mut w := Window{
		refresh_render_only: true
	}
	w.mark_layout_refresh()
	assert w.refresh_layout
	assert !w.refresh_render_only
}

fn test_mark_render_only_refresh_sets_when_layout_not_pending() {
	mut w := Window{}
	w.mark_render_only_refresh()
	assert !w.refresh_layout
	assert w.refresh_render_only
}

fn test_mark_render_only_refresh_skips_when_layout_pending() {
	mut w := Window{
		refresh_layout: true
	}
	w.mark_render_only_refresh()
	assert w.refresh_layout
	assert !w.refresh_render_only
}

fn test_max_animation_refresh_kind_prefers_layout() {
	kind := max_animation_refresh_kind(.render_only, .layout)
	assert kind == .layout
}

fn test_max_animation_refresh_kind_prefers_render_only_over_none() {
	kind := max_animation_refresh_kind(.none, .render_only)
	assert kind == .render_only
}

fn test_blink_cursor_animation_refresh_kind_is_render_only() {
	a := BlinkCursorAnimation{}
	assert a.refresh_kind() == .render_only
}

fn test_animate_refresh_kind_is_layout() {
	a := Animate{
		id:       'test'
		callback: fn (mut _ Animate, mut _ Window) {}
	}
	assert a.refresh_kind() == .layout
}
