module gui

// a11y_tree.v — Builds a flat array of accessibility nodes
// from the layout tree and syncs to the native backend.
import nativebridge
import sokol.sapp
import log

// Action constants matching GUI_A11Y_ACTION_* in a11y_bridge.h.
const a11y_action_press = 0
const a11y_action_increment = 1
const a11y_action_decrement = 2
const a11y_action_confirm = 3
const a11y_action_cancel = 4

// A11y holds per-window accessibility backend state.
struct A11y {
mut:
	initialized      bool
	prev_id_focus    u32               // track focus changes between syncs
	prev_live_values map[string]string // label→value_text for live nodes
	nodes            []C.GuiA11yNode   // reused across frames
	live_nodes       []LiveNode        // reused across frames
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

	// Reuse nodes array across frames. gc_clear zeros backing
	// memory to prevent GC false retention from stale pointers.
	if w.a11y.nodes.cap == 0 {
		w.a11y.nodes = []C.GuiA11yNode{cap: 64}
	} else {
		gc_clear(mut w.a11y.nodes)
	}
	if w.a11y.live_nodes.cap == 0 {
		w.a11y.live_nodes = []LiveNode{cap: 8}
	} else {
		gc_clear(mut w.a11y.live_nodes)
	}

	focused_idx := a11y_collect(&w.layout, -1, mut w.a11y.nodes, w.view_state.id_focus, mut
		w.a11y.live_nodes)

	if w.a11y.nodes.len == 0 {
		return
	}

	nativebridge.a11y_sync(unsafe { &w.a11y.nodes[0] }, w.a11y.nodes.len, focused_idx)
	w.a11y.prev_id_focus = w.view_state.id_focus

	// Live region change detection: announce value changes.
	// Uses LiveNode V strings collected during a11y_collect
	// — no cstring_to_vstring round-trip needed.
	if w.a11y.live_nodes.len > 0 {
		mut new_live := map[string]string{}
		for ln in w.a11y.live_nodes {
			if ln.label.len == 0 {
				continue
			}
			new_live[ln.label] = ln.value_text
			if prev := w.a11y.prev_live_values[ln.label] {
				if prev != ln.value_text && ln.value_text.len > 0 {
					nativebridge.a11y_announce(ln.value_text)
				}
			}
		}
		w.a11y.prev_live_values = new_live.move()
	} else if w.a11y.prev_live_values.len > 0 {
		w.a11y.prev_live_values = map[string]string{}
	}
}

// a11y_collect recursively walks the layout tree, appending
// a GuiA11yNode for each shape with a11y_role != .none.
// Shapes with .none role are transparent — children inherit
// parent_idx. Returns the index of the focused element (-1
// if none found).
fn a11y_collect(layout &Layout, parent_idx int, mut nodes []C.GuiA11yNode, id_focus u32, mut live_nodes []LiveNode) int {
	if layout.shape == unsafe { nil } {
		return -1
	}

	mut focused_idx := -1
	shape := layout.shape

	// Determine parent index for children: this node's
	// index if it emits an a11y node, else inherited.
	mut my_idx := parent_idx

	if shape.a11y_role != .none {
		my_idx = nodes.len

		label_str := if shape.has_a11y() { shape.a11y.label } else { '' }
		desc_str := if shape.has_a11y() { shape.a11y.description } else { '' }
		val_str := if shape.has_a11y() { shape.a11y.value_text } else { '' }

		nodes << C.GuiA11yNode{
			parent_idx:    parent_idx
			role:          int(shape.a11y_role)
			state:         int(shape.a11y_state)
			x:             shape.x
			y:             shape.y
			w:             shape.width
			h:             shape.height
			label:         a11y_cstr(label_str)
			description:   a11y_cstr(desc_str)
			value_text:    a11y_cstr(val_str)
			value_num:     if shape.has_a11y() { shape.a11y.value_num } else { f32(0) }
			value_min:     if shape.has_a11y() { shape.a11y.value_min } else { f32(0) }
			value_max:     if shape.has_a11y() { shape.a11y.value_max } else { f32(0) }
			focus_id:      int(shape.id_focus)
			heading_level: if shape.has_a11y() { int(shape.a11y.heading_level) } else { 0 }
		}

		if id_focus > 0 && shape.id_focus == id_focus {
			focused_idx = my_idx
		}

		// Collect live node V strings for change detection
		// — avoids cstring_to_vstring in sync_a11y.
		if shape.a11y_state.has(.live) {
			live_nodes << LiveNode{
				label:      label_str
				value_text: val_str
			}
		}
	}

	for child in layout.children {
		fi := a11y_collect(&child, my_idx, mut nodes, id_focus, mut live_nodes)
		if fi >= 0 {
			focused_idx = fi
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
		a11y_action_press {
			if ly.shape.events.on_click != unsafe { nil } {
				mut e := Event{
					typ: .mouse_down
				}
				ly.shape.events.on_click(&ly, mut e, mut w)
			}
		}
		a11y_action_increment {
			if ly.shape.events.on_mouse_scroll != unsafe { nil } {
				mut e := Event{
					typ:      .mouse_scroll
					scroll_y: 1.0
				}
				ly.shape.events.on_mouse_scroll(&ly, mut e, mut w)
			}
		}
		a11y_action_decrement {
			if ly.shape.events.on_mouse_scroll != unsafe { nil } {
				mut e := Event{
					typ:      .mouse_scroll
					scroll_y: -1.0
				}
				ly.shape.events.on_mouse_scroll(&ly, mut e, mut w)
			}
		}
		a11y_action_confirm {
			if ly.shape.events.on_keydown != unsafe { nil } {
				mut e := Event{
					typ:      .key_down
					key_code: .enter
				}
				ly.shape.events.on_keydown(&ly, mut e, mut w)
			}
		}
		a11y_action_cancel {
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

// a11y_cleanup releases the native accessibility container.
// Used as gg cleanup_fn in window.v.
fn a11y_cleanup(_ voidptr) {
	nativebridge.a11y_destroy()
}
