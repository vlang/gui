module gui

// inspector.v — Runtime inspector overlay for layout debugging.
// Injected as floating layout in layout_arrange (same as dialogs).
// Gated by $if !prod; zero overhead in production builds.
// F12 toggles. Shows layout tree, property panel, wireframe.

const ns_inspector = 'gui.inspector'
const ns_inspector_width = 'gui.inspector.w'
const cap_inspector = 8
const inspector_id_focus = u32(0xFFF00000)
const inspector_id_scroll_panel = u32(0xFFF00001)
const inspector_tree_id = '__inspector_tree__'
const inspector_panel_min_width = f32(300)
const inspector_resize_step = f32(50)
const inspector_margin = f32(10)
const inspector_text_style = TextStyle{
	size:  12
	color: Color{220, 220, 220, 255}
}
const inspector_icon_style = TextStyle{
	family: icon_font_name
	size:   12
	color:  Color{220, 220, 220, 255}
}

// InspectorStackFrame is a stack entry for iterative tree walk.
struct InspectorStackFrame {
	nodes []TreeNodeCfg
mut:
	pos int
}

// InspectorNodeProps snapshots shape properties as values
// so the properties panel can display them after layout_clear.
struct InspectorNodeProps {
	type_name    string
	id           string
	x            f32
	y            f32
	width        f32
	height       f32
	sizing       Sizing
	padding      Padding
	spacing      f32
	color        Color
	radius       f32
	id_focus     u32
	id_scroll    u32
	is_float     bool
	clip         bool
	opacity      f32
	events       string // pre-formatted handler list
	text_preview string // truncated text content
	children     int
}

// inspector_toggle flips the inspector overlay on/off.
@[if !prod]
fn inspector_toggle(mut w Window) {
	w.inspector_enabled = !w.inspector_enabled
	w.update_window()
}

// inspector_is_left returns true when the panel is
// docked to the left side. Default is right.
fn inspector_is_left(w &Window) bool {
	sm := state_map_read[string, string](w, ns_inspector) or { return false }
	return (sm.get('side') or { '' }) == 'left'
}

// inspector_toggle_side flips the panel between left
// and right docking.
fn inspector_toggle_side(mut w Window) {
	mut sm := state_map[string, string](mut w, ns_inspector, cap_inspector)
	cur := sm.get('side') or { '' }
	sm.set('side', if cur == 'left' { '' } else { 'left' })
	w.update_window()
}

// inspector_panel_width reads the stored width or returns
// the default minimum.
fn inspector_panel_width(w &Window) f32 {
	sm := state_map_read[string, f32](w, ns_inspector_width) or { return inspector_panel_min_width }
	return sm.get('width') or { inspector_panel_min_width }
}

// inspector_resize adjusts panel width by delta, clamped
// to [min_width, 80% window width].
fn inspector_resize(delta f32, mut w Window) {
	ww, _ := w.window_size()
	max_w := f32(ww) * 0.8
	cur := inspector_panel_width(w)
	new_w := f32_clamp(cur + delta, inspector_panel_min_width, max_w)
	mut sm := state_map[string, f32](mut w, ns_inspector_width, cap_inspector)
	sm.set('width', new_w)
	w.update_window()
}

// inspector_floating_panel builds the inspector view.
// Called from layout_arrange; uses cached tree nodes from
// the previous frame (saved before layout_clear).
fn inspector_floating_panel(mut w Window) View {
	_, wh := w.window_size()
	panel_h := f32(wh) - inspector_margin * 2
	panel_w := inspector_panel_width(w)

	mut content := []View{cap: 3}
	content << inspector_help_bar()
	content << inspector_tree_view(mut w)
	inspector_apply_scroll_to(panel_h, mut w)

	sb_cfg := &ScrollbarCfg{
		color_thumb: rgba(255, 255, 255, 80)
	}
	left := inspector_is_left(w)
	return column(
		float:           true
		float_anchor:    if left { .top_left } else { .top_right }
		float_tie_off:   if left { .top_left } else { .top_right }
		float_offset_x:  if left { inspector_margin } else { -inspector_margin }
		float_offset_y:  inspector_margin
		width:           panel_w
		height:          panel_h
		sizing:          fixed_fixed
		color:           rgba(20, 20, 20, 230)
		radius:          8
		clip:            true
		id_scroll:       inspector_id_scroll_panel
		scrollbar_cfg_x: sb_cfg
		scrollbar_cfg_y: sb_cfg
		padding:         Padding{
			right: gui_theme.scrollbar_style.size + gui_theme.scrollbar_style.gap_edge * 2
		}
		spacing:         0
		on_click:        fn (_ &Layout, mut e Event, mut _ Window) {
			e.is_handled = true
		}
		content:         content
	)
}

// inspector_help_bar returns a small text line showing
// keyboard shortcuts for the inspector.
fn inspector_help_bar() View {
	return text(
		text:       '  F12 toggle  Ctrl+\u2190\u2192 resize  Ctrl+\u2191 side'
		text_style: TextStyle{
			size:  10
			color: rgba(130, 130, 130, 200)
		}
	)
}

// inspector_tree_view builds the tree widget from cached
// previous-frame tree nodes. No fixed height or virtualization;
// tree grows to content, panel scroll handles overflow.
fn inspector_tree_view(mut w Window) View {
	nodes := w.inspector_tree_cache
	return w.tree(TreeCfg{
		id:        inspector_tree_id
		id_focus:  inspector_id_focus
		indent:    16
		spacing:   1
		nodes:     nodes
		on_select: fn (id string, mut w Window) {
			inspector_select(id, mut w)
		}
	})
}

// inspector_select sets the selected node path in inspector
// state and expands it in the tree. Shared by tree click
// and pick-to-select.
fn inspector_select(path string, mut w Window) {
	if path.starts_with('__prop_') {
		return
	}
	mut sm := state_map[string, string](mut w, ns_inspector, cap_inspector)
	old := sm.get('selected') or { '' }
	if old == path {
		sm.set('selected', '')
	} else {
		sm.set('selected', path)
		sm.set('scroll_to', path)
		mut tree_map := w.view_state.tree_state.get(inspector_tree_id) or {
			map[string]bool{}
		}
		// Expand selected node and all ancestors.
		tree_map[path] = true
		parts := path.split('.')
		mut prefix := parts[0]
		tree_map[prefix] = true
		for i in 1 .. parts.len {
			prefix += '.${parts[i]}'
			tree_map[prefix] = true
		}
		w.view_state.tree_state.set(inspector_tree_id, tree_map)
	}
	w.update_window()
}

// inspector_pick_path walks app content layout depth-first
// in reverse child order (matching z-order) and returns
// the dot-path of the deepest node containing (x, y).
// Called inside $if !prod; no attribute needed.
fn inspector_pick_path(layout &Layout, x f32, y f32) string {
	if layout.children.len == 0 {
		return ''
	}
	return inspector_pick_recurse(layout.children[0], '0', x, y)
}

// inspector_pick_recurse depth-first reverse-child walk.
fn inspector_pick_recurse(layout &Layout, path string, x f32, y f32) string {
	if layout.shape == unsafe { nil } {
		return ''
	}
	if !layout.shape.point_in_shape(x, y) {
		return ''
	}
	// Reverse order: later children are on top (higher z).
	for i := layout.children.len - 1; i >= 0; i-- {
		child_path := '${path}.${i}'
		result := inspector_pick_recurse(layout.children[i], child_path, x, y)
		if result.len > 0 {
			return result
		}
	}
	return path
}

// inspector_selected_path returns the currently selected
// node path from state.
fn inspector_selected_path(w &Window) string {
	sm := state_map_read[string, string](w, ns_inspector) or { return '' }
	return sm.get('selected') or { '' }
}

// inspector_build_tree_nodes converts the layout tree to
// TreeNodeCfg array and populates the props cache.
// Walks children[0] only (app content). Injects property
// child nodes into the selected node.
fn inspector_build_tree_nodes(layout &Layout, selected string, mut props map[string]InspectorNodeProps) []TreeNodeCfg {
	if layout.children.len == 0 {
		return []
	}
	return inspector_layout_to_tree(layout.children[0], '0', selected, mut props)
}

// inspector_layout_to_tree recursively converts a layout
// subtree into tree nodes, caching props for each node.
// When path matches selected, property leaf nodes are
// appended as children.
fn inspector_layout_to_tree(layout &Layout, path string, selected string, mut props map[string]InspectorNodeProps) []TreeNodeCfg {
	label := inspector_node_label(layout.shape)
	p := inspector_snapshot_props(layout)
	props[path] = p
	mut child_nodes := []TreeNodeCfg{cap: layout.children.len + 16}
	// Properties first so they're visible at the top
	if path == selected {
		child_nodes << inspector_props_nodes(p)
	}
	for i, child in layout.children {
		child_path := '${path}.${i}'
		child_nodes << inspector_layout_to_tree(child, child_path, selected, mut props)
	}
	return [
		TreeNodeCfg{
			id:              path
			text:            label
			text_style:      inspector_text_style
			text_style_icon: inspector_icon_style
			nodes:           child_nodes
		},
	]
}

// inspector_props_nodes builds leaf TreeNodeCfg entries
// for each non-default property value.
fn inspector_props_nodes(p InspectorNodeProps) []TreeNodeCfg {
	prop_style := TextStyle{
		size:  11
		color: rgba(140, 180, 220, 255)
	}
	prop_icon_style := TextStyle{
		size:   11
		family: icon_font_name
		color:  rgba(140, 180, 220, 255)
	}
	mut nodes := []TreeNodeCfg{cap: 16}
	if p.text_preview.len > 0 {
		nodes << TreeNodeCfg{
			id:              '__prop_text'
			text:            'text: "${p.text_preview}"'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	if p.id.len > 0 {
		nodes << TreeNodeCfg{
			id:              '__prop_id'
			text:            'id: ${p.id}'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	nodes << TreeNodeCfg{
		id:              '__prop_pos'
		text:            'pos: ${int(p.x)}, ${int(p.y)}'
		text_style:      prop_style
		text_style_icon: prop_icon_style
	}
	nodes << TreeNodeCfg{
		id:              '__prop_size'
		text:            'size: ${int(p.width)} x ${int(p.height)}'
		text_style:      prop_style
		text_style_icon: prop_icon_style
	}
	if p.sizing.width != .fit || p.sizing.height != .fit {
		nodes << TreeNodeCfg{
			id:              '__prop_sizing'
			text:            'sizing: ${p.sizing.width}, ${p.sizing.height}'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	if !p.padding.is_none() {
		nodes << TreeNodeCfg{
			id:              '__prop_pad'
			text:            'pad: ${int(p.padding.top)} ${int(p.padding.right)} ${int(p.padding.bottom)} ${int(p.padding.left)}'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	if p.spacing > 0 {
		nodes << TreeNodeCfg{
			id:              '__prop_spacing'
			text:            'spacing: ${int(p.spacing)}'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	if p.color.a > 0 {
		nodes << TreeNodeCfg{
			id:              '__prop_color'
			text:            'color: ${inspector_color_str(p.color)}'
			icon:            '\u2588'
			text_style:      prop_style
			text_style_icon: TextStyle{
				size:  11
				color: p.color
			}
		}
	}
	if p.radius > 0 {
		nodes << TreeNodeCfg{
			id:              '__prop_radius'
			text:            'radius: ${int(p.radius)}'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	if p.id_focus > 0 {
		nodes << TreeNodeCfg{
			id:              '__prop_focus'
			text:            'id_focus: ${p.id_focus}'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	if p.id_scroll > 0 {
		nodes << TreeNodeCfg{
			id:              '__prop_scroll'
			text:            'id_scroll: ${p.id_scroll}'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	if p.is_float {
		nodes << TreeNodeCfg{
			id:              '__prop_float'
			text:            'float: true'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	if p.clip {
		nodes << TreeNodeCfg{
			id:              '__prop_clip'
			text:            'clip: true'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	if p.opacity < 1.0 {
		nodes << TreeNodeCfg{
			id:              '__prop_opacity'
			text:            'opacity: ${p.opacity:.2f}'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	if p.events.len > 0 {
		nodes << TreeNodeCfg{
			id:              '__prop_events'
			text:            'events: ${p.events}'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	if p.children > 0 {
		nodes << TreeNodeCfg{
			id:              '__prop_children'
			text:            'children: ${p.children}'
			text_style:      prop_style
			text_style_icon: prop_icon_style
		}
	}
	return nodes
}

// inspector_snapshot_props captures shape properties as
// plain values for the properties panel.
fn inspector_snapshot_props(layout &Layout) InspectorNodeProps {
	shape := layout.shape
	if shape == unsafe { nil } {
		return InspectorNodeProps{}
	}
	mut text_preview := ''
	if shape.tc != unsafe { nil } && shape.tc.text.len > 0 {
		text_preview = if shape.tc.text.len > 30 {
			shape.tc.text[..30] + '...'
		} else {
			shape.tc.text
		}
	}
	return InspectorNodeProps{
		type_name:    inspector_type_name(shape)
		id:           shape.id
		x:            shape.x
		y:            shape.y
		width:        shape.width
		height:       shape.height
		sizing:       shape.sizing
		padding:      shape.padding
		spacing:      shape.spacing
		color:        shape.color
		radius:       shape.radius
		id_focus:     shape.id_focus
		id_scroll:    shape.id_scroll
		is_float:     shape.float
		clip:         shape.clip
		opacity:      shape.opacity
		events:       if shape.has_events() {
			inspector_events_str(shape.events)
		} else {
			''
		}
		text_preview: text_preview
		children:     layout.children.len
	}
}

// inspector_node_label formats a node label from shape info.
// Format: "{type} {w}x{h}" + " #{id}" if set.
fn inspector_node_label(shape &Shape) string {
	if shape == unsafe { nil } {
		return '(nil)'
	}
	type_name := inspector_type_name(shape)
	w := int(shape.width)
	h := int(shape.height)
	mut label := '${type_name} ${w}x${h}'
	if shape.id.len > 0 {
		label += ' #${shape.id}'
	}
	return label
}

// inspector_type_name maps shape_type + axis to a human name.
fn inspector_type_name(shape &Shape) string {
	return match shape.shape_type {
		.text {
			'text'
		}
		.image {
			'image'
		}
		.circle {
			'circle'
		}
		.rtf {
			'rtf'
		}
		.svg {
			'svg'
		}
		.none, .rectangle {
			match shape.axis {
				.top_to_bottom { 'column' }
				.left_to_right { 'row' }
				.none { 'canvas' }
			}
		}
	}
}

// inspector_find_by_path looks up a layout node by
// dot-separated index path (e.g. "0.2.1").
fn inspector_find_by_path(layout &Layout, path string) ?Layout {
	parts := path.split('.')
	mut node := unsafe { layout }
	for part in parts {
		idx := part.int()
		if idx < 0 || idx >= node.children.len {
			return none
		}
		node = &node.children[idx]
	}
	return *node
}

// inspector_inject_wireframe appends DrawStrokeRect
// renderers for the selected node.
@[if !prod]
fn inspector_inject_wireframe(mut w Window) {
	selected := inspector_selected_path(w)
	if selected.len == 0 {
		return
	}
	node := inspector_find_by_path(&w.layout, selected) or { return }
	shape := node.shape
	if shape == unsafe { nil } {
		return
	}

	// Cyan border for element bounds
	w.renderers << Renderer(DrawStrokeRect{
		x:         shape.x
		y:         shape.y
		w:         shape.width
		h:         shape.height
		radius:    shape.radius
		color:     rgba(0, 255, 255, 200).to_gx_color()
		thickness: 2
	})

	// Green border for content area (inside padding)
	if !shape.padding.is_none() {
		w.renderers << Renderer(DrawStrokeRect{
			x:         shape.x + shape.padding.left
			y:         shape.y + shape.padding.top
			w:         f32_max(0, shape.width - shape.padding.left - shape.padding.right)
			h:         f32_max(0, shape.height - shape.padding.top - shape.padding.bottom)
			radius:    0
			color:     rgba(0, 200, 0, 150).to_gx_color()
			thickness: 1
		})
	}
}

// inspector_events_str formats attached event handler names.
fn inspector_events_str(eh &EventHandlers) string {
	if eh == unsafe { nil } {
		return ''
	}
	mut names := []string{cap: 8}
	if eh.on_click != unsafe { nil } {
		names << 'click'
	}
	if eh.on_char != unsafe { nil } {
		names << 'char'
	}
	if eh.on_keydown != unsafe { nil } {
		names << 'keydown'
	}
	if eh.on_mouse_move != unsafe { nil } {
		names << 'mouse_move'
	}
	if eh.on_mouse_up != unsafe { nil } {
		names << 'mouse_up'
	}
	if eh.on_mouse_scroll != unsafe { nil } {
		names << 'scroll'
	}
	if eh.on_hover != unsafe { nil } {
		names << 'hover'
	}
	if eh.on_ime_commit != unsafe { nil } {
		names << 'ime'
	}
	if eh.amend_layout != unsafe { nil } {
		names << 'amend'
	}
	return names.join(', ')
}

// inspector_color_str formats a Color as hex string.
fn inspector_color_str(c Color) string {
	if c.a == 255 {
		return '#${c.r:02x}${c.g:02x}${c.b:02x}'
	}
	return '#${c.r:02x}${c.g:02x}${c.b:02x}${c.a:02x}'
}

// inspector_apply_scroll_to scrolls the inspector panel to
// reveal the pending scroll target, then clears it.
fn inspector_apply_scroll_to(panel_h f32, mut w Window) {
	mut sm := state_map[string, string](mut w, ns_inspector, cap_inspector)
	target := sm.get('scroll_to') or { return }
	if target.len == 0 {
		return
	}
	sm.set('scroll_to', '')
	tree_map := w.view_state.tree_state.get(inspector_tree_id) or { return }
	row_idx := inspector_flat_row_index(w.inspector_tree_cache, tree_map, target)
	if row_idx < 0 {
		return
	}
	row_h := tree_font_height(gui_theme.tree_style.text_style, mut w) + 1
	target_y := f32(row_idx) * row_h
	mut new_scroll := -(target_y - row_h * 2)
	if new_scroll > 0 {
		new_scroll = 0
	}
	mut sy := state_map[u32, f32](mut w, ns_scroll_y, cap_scroll)
	sy.set(inspector_id_scroll_panel, new_scroll)
}

// inspector_flat_row_index returns the flat row index of
// target in the visible tree. Returns -1 if not found.
// Walks depth-first, counting visible rows until target
// is found, avoiding array allocation.
fn inspector_flat_row_index(nodes []TreeNodeCfg, tree_map map[string]bool, target string) int {
	mut stack := []InspectorStackFrame{cap: 16}
	stack << InspectorStackFrame{
		nodes: nodes
	}
	mut idx := 0
	for stack.len > 0 {
		si := stack.len - 1
		if stack[si].pos >= stack[si].nodes.len {
			stack.delete_last()
			continue
		}
		node := stack[si].nodes[stack[si].pos]
		stack[si].pos++
		id := if node.id.len == 0 { node.text } else { node.id }
		if id == target {
			return idx
		}
		idx++
		if tree_map[id] && node.nodes.len > 0 {
			stack << InspectorStackFrame{
				nodes: node.nodes
			}
		}
	}
	return -1
}
