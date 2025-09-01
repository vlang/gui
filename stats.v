module gui

import gg

const stat_top_div = '=================================='
const stat_sub_div = '----------------------------------'

fn (window &Window) stats() string {
	mut tx := []string{}
	tx << ''
	tx << 'Statistics'
	tx << stat_top_div
	tx << window.view_state.stats()
	tx << struct_sizes()
	tx << window.context_stats()
	tx << memory_stats()
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
	tx << 'Shape                    ${sizeof(Shape):8}'
	tx << 'ContainerView            ${sizeof(ContainerView):8}'
	tx << 'ContainerCfg             ${sizeof(ContainerCfg):8}'
	tx << 'TextCfg                  ${sizeof(TextCfg):8}'
	tx << 'TextStyle                ${sizeof(TextStyle):8}'
	tx << 'TextView                 ${sizeof(TextView):8}'
	tx << '[]View                   ${sizeof([]View):8}'
	return tx.join('\n')
}

fn (vs ViewState) stats() string {
	mut tx := []string{}
	tx << ''
	tx << 'View State'
	tx << stat_sub_div
	tx << 'input_state length       ${cm(usize(vs.input_state.len)):8}'
	tx << 'offset_x_state length    ${cm(usize(vs.offset_x_state.len)):8}'
	tx << 'offset_y_state length    ${cm(usize(vs.offset_y_state.len)):8}'
	tx << 'text_widths length       ${cm(usize(vs.text_widths.len)):8}'
	tx << 'menu_state  length       ${cm(usize(vs.menu_state.len)):8}'
	tx << 'image_map  length        ${cm(usize(vs.image_map.len)):8}'
	tx << 'select_state length      ${cm(usize(vs.select_state.len)):8}'
	tx << 'tree_state length        ${cm(usize(vs.tree_state.len)):8}'
	tx << 'date_picker_state length ${cm(usize(vs.date_picker_state.len)):8}'
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
