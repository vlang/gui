module gui

// This file is intended to be active only during debug builds of the application.
// Its primary purpose is to serve as a comprehensive monitoring tool for tracking
// and analyzing the program's resource usage and internal state in real-time.
//
// The functionality provided within this file allows developers to:
// - Monitor the instantiation and rendering of various UI components, such as
//   containers, text elements, images, and rich text fields, providing insight
//   into the complexity and overhead of the current view hierarchy.
// - Track memory allocation and garbage collection statistics, including heap
//   usage, free memory, and total bytes allocated, which is crucial for identifying
//   memory leaks and optimizing performance.
// - Inspect the memory footprint of core data structures used within the GUI
//   framework, helping to ensure that memory is being used efficiently.
// - Visualize the internal state of the window and view system, including input
//   states, scroll offsets, and other dynamic properties that affect the user
//   experience.
//
import gg

const stat_top_div = '=================================='
const stat_sub_div = '----------------------------------'

struct Stats {
mut:
	container_views  usize
	text_views       usize
	image_views      usize
	rtf_views        usize
	layouts          usize
	max_renderers    usize
	layouts_rendered usize
	layouts_skipped  usize
	layouts_total    usize
}

fn (mut stats Stats) increment_container_views() {
	stats.container_views += 1
}

fn (mut stats Stats) increment_text_views() {
	stats.text_views += 1
}

fn (mut stats Stats) increment_image_views() {
	stats.image_views += 1
}

fn (mut stats Stats) increment_rtf_views() {
	stats.rtf_views += 1
}

fn (mut stats Stats) update_max_renderers(count usize) {
	if count > stats.max_renderers {
		stats.max_renderers = count
	}
}

fn (mut stats Stats) increment_layouts() {
	stats.layouts += 1
}

fn (window &Window) stats() string {
	mut tx := []string{}
	tx << ''
	tx << 'Statistics'
	tx << stat_top_div
	tx << window.view_state.view_state_stats()
	tx << struct_sizes()
	tx << window.view_stats()
	tx << window.context_stats()
	tx << memory_stats()
	tx << window.layout_stats()
	return tx.join('\n')
}

fn (window &Window) view_stats() string {
	mut tx := []string{}
	tx << ''
	tx << 'Views Generated'
	tx << stat_sub_div
	tx << 'container views ${cm(gui_stats.container_views):17}'
	tx << 'text views      ${cm(gui_stats.text_views):17}'
	tx << 'image views     ${cm(gui_stats.image_views):17}'
	tx << 'rtf views       ${cm(gui_stats.rtf_views):17}'
	tx << 'layouts         ${cm(gui_stats.layouts):17}'
	tx << 'max renderers   ${cm(gui_stats.max_renderers):17}'
	return tx.join('\n')
}

fn memory_stats() string {
	gc := gc_heap_usage()

	mut tx := []string{}
	tx << ''
	tx << 'Memory'
	tx << stat_sub_div
	tx << 'heap size             ${cmmb(gc.heap_size):8} MB'
	tx << 'free bytes            ${cmmb(gc.free_bytes):8} MB'
	tx << 'unmapped bytes        ${cmmb(gc.unmapped_bytes):8} MB'
	tx << 'bytes since gc        ${cmmb(gc.bytes_since_gc):8} MB'
	tx << 'memory use            ${cmmb(gc_memory_use()):8} MB'
	tx << 'total bytes           ${cmmb(gc.total_bytes):8} MB'
	return tx.join('\n')
}

fn struct_sizes() string {
	mut tx := []string{}
	tx << ''
	tx << 'Various Struct Sizes'
	tx << stat_sub_div
	tx << 'Layout                   ${sizeof(Layout):8}'
	tx << 'Shape                    ${sizeof(Shape):8}'
	tx << 'ContainerView            ${sizeof(ContainerView):8}'
	tx << 'ContainerCfg             ${sizeof(ContainerCfg):8}'
	tx << 'TextView                 ${sizeof(TextView):8}'
	tx << 'TextCfg                  ${sizeof(TextCfg):8}'
	tx << 'TextStyle                ${sizeof(TextStyle):8}'
	tx << '[]View                   ${sizeof([]View):8}'
	return tx.join('\n')
}

fn (vs ViewState) view_state_stats() string {
	mut tx := []string{}
	tx << ''
	tx << 'View State'
	tx << stat_sub_div
	tx << 'input_state length       ${cm(usize(vs.input_state.len)):8}'
	tx << 'scroll_x length          ${cm(usize(vs.scroll_x.len)):8}'
	tx << 'scroll_y length          ${cm(usize(vs.scroll_y.len)):8}'
	tx << 'menu_state length        ${cm(usize(vs.menu_state.len)):8}'
	tx << 'image_map length         ${cm(usize(vs.image_map.len)):8}'
	tx << 'select_state length      ${cm(usize(vs.select_state.len)):8}'
	tx << 'tree_state length        ${cm(usize(vs.tree_state.len)):8}'
	tx << 'date_picker_state length ${cm(usize(vs.date_picker_state.len)):8}'
	return tx.join('\n')
}

fn (window &Window) layout_stats() string {
	mut tx := []string{}
	tx << ''
	tx << 'Layout Stats'
	tx << stat_sub_div
	tx << 'total time us           ${cm(usize(window.layout_stats.total_time_us)):8}'
	tx << 'node count              ${cm(usize(window.layout_stats.node_count)):8}'
	tx << 'floating count          ${cm(usize(window.layout_stats.floating_count)):8}'
	tx << ''
	tx << 'Arena Stats'
	tx << stat_sub_div
	tx << 'max shapes allocated    ${cm(usize(window.layout_arena.max_index)):8}'
	tx << 'arena capacity          ${cm(usize(window.layout_arena.shapes.len)):8}'
	tx << 'reset count             ${cm(usize(window.layout_arena.reset_count)):8}'
	return tx.join('\n')
}

fn (window &Window) context_stats() string {
	ww, wh := window.window_size()
	win_size := '${ww} x ${wh}'

	screen_size := gg.screen_size()
	scr_size := '${screen_size.width} x ${screen_size.height}'

	mut tx := []string{}
	tx << ''
	tx << 'gg Context'
	tx << stat_sub_div
	tx << 'frames drawn ${cm(usize(window.context().frame)):20}'
	tx << 'window size  ${win_size:20}'
	tx << 'screen size  ${scr_size:20}'
	tx << 'high dpi     ${gg.high_dpi():20}'
	return tx.join('\n')
}

fn cm(num usize) string {
	if num < 1000 {
		return num.str()
	}
	return cm(num / 1000) + ',${(num % 1000):03u}'
}

fn cmkb(num usize) string {
	return cm(num / 1024)
}

fn cmmb(num usize) string {
	return cm(num / (1024 * 1024))
}
