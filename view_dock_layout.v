module gui

// view_dock_layout.v — DockLayoutCfg, DockPanelDef, recursive
// view generation (split → splitter, panel_group → tab header +
// content), and dock-drag integration.

// DockPanelDef defines a single panel that can appear in the
// dock layout. Maps panel_id to label and content views.
pub struct DockPanelDef {
pub:
	id       string @[required]
	label    string @[required]
	content  []View @[required]
	closable bool = true
}

// DockLayoutCfg configures a dock layout component.
pub struct DockLayoutCfg {
pub:
	id                  string                     @[required]
	root                &DockNode                  @[required]
	panels              []DockPanelDef             @[required]
	on_layout_change    fn (&DockNode, mut Window) @[required]
	on_panel_select     fn (string, string, mut Window) = unsafe { nil } // (group_id, panel_id)
	on_panel_close      fn (string, mut Window)         = unsafe { nil }
	sizing              Sizing = fill_fill
	color_zone_preview  Color  = Color{70, 130, 220, 80}
	color_tab           Color  = gui_theme.color_panel
	color_tab_active    Color  = gui_theme.color_panel
	color_tab_hover     Color  = gui_theme.color_hover
	color_tab_bar       Color  = gui_theme.color_panel
	color_tab_separator Color  = gui_theme.color_border
	color_content       Color  = gui_theme.color_background
}

// DockLayoutCore holds callback-relevant fields without content
// arrays. Captured in closures to avoid GC false retention of the
// full DockLayoutCfg (which holds []DockPanelDef with []View).
@[heap]
struct DockLayoutCore {
	id                 string
	root               &DockNode
	on_layout_change   fn (&DockNode, mut Window) @[required]
	on_panel_select    fn (string, string, mut Window) = unsafe { nil }
	on_panel_close     fn (string, mut Window)         = unsafe { nil }
	color_zone_preview Color
}

fn dock_layout_core(cfg &DockLayoutCfg) &DockLayoutCore {
	return &DockLayoutCore{
		id:                 cfg.id
		root:               cfg.root
		on_layout_change:   cfg.on_layout_change
		on_panel_select:    cfg.on_panel_select
		on_panel_close:     cfg.on_panel_close
		color_zone_preview: cfg.color_zone_preview
	}
}

// DockLayoutView is the View implementation for dock_layout.
// Using a custom View struct gives generate_layout access to
// mut Window, which is needed to read DockDragState for ghost
// rendering during view generation.
@[heap]
struct DockLayoutView implements View {
	cfg DockLayoutCfg
mut:
	content []View
}

// dock_layout creates a docking layout component. Renders a tree
// of splitters and tabbed panel groups. Supports drag-and-drop
// panel rearrangement.
pub fn dock_layout(cfg DockLayoutCfg) View {
	return DockLayoutView{
		cfg: cfg
	}
}

fn (mut dv DockLayoutView) generate_layout(mut w Window) Layout {
	cfg := dv.cfg
	core := dock_layout_core(&cfg)
	drag := dock_drag_get(mut w, cfg.id)

	mut content := []View{cap: 2}
	content << dock_node_view(core, cfg.root, cfg, drag)
	// Zone overlay — positioned by amend_layout, hidden when no drag.
	content << dock_drag_zone_overlay_view(cfg.color_zone_preview)

	// Ghost tab label while dragging.
	if drag.active {
		ghost_label := dock_find_panel_label(cfg.panels, drag.panel_id)
		if ghost_label.len > 0 {
			content << dock_drag_ghost_view(drag, ghost_label)
		}
	}

	dock_id := core.id
	color_zone := core.color_zone_preview

	mut cv := canvas(ContainerCfg{
		name:         'dock_layout'
		id:           cfg.id
		sizing:       cfg.sizing
		padding:      padding_none
		spacing:      0
		clip:         true
		amend_layout: fn [dock_id, color_zone] (mut layout Layout, mut w Window) {
			dock_layout_amend(dock_id, color_zone, mut layout, mut w)
		}
		on_keydown:   fn [dock_id] (_ &Layout, mut e Event, mut w Window) {
			if e.key_code == .escape {
				state := dock_drag_get(mut w, dock_id)
				if state.active {
					dock_drag_cancel(dock_id, mut w)
					e.is_handled = true
				}
			}
		}
		content:      content
	})

	return generate_layout(mut cv, mut w)
}

// dock_layout_amend positions the single child (tree view) to fill
// the dock container, and positions the zone overlay.
fn dock_layout_amend(dock_id string, color_zone Color, mut layout Layout, mut w Window) {
	if layout.children.len < 1 {
		return
	}
	// First child is the tree view — fill the entire dock area.
	splitter_layout_child(mut layout.children[0], layout.shape.x, layout.shape.y, layout.shape.width,
		layout.shape.height, mut w)
	// Second child (zone overlay) is positioned by dock_drag_amend_overlay.
	if layout.children.len >= 2 {
		dock_drag_amend_overlay(dock_id, color_zone, mut layout, mut w)
	}
}

// dock_node_view recursively generates views for the dock tree.
fn dock_node_view(core &DockLayoutCore, node &DockNode, cfg DockLayoutCfg, drag DockDragState) View {
	if node.kind == .split {
		return dock_split_view(core, node, cfg, drag)
	}
	return dock_group_view(core, node, cfg, drag)
}

// dock_split_view generates a splitter for a DockSplit node.
fn dock_split_view(core &DockLayoutCore, node &DockNode, cfg DockLayoutCfg, drag DockDragState) View {
	split_id := node.id
	root := core.root
	on_layout_change := core.on_layout_change

	return splitter(
		id:          'dock_split:${node.id}'
		orientation: if node.dir == .horizontal {
			SplitterOrientation.horizontal
		} else {
			SplitterOrientation.vertical
		}
		ratio:       node.ratio
		sizing:      fill_fill
		on_change:   fn [split_id, root, on_layout_change] (ratio f32, _ SplitterCollapsed, mut _ Event, mut w Window) {
			new_root := dock_tree_update_ratio(root, split_id, ratio)
			on_layout_change(new_root, mut w)
		}
		first:       SplitterPaneCfg{
			content: if node.first != unsafe { nil } {
				[dock_node_view(core, node.first, cfg, drag)]
			} else {
				[]View{}
			}
		}
		second:      SplitterPaneCfg{
			content: if node.second != unsafe { nil } {
				[dock_node_view(core, node.second, cfg, drag)]
			} else {
				[]View{}
			}
		}
	)
}

// dock_group_view generates a tab header + content area for a
// DockPanelGroup node.
fn dock_group_view(core &DockLayoutCore, group &DockNode, cfg DockLayoutCfg, drag DockDragState) View {
	dragging := drag.active && drag.source_group == group.id

	mut tab_buttons := []View{cap: group.panel_ids.len}
	mut active_content := []View{}

	color_sep := cfg.color_tab_separator
	for panel_id in group.panel_ids {
		panel_def := dock_find_panel_def(cfg.panels, panel_id) or { continue }
		is_selected := panel_id == group.selected_id
		is_dragged := dragging && drag.panel_id == panel_id

		if is_dragged {
			continue
		}

		if is_selected {
			active_content = unsafe { panel_def.content }
		}

		if tab_buttons.len > 0 {
			tab_buttons << column(width: 1, sizing: fixed_fill, color: color_sep)
		}
		tab_buttons << dock_tab_button(core, group, panel_def, is_selected, cfg)
	}

	// If selected tab was dragged out, show first remaining.
	if active_content.len == 0 && group.panel_ids.len > 0 {
		for pid in group.panel_ids {
			if dragging && drag.panel_id == pid {
				continue
			}
			if pd := dock_find_panel_def(cfg.panels, pid) {
				active_content = unsafe { pd.content }
				break
			}
		}
	}

	mut group_content := []View{cap: 2}

	// Tab header row.
	group_content << row(
		name:    'dock_tab_bar'
		sizing:  fill_fit
		padding: padding(2, 4, 0, 4)
		spacing: 0
		color:   cfg.color_tab_bar
		content: tab_buttons
	)

	// Content area.
	group_content << column(
		name:    'dock_content'
		sizing:  fill_fill
		padding: padding_none
		spacing: 0
		clip:    true
		color:   cfg.color_content
		content: active_content
	)

	return column(
		name:    'dock_panel_group'
		id:      group.id
		sizing:  fill_fill
		padding: padding_none
		spacing: 0
		clip:    true
		content: group_content
	)
}

// dock_tab_button creates a single tab button in a panel group header.
fn dock_tab_button(core &DockLayoutCore, group &DockNode, panel DockPanelDef, is_selected bool, cfg DockLayoutCfg) View {
	panel_id := panel.id
	group_id := group.id
	dock_id := core.id
	root := core.root
	on_layout_change := core.on_layout_change
	on_panel_select := core.on_panel_select
	on_panel_close := core.on_panel_close

	color_tab := if is_selected { cfg.color_tab_active } else { cfg.color_tab }
	color_hover := cfg.color_tab_hover

	mut btn_content := []View{cap: 2}
	btn_content << text(text: panel.label)
	if panel.closable && on_panel_close != unsafe { nil } {
		btn_content << button(
			id:          'dock_close:${panel_id}'
			width:       14
			height:      14
			sizing:      fixed_fixed
			padding:     padding_none
			size_border: 0
			color:       color_transparent
			color_hover: gui_theme.color_hover
			radius:      2
			on_click:    fn [on_panel_close, panel_id] (_ &Layout, mut _ Event, mut w Window) {
				on_panel_close(panel_id, mut w)
			}
			content:     [
				text(
					text:       icon_close
					text_style: TextStyle{
						...gui_theme.icon2
						size: 10
					}
				),
			]
		)
	}

	return button(
		id:          'dock_tab:${group_id}:${panel_id}'
		sizing:      fill_fit
		h_align:     .left
		padding:     padding(4, 8, 4, 8)
		radius:      0
		size_border: 0
		color:       color_tab
		color_hover: color_hover
		on_click:    fn [dock_id, panel_id, group_id, root, on_layout_change, on_panel_select] (layout &Layout, mut e Event, mut w Window) {
			dock_drag_start(dock_id, panel_id, group_id, root, on_layout_change, layout,
				e, mut w)
			if on_panel_select != unsafe { nil } {
				on_panel_select(group_id, panel_id, mut w)
			}
			e.is_handled = true
		}
		content:     btn_content
	)
}

// dock_find_panel_def looks up a panel definition by id.
fn dock_find_panel_def(panels []DockPanelDef, panel_id string) ?DockPanelDef {
	for p in panels {
		if p.id == panel_id {
			return p
		}
	}
	return none
}

// dock_find_panel_label returns the label for a panel id.
fn dock_find_panel_label(panels []DockPanelDef, panel_id string) string {
	for p in panels {
		if p.id == panel_id {
			return p.label
		}
	}
	return ''
}

// dock_tree_update_ratio returns a new tree with the ratio of the
// given split updated.
fn dock_tree_update_ratio(root &DockNode, split_id string, ratio f32) &DockNode {
	return dock_tree_update_ratio_rec(root, split_id, ratio)
}

fn dock_tree_update_ratio_rec(nd &DockNode, split_id string, ratio f32) &DockNode {
	orig := unsafe { nd }
	if nd.kind == .split {
		if nd.id == split_id {
			return dock_split(nd.id, nd.dir, ratio, nd.first, nd.second)
		}
		if nd.first == unsafe { nil } || nd.second == unsafe { nil } {
			return orig
		}
		new_first := dock_tree_update_ratio_rec(nd.first, split_id, ratio)
		new_second := dock_tree_update_ratio_rec(nd.second, split_id, ratio)
		if new_first != nd.first || new_second != nd.second {
			return dock_split(nd.id, nd.dir, nd.ratio, new_first, new_second)
		}
	}
	return orig
}
