module gui

import os

const link_context_menu_id_focus = u32(0xC74E_0001)

// link_context_menu_view builds a floating menu positioned at the
// stored click coordinates with Open/Copy actions and a URL label.
fn link_context_menu_view(window &Window) View {
	url := window.view_state.link_context_menu_url
	x := window.view_state.link_context_menu_x
	y := window.view_state.link_context_menu_y
	is_anchor := url.starts_with('#')

	open_label := if is_anchor { gui_locale.str_go_to_target } else { gui_locale.str_open_link }
	subtitle_style := gui_theme.menubar_style.text_style_subtitle

	open_action := if is_anchor {
		make_link_scroll_action(url)
	} else {
		make_link_open_action(url)
	}

	cfg := MenubarCfg{
		id_focus: link_context_menu_id_focus
		items:    [
			MenuItemCfg{
				id:     'link-open'
				text:   open_label
				action: open_action
			},
			MenuItemCfg{
				id:     'link-copy'
				text:   gui_locale.str_copy_link
				action: make_link_copy_action(url)
			},
			menu_separator(),
			MenuItemCfg{
				id:          menu_subtitle_id
				disabled:    true
				custom_view: text(
					text:       url
					text_style: subtitle_style
					mode:       .multiline
				)
			},
		]
		action:   fn (_ string, mut _ Event, mut w Window) {
			w.dismiss_link_context_menu()
		}
	}

	return column(
		name:           'link_context_menu'
		color:          cfg.color
		float:          true
		float_anchor:   .top_left
		float_tie_off:  .top_left
		float_offset_x: x
		float_offset_y: y
		size_border:    cfg.size_border
		color_border:   cfg.color_border
		radius:         cfg.radius
		sizing:         cfg.sizing
		max_width:      300
		amend_layout:   make_menu_amend_layout(link_context_menu_id_focus)
		padding:        cfg.padding_submenu
		spacing:        cfg.spacing_submenu
		content:        menu_build(cfg, 1, cfg.items, window)
	)
}

fn make_link_open_action(url string) fn (&MenuItemCfg, mut Event, mut Window) {
	return fn [url] (_ &MenuItemCfg, mut _ Event, mut w Window) {
		os.open_uri(url) or {}
		w.dismiss_link_context_menu()
	}
}

fn make_link_copy_action(url string) fn (&MenuItemCfg, mut Event, mut Window) {
	return fn [url] (_ &MenuItemCfg, mut _ Event, mut w Window) {
		to_clipboard(url)
		w.dismiss_link_context_menu()
	}
}

fn make_link_scroll_action(url string) fn (&MenuItemCfg, mut Event, mut Window) {
	anchor := url[1..]
	return fn [anchor] (_ &MenuItemCfg, mut _ Event, mut w Window) {
		w.scroll_to_view(anchor)
		w.dismiss_link_context_menu()
	}
}
