module gui

// a11y_tree.v — Builds a flat array of accessibility nodes
// from the layout tree and syncs to the native backend.
import nativebridge
import sokol.sapp
import log

// A11y holds per-window accessibility backend state.
struct A11y {
mut:
	initialized      bool
	prev_id_focus    u32               // track focus changes between syncs
	prev_live_values map[string]string // label→value_text for live nodes
}

// init_a11y lazily creates the native accessibility container.
// Called from frame_fn, same pattern as init_ime.
fn (mut w Window) init_a11y() {
	if w.a11y.initialized {
		return
	}
	w.a11y.initialized = true

	$if macos {
		ns_window := sapp.macos_get_window()
		if ns_window == unsafe { nil } {
			return
		}
		nativebridge.a11y_init(ns_window, voidptr(&a11y_action_callback), w)
	}
}

// sync_a11y walks the layout tree, builds a flat node array,
// and pushes it to the native accessibility backend.
fn (mut w Window) sync_a11y() {
	$if !macos {
		return
	}
	if !w.a11y.initialized {
		return
	}
	if w.layout.shape == unsafe { nil } {
		return
	}

	mut nodes := []C.GuiA11yNode{cap: 64}
	focused_idx := a11y_collect(&w.layout, -1, mut nodes, w.view_state.id_focus)

	if nodes.len == 0 {
		return
	}

	nativebridge.a11y_sync(unsafe { &nodes[0] }, nodes.len, focused_idx)
	w.a11y.prev_id_focus = w.view_state.id_focus

	// Live region change detection: announce value changes
	mut new_live := map[string]string{}
	for n in nodes {
		if n.state & int(AccessState.live) != 0 {
			label := if n.label != unsafe { nil } {
				unsafe { cstring_to_vstring(n.label) }
			} else {
				''
			}
			if label.len == 0 {
				continue
			}
			val := if n.value_text != unsafe { nil } {
				unsafe { cstring_to_vstring(n.value_text) }
			} else {
				''
			}
			new_live[label] = val
			if prev := w.a11y.prev_live_values[label] {
				if prev != val && val.len > 0 {
					nativebridge.a11y_announce(val)
				}
			}
		}
	}
	w.a11y.prev_live_values = new_live.move()
}

// a11y_collect recursively walks the layout tree, appending
// a GuiA11yNode for each shape with a11y_role != .none.
// Shapes with .none role are transparent — children inherit
// parent_idx. Returns the index of the focused element (-1
// if none found).
fn a11y_collect(layout &Layout, parent_idx int, mut nodes []C.GuiA11yNode, id_focus u32) int {
	if layout.shape == unsafe { nil } {
		return -1
	}

	mut focused_idx := -1
	shape := layout.shape

	// Determine whether this shape emits an a11y node
	if shape.a11y_role != .none {
		idx := nodes.len

		label_ptr := a11y_cstr(if shape.has_a11y() { shape.a11y.label } else { '' })
		desc_ptr := a11y_cstr(if shape.has_a11y() { shape.a11y.description } else { '' })
		val_ptr := a11y_cstr(if shape.has_a11y() { shape.a11y.value_text } else { '' })

		nodes << C.GuiA11yNode{
			parent_idx:    parent_idx
			role:          int(shape.a11y_role)
			state:         int(shape.a11y_state)
			x:             shape.x
			y:             shape.y
			w:             shape.width
			h:             shape.height
			label:         label_ptr
			description:   desc_ptr
			value_text:    val_ptr
			value_num:     if shape.has_a11y() { shape.a11y.value_num } else { f32(0) }
			value_min:     if shape.has_a11y() { shape.a11y.value_min } else { f32(0) }
			value_max:     if shape.has_a11y() { shape.a11y.value_max } else { f32(0) }
			focus_id:      int(shape.id_focus)
			heading_level: if shape.has_a11y() { int(shape.a11y.heading_level) } else { 0 }
		}

		if id_focus > 0 && shape.id_focus == id_focus {
			focused_idx = idx
		}

		// Recurse children with this node as parent
		for child in layout.children {
			fi := a11y_collect(&child, idx, mut nodes, id_focus)
			if fi >= 0 {
				focused_idx = fi
			}
		}
	} else {
		// Skip this shape but walk children with inherited parent
		for child in layout.children {
			fi := a11y_collect(&child, parent_idx, mut nodes, id_focus)
			if fi >= 0 {
				focused_idx = fi
			}
		}
	}

	return focused_idx
}

// a11y_cstr returns a &char pointer for the C bridge.
// Empty strings produce a null pointer.
@[inline]
fn a11y_cstr(s string) &char {
	if s.len == 0 {
		return unsafe { nil }
	}
	return s.str
}

// a11y_action_callback is invoked by the native backend
// when VoiceOver triggers an action (press, increment, etc).
fn a11y_action_callback(action int, focus_id int, user_data voidptr) {
	if user_data == unsafe { nil } || focus_id <= 0 {
		return
	}
	mut w := unsafe { &Window(user_data) }

	ly := find_layout_by_id_focus(&w.layout, u32(focus_id)) or {
		log.debug('a11y: no layout for focus_id ${focus_id}')
		return
	}

	if !ly.shape.has_events() {
		return
	}

	match action {
		0 {
			// Press → on_click
			if ly.shape.events.on_click != unsafe { nil } {
				mut e := Event{
					typ: .mouse_down
				}
				ly.shape.events.on_click(&ly, mut e, mut w)
			}
		}
		1 {
			// Increment → on_mouse_scroll (positive)
			if ly.shape.events.on_mouse_scroll != unsafe { nil } {
				mut e := Event{
					typ:      .mouse_scroll
					scroll_y: 1.0
				}
				ly.shape.events.on_mouse_scroll(&ly, mut e, mut w)
			}
		}
		2 {
			// Decrement → on_mouse_scroll (negative)
			if ly.shape.events.on_mouse_scroll != unsafe { nil } {
				mut e := Event{
					typ:      .mouse_scroll
					scroll_y: -1.0
				}
				ly.shape.events.on_mouse_scroll(&ly, mut e, mut w)
			}
		}
		3 {
			// Confirm → on_keydown with enter
			if ly.shape.events.on_keydown != unsafe { nil } {
				mut e := Event{
					typ:      .key_down
					key_code: .enter
				}
				ly.shape.events.on_keydown(&ly, mut e, mut w)
			}
		}
		4 {
			// Cancel → on_keydown with escape
			if ly.shape.events.on_keydown != unsafe { nil } {
				mut e := Event{
					typ:      .key_down
					key_code: .escape
				}
				ly.shape.events.on_keydown(&ly, mut e, mut w)
			}
		}
		else {}
	}
}
