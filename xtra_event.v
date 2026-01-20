module gui

// spacebar_to_click creates an on_char handler that fires on_click when
// spacebar is pressed. Enables keyboard activation for clickable elements.
fn spacebar_to_click(on_click fn (&Layout, mut Event, mut Window)) fn (&Layout, mut Event, mut Window) {
	if on_click == unsafe { nil } {
		return fn (_ &Layout, mut _ Event, mut _ Window) {}
	}
	return fn [on_click] (layout &Layout, mut e Event, mut w Window) {
		if e.char_code == ` ` {
			on_click(layout, mut e, mut w)
			e.is_handled = true
		}
	}
}

// left_click_only wraps a click handler to only fire on left mouse button.
fn left_click_only(on_click fn (&Layout, mut Event, mut Window)) fn (&Layout, mut Event, mut Window) {
	if on_click == unsafe { nil } {
		return on_click
	}
	return fn [on_click] (layout &Layout, mut e Event, mut w Window) {
		if e.mouse_button == .left {
			on_click(layout, mut e, mut w)
		}
	}
}
