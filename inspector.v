module gui

// inspector.v — Runtime inspector overlay for layout debugging.
// Injected as floating layout in layout_arrange (same as dialogs).
// Gated by $if !prod; zero overhead in production builds.
// F12 toggles. Shows layout tree, property panel, wireframe.

const ns_inspector = 'gui.inspector'
const ns_inspector_width = 'gui.inspector.w'
const cap_inspector = 5
const inspector_id_focus = u32(0xFFF00000)
const inspector_id_scroll_panel = u32(0xFFF00001)
const inspector_tree_id = '__inspector_tree__'
const inspector_panel_min_width = f32(300)
const inspector_resize_step = f32(50)
const inspector_margin = f32(10)

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

	mut content := []View{cap: 2}
	// Header
	content << row(
		sizing:  fill_fixed
		color:   rgba(30, 30, 30, 240)
		padding: pad_tblr(4, 8)
		content: [
			text(
				text:       'Inspector'
				text_style: TextStyle{
					size:     14
					color:    white
					typeface: .bold
				}
			),
		]
	)
	// Tree with inline properties as child nodes
	content << inspector_tree_view(mut w)

	return column(
		float:          true
		float_anchor:   .top_right
		float_tie_off:  .top_right
		float_offset_x: -inspector_margin
		float_offset_y: inspector_margin
		width:          panel_w
		height:         panel_h
		sizing:         fixed_fixed
		color:          rgba(20, 20, 20, 230)
		radius:         8
		clip:           true
		id_scroll:      inspector_id_scroll_panel
		scroll_mode:    .vertical_only
		padding:        padding_none
		spacing:        0
		on_click:       fn (_ &Layout, mut e Event, mut _ Window) {
			e.is_handled = true
		}
		content:        content
	)
}

// inspector_tree_view builds the tree widget from cached
// previous-frame tree nodes. No fixed height or virtualization;
// tree grows to content, panel scroll handles overflow.
fn inspector_tree_view(mut w Window) View {
	nodes := w.inspector_tree_cache
	ns := ns_inspector
	cap := cap_inspector
	return w.tree(TreeCfg{
		id:        inspector_tree_id
		id_focus:  inspector_id_focus
		indent:    16
		spacing:   1
		nodes:     nodes
		on_select: fn [ns, cap] (id string, mut w Window) {
			mut sm := state_map[string, string](mut w, ns, cap)
			old := sm.get('selected') or { '' }
			// Toggle: deselect if already selected
			if old == id {
				sm.set('selected', '')
			} else {
				sm.set('selected', id)
				// Expand the node so property children show
				tree_id := inspector_tree_id
				mut tree_map := w.view_state.tree_state.get(tree_id) or {
					map[string]bool{}
				}
				tree_map[id] = true
				w.view_state.tree_state.set(tree_id, tree_map)
			}
			w.update_window()
		}
	})
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
fn inspector_layout_to_tree(layout Layout, path string, selected string, mut props map[string]InspectorNodeProps) []TreeNodeCfg {
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
	return [TreeNodeCfg{
		id:    path
		text:  label
		nodes: child_nodes
	}]
}

// inspector_props_nodes builds leaf TreeNodeCfg entries
// for each non-default property value.
fn inspector_props_nodes(p InspectorNodeProps) []TreeNodeCfg {
	prop_style := TextStyle{
		size:  11
		color: rgba(140, 180, 220, 255)
	}
	mut nodes := []TreeNodeCfg{cap: 16}
	if p.text_preview.len > 0 {
		nodes << TreeNodeCfg{
			id:         '__prop_text'
			text:       'text: "${p.text_preview}"'
			text_style: prop_style
		}
	}
	if p.id.len > 0 {
		nodes << TreeNodeCfg{
			id:         '__prop_id'
			text:       'id: ${p.id}'
			text_style: prop_style
		}
	}
	nodes << TreeNodeCfg{
		id:         '__prop_pos'
		text:       'pos: ${int(p.x)}, ${int(p.y)}'
		text_style: prop_style
	}
	nodes << TreeNodeCfg{
		id:         '__prop_size'
		text:       'size: ${int(p.width)} x ${int(p.height)}'
		text_style: prop_style
	}
	if p.sizing.width != .fit || p.sizing.height != .fit {
		nodes << TreeNodeCfg{
			id:         '__prop_sizing'
			text:       'sizing: ${p.sizing.width}, ${p.sizing.height}'
			text_style: prop_style
		}
	}
	if !p.padding.is_none() {
		nodes << TreeNodeCfg{
			id:         '__prop_pad'
			text:       'pad: ${int(p.padding.top)} ${int(p.padding.right)} ${int(p.padding.bottom)} ${int(p.padding.left)}'
			text_style: prop_style
		}
	}
	if p.spacing > 0 {
		nodes << TreeNodeCfg{
			id:         '__prop_spacing'
			text:       'spacing: ${int(p.spacing)}'
			text_style: prop_style
		}
	}
	if p.color.a > 0 {
		nodes << TreeNodeCfg{
			id:         '__prop_color'
			text:       'color: ${inspector_color_str(p.color)}'
			text_style: prop_style
		}
	}
	if p.radius > 0 {
		nodes << TreeNodeCfg{
			id:         '__prop_radius'
			text:       'radius: ${int(p.radius)}'
			text_style: prop_style
		}
	}
	if p.id_focus > 0 {
		nodes << TreeNodeCfg{
			id:         '__prop_focus'
			text:       'id_focus: ${p.id_focus}'
			text_style: prop_style
		}
	}
	if p.id_scroll > 0 {
		nodes << TreeNodeCfg{
			id:         '__prop_scroll'
			text:       'id_scroll: ${p.id_scroll}'
			text_style: prop_style
		}
	}
	if p.is_float {
		nodes << TreeNodeCfg{
			id:         '__prop_float'
			text:       'float: true'
			text_style: prop_style
		}
	}
	if p.clip {
		nodes << TreeNodeCfg{
			id:         '__prop_clip'
			text:       'clip: true'
			text_style: prop_style
		}
	}
	if p.opacity < 1.0 {
		nodes << TreeNodeCfg{
			id:         '__prop_opacity'
			text:       'opacity: ${p.opacity:.2f}'
			text_style: prop_style
		}
	}
	if p.events.len > 0 {
		nodes << TreeNodeCfg{
			id:         '__prop_events'
			text:       'events: ${p.events}'
			text_style: prop_style
		}
	}
	if p.children > 0 {
		nodes << TreeNodeCfg{
			id:         '__prop_children'
			text:       'children: ${p.children}'
			text_style: prop_style
		}
	}
	return nodes
}

// inspector_snapshot_props captures shape properties as
// plain values for the properties panel.
fn inspector_snapshot_props(layout Layout) InspectorNodeProps {
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
			w:         shape.width - shape.padding.left - shape.padding.right
			h:         shape.height - shape.padding.top - shape.padding.bottom
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
