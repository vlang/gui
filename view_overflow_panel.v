module gui

// view_overflow_panel.v implements a layout-aware overflow panel.
// Children are shown in a row; those that don't fit are hidden and
// revealed in a floating dropdown menu when the trigger button is
// clicked. A dedicated layout pass (layout_overflow) determines
// which children fit, storing visible_count in ViewState so the
// view generator can build the dropdown with overflow items.

// OverflowItem pairs a toolbar View with a menu label for the
// dropdown fallback.
pub struct OverflowItem {
pub:
	id     string @[required]
	view   View   @[required] // toolbar representation
	text   string // menu label when overflowed
	action fn (&MenuItemCfg, mut Event, mut Window) = unsafe { nil }
}

// OverflowPanelCfg configures an [overflow_panel](#overflow_panel).
@[minify]
pub struct OverflowPanelCfg {
	A11yCfg
pub:
	id       string @[required]
	id_focus u32    @[required]
	items    []OverflowItem

	// Custom trigger button content; default: ellipsis icon.
	trigger []View

	padding Padding = gui_theme.button_style.padding

	// Dropdown positioning
	float_anchor   FloatAttach = .bottom_right
	float_tie_off  FloatAttach = .top_right
	float_offset_x f32
	float_offset_y f32

	spacing  f32 = gui_theme.spacing_small
	disabled bool
}

// overflow_panel creates a row that hides children that don't fit
// and shows them in a floating dropdown menu when the trigger is
// clicked. See [OverflowPanelCfg](#OverflowPanelCfg).
pub fn (window &Window) overflow_panel(cfg OverflowPanelCfg) View {
	// mut cast needed for state_map lazy-init; overflow_panel is
	// called during view generation where Window is conceptually mutable.
	mut w_mut := unsafe { &Window(window) }
	mut om := state_map[string, int](mut *w_mut, ns_overflow, cap_moderate)
	visible_count := om.get(cfg.id) or { cfg.items.len }
	mut ss := state_map[string, bool](mut *w_mut, ns_select, cap_moderate)
	is_open := ss.get(cfg.id) or { false }

	// Build content: all item views + trigger button (always last).
	// All items are emitted so the layout pass can measure real widths;
	// layout_overflow hides those that don't fit.
	mut content := []View{cap: cfg.items.len + 2}
	for item in cfg.items {
		content << item.view
	}

	// Trigger button
	trigger_content := if cfg.trigger.len > 0 {
		cfg.trigger
	} else {
		[
			View(text(
				text:       icon_elipsis_v
				text_style: TextStyle{
					...theme().text_style
					family: icon_font_name
				}
			)),
		]
	}

	// Extract captures for closure
	id := cfg.id
	id_focus := cfg.id_focus

	content << button(
		id:           cfg.id + '_trigger'
		id_focus:     cfg.id_focus
		color:        color_transparent
		color_hover:  color_transparent
		color_click:  color_transparent
		color_focus:  color_transparent
		color_border: color_transparent
		padding:      cfg.padding
		disabled:     cfg.disabled
		content:      trigger_content
		on_click:     fn [id, id_focus, is_open] (_ &Layout, mut e Event, mut w Window) {
			mut ss := state_map[string, bool](mut w, ns_select, cap_moderate)
			ss.clear()
			ss.set(id, !is_open)
			w.set_id_focus(id_focus)
			e.is_handled = true
		}
	)

	// Floating dropdown with overflow items as menu items
	if is_open && visible_count < cfg.items.len {
		mut menu_items := []MenuItemCfg{cap: cfg.items.len - visible_count}
		for item in cfg.items[visible_count..] {
			user_action := item.action
			menu_items << MenuItemCfg{
				id:     item.id
				text:   if item.text.len > 0 { item.text } else { item.id }
				action: fn [id, user_action] (mi &MenuItemCfg, mut e Event, mut w Window) {
					if user_action != unsafe { nil } {
						user_action(mi, mut e, mut w)
					}
					mut ss := state_map[string, bool](mut w, ns_select, cap_moderate)
					ss.delete(id)
				}
			}
		}
		content << window.menu(MenubarCfg{
			id:            cfg.id + '_menu'
			id_focus:      cfg.id_focus
			items:         menu_items
			float:         true
			float_anchor:  cfg.float_anchor
			float_tie_off: cfg.float_tie_off
		})
	}

	return row(
		id:       cfg.id
		overflow: true
		sizing:   fill_fit
		spacing:  cfg.spacing
		content:  content
	)
}
