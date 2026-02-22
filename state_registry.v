module gui

import log

// StateRegistry stores per-widget BoundedMap instances keyed by
// namespace string. Replaces dedicated BoundedMap fields on
// ViewState — shrinks the struct and lets third-party modules
// persist typed state across frames via state_map().
//
// orders stores a voidptr to each BoundedMap's `order` array
// header so clear() can zero backing memory without knowing the
// generic types (Boehm GC false-retention prevention).
struct StateRegistry {
mut:
	maps   map[string]voidptr
	meta   map[string]StateMapMeta
	orders map[string]voidptr
}

// StateMapMeta stores per-namespace metadata for type-erased
// BoundedMap instances.
struct StateMapMeta {
	type_tag string
	max_size int
}

fn state_map_type_tag[K, V]() string {
	return typeof[K]().name + ':' + typeof[V]().name
}

fn state_map_type_check[K, V](registry &StateRegistry, ns string) ! {
	if m := registry.meta[ns] {
		tag := state_map_type_tag[K, V]()
		if m.type_tag != tag {
			return error('state_map type mismatch: ${ns} expected ${m.type_tag} got ${tag}')
		}
	}
}

// state_map returns (or lazily creates) a &BoundedMap[K, V] for
// the given namespace. Cache the returned pointer in a local to
// avoid repeated map lookups in hot paths.
//
// Third-party usage:
//   mut sm := gui.state_map[string, MyState](mut w, 'mylib.wgt', 20)
//   st := sm.get(id) or { MyState{} }
//   sm.set(id, new_st)
pub fn state_map[K, V](mut w Window, ns string, max_size int) &BoundedMap[K, V] {
	state_map_type_check[K, V](&w.view_state.registry, ns) or { panic(err.msg()) }
	if ptr := w.view_state.registry.maps[ns] {
		if m := w.view_state.registry.meta[ns] {
			if m.max_size != max_size {
				log.warn('state_map max_size mismatch: ${ns} registered ${m.max_size}, requested ${max_size}')
			}
		}
		return unsafe { &BoundedMap[K, V](ptr) }
	}
	m := &BoundedMap[K, V]{
		max_size: max_size
	}
	w.view_state.registry.maps[ns] = voidptr(m)
	w.view_state.registry.orders[ns] = voidptr(&m.order)
	w.view_state.registry.meta[ns] = StateMapMeta{
		type_tag: state_map_type_tag[K, V]()
		max_size: max_size
	}
	return m
}

// state_map_read returns a &BoundedMap[K, V] for the given namespace
// without requiring mut Window. Returns none if the namespace has not
// been initialised yet. Use for read-only access from &Window methods.
fn state_map_read[K, V](w &Window, ns string) ?&BoundedMap[K, V] {
	state_map_type_check[K, V](&w.view_state.registry, ns) or { panic(err.msg()) }
	if ptr := w.view_state.registry.maps[ns] {
		return unsafe { &BoundedMap[K, V](ptr) }
	}
	return none
}

// state_read_or returns the value for key in namespace ns, or
// default if the namespace or key does not exist. Read-only;
// does not require mut Window.
fn state_read_or[K, V](w &Window, ns string, key K, default V) V {
	sm := state_map_read[K, V](w, ns) or { return default }
	return sm.get(key) or { default }
}

// clear zeros each BoundedMap's order-array backing memory to
// prevent Boehm GC false retention of stale key pointers, then
// drops the registry references.
fn (mut r StateRegistry) clear() {
	for _, order_ptr in r.orders {
		if order_ptr != unsafe { nil } {
			unsafe {
				mut a := &array(order_ptr)
				vmemset(a.data, 0, a.cap * a.element_size)
				a.len = 0
			}
		}
	}
	r.maps.clear()
	r.meta.clear()
	r.orders.clear()
}

// registry_entry_count returns the number of entries stored in
// the BoundedMap for the given namespace, or 0 if not found.
// Non-generic: reads the order array length directly.
fn (r &StateRegistry) entry_count(ns string) int {
	if order_ptr := r.orders[ns] {
		if order_ptr != unsafe { nil } {
			return unsafe { (&array(order_ptr)).len }
		}
	}
	return 0
}

// BoundedMap capacity tiers - max entries before LRU eviction.
const cap_few = 20 // menus, pickers, splitters
const cap_moderate = 50 // general widgets
const cap_many = 100 // inputs, focus tracking
const cap_scroll = 200 // scroll containers
const cap_tree_focus = 30 // keep tree focus cache bounded

// Namespace constants for internal gui state maps.
const ns_overflow = 'gui.overflow'
const ns_progress = 'gui.progress'
const ns_splitter_runtime = 'gui.splitter.runtime'
const ns_color_picker = 'gui.color_picker'
const ns_select = 'gui.select'
const ns_select_highlight = 'gui.select.highlight'
const ns_menu = 'gui.menu'
const ns_input = 'gui.input'
const ns_input_focus = 'gui.input.focus'
const ns_input_date = 'gui.input_date'
const ns_scroll_x = 'gui.scroll.x'
const ns_scroll_y = 'gui.scroll.y'
const ns_form = 'gui.form'
const ns_list_box_focus = 'gui.list_box.focus'
const ns_list_box_source = 'gui.list_box.source'
const ns_tree_focus = 'gui.tree.focus'
const ns_tree_lazy = 'gui.tree.lazy'
const cap_tree_lazy = 30
const ns_date_picker = 'gui.date_picker'
const ns_table_col_widths = 'gui.table.col_widths'
const ns_table_warned_no_id = 'gui.table.warned_no_id'
const ns_svg_anim_start = 'gui.svg.anim_start'
const ns_svg_anim_seen = 'gui.svg.anim_seen'
const ns_active_downloads = 'gui.active_downloads'
const ns_dg_col_widths = 'gui.dg.col_widths'
const ns_dg_presentation = 'gui.dg.presentation'
const ns_dg_resize = 'gui.dg.resize'
const ns_dg_header_hover = 'gui.dg.header_hover'
const ns_dg_range = 'gui.dg.range'
const ns_dg_chooser_open = 'gui.dg.chooser_open'
const ns_dg_edit = 'gui.dg.edit'
const ns_dg_crud = 'gui.dg.crud'
const ns_dg_jump = 'gui.dg.jump'
const ns_dg_pending_jump = 'gui.dg.pending_jump'
const ns_dg_source = 'gui.dg.source'
