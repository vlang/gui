import gg
import gui
import math
import os
import time
import vglyph

// Showcase
// =============================
// Oh majeuere, dim the lights...

const id_scroll_gallery = 1
const id_scroll_list_box = 2
const id_scroll_catalog = 3
const id_scroll_sync_demo = 4
const id_scroll_tree = 5
const id_scroll_drag_reorder_tree = 6
const id_focus_showcase_splitter_main = u32(9160)
const id_focus_showcase_splitter_detail = u32(9161)
const showcase_form_id = 'showcase_forms'
const bc_full_path = [
	gui.BreadcrumbItemCfg{
		id:    'home'
		label: 'Home'
		icon:  gui.icon_home
	},
	gui.BreadcrumbItemCfg{
		id:    'docs'
		label: 'Docs'
		icon:  gui.icon_folder
	},
	gui.BreadcrumbItemCfg{
		id:    'guide'
		label: 'Guide'
	},
	gui.BreadcrumbItemCfg{
		id:    'page'
		label: 'Getting Started'
	},
]

@[heap]
struct ShowcaseApp {
pub mut:
	locale_index       int
	nav_query          string
	selected_group     string = 'all'
	selected_component string = 'welcome'
	// buttons
	button_clicks int
	// inputs
	input_text      string
	input_password  string
	input_phone     string
	input_expiry    string
	input_multiline string = 'Now is the time for all good men to come to the aid of their country'
	// toggles
	select_toggle   bool
	select_checkbox bool
	select_city     string = 'ny'
	select_switch   bool
	// menu
	selected_menu_id string
	search_text      string
	// printing
	printing_last_path string
	printing_status    string
	// range sliders
	range_value f32 = 50
	// numeric input
	numeric_en_text        string = '1,234.50'
	numeric_en_value       ?f64   = 1234.5
	numeric_de_text        string = '1.234,50'
	numeric_de_value       ?f64   = 1234.5
	numeric_currency_text  string = '$1,234.50'
	numeric_currency_value ?f64   = 1234.5
	numeric_percent_text   string = '12.50%'
	numeric_percent_value  ?f64   = 0.125
	numeric_plain_text     string
	numeric_plain_value    ?f64
	// forms
	form_username   string
	form_email      string
	form_age_text   string
	form_age_value  ?f64
	form_submit_msg string
	// select
	selected_1 []string
	selected_2 []string
	// tree view
	tree_id    string
	lazy_nodes map[string][]gui.TreeNodeCfg
	// list Box
	list_box_multiple_select bool
	list_box_selected_ids    []string
	// table
	table_sort_by      int
	table_border_style string = 'all'
	// data grid
	data_grid_query     gui.GridQueryState
	data_grid_selection gui.GridSelection = gui.GridSelection{
		selected_row_ids: map[string]bool{}
	}
	// data source
	data_source_query     gui.GridQueryState
	data_source_selection gui.GridSelection = gui.GridSelection{
		selected_row_ids: map[string]bool{}
	}
	data_source           ?gui.DataGridDataSource
	// radio
	select_radio bool
	// expand_pad
	open_expand_panel bool
	// Date Pickers
	date_picker_dates []time.Time
	input_date        time.Time = time.now()
	roller_date       time.Time = time.now()
	// breadcrumb
	bc_selected string                  = 'page'
	bc_path     []gui.BreadcrumbItemCfg = bc_full_path
	// tab control
	tab_selected string = 'overview'
	// splitter
	splitter_main_state   gui.SplitterState = gui.SplitterState{
		ratio: 0.30
	}
	splitter_detail_state gui.SplitterState = gui.SplitterState{
		ratio: 0.55
	}
	// color picker
	color_picker_color gui.Color = gui.Color{
		r: 255
		g: 85
		b: 0
		a: 255
	}
	color_picker_hsv   bool
	// theme generator
	theme_gen_seed        gui.Color = gui.theme_dark_bordered_cfg.color_select
	theme_gen_strategy    string    = 'mono'
	theme_gen_tint        f32
	theme_gen_radius      f32    = gui.theme_dark_bordered_cfg.radius
	theme_gen_radius_text string = '${gui.theme_dark_bordered_cfg.radius:.1}'
	theme_gen_border      f32    = gui.theme_dark_bordered_cfg.size_border
	theme_gen_border_text string = '${gui.theme_dark_bordered_cfg.size_border:.1}'
	theme_gen_pick_text   bool
	theme_gen_text        gui.Color = gui.theme_dark_bordered_cfg.text_style.color
	theme_gen_name        string
	// Animations
	anim_tween_x         f32
	anim_spring_x        f32
	anim_keyframe_x      f32
	anim_layout_expanded bool
	// wrap panel
	wrap_check_a  bool
	wrap_check_b  bool
	wrap_switch_a bool
	wrap_switch_b bool
	wrap_radio    int
	// sidebar
	sidebar_open bool = true
	// combobox
	combobox_selected string
	// command palette
	last_palette_action string
	// drag reorder
	drag_reorder_items    []gui.ListBoxOption = drag_reorder_demo_items()
	drag_reorder_selected []string
	drag_reorder_tabs     []gui.TabItemCfg  = drag_reorder_demo_tabs()
	drag_reorder_tab_sel  string            = 'alpha'
	drag_reorder_nodes    []gui.TreeNodeCfg = drag_reorder_demo_nodes()
	// docs panel
	show_docs bool
}

struct DemoEntry {
	id      string
	label   string
	group   string
	summary string
	tags    []string
}

fn main() {
	mut window := gui.window(
		title:        'Gui Showcase'
		state:        &ShowcaseApp{}
		width:        950
		height:       700
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
			ensure_showcase_embedded_image()
			for data in showcase_locale_data {
				gui.locale_register(gui.locale_parse(data.to_string()) or { continue })
			}
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	return gui.row(
		width:   w
		height:  h
		padding: gui.padding_none
		sizing:  gui.fixed_fixed
		spacing: 0
		content: [
			catalog_panel(mut window),
			detail_panel(mut window),
		]
	)
}

struct DemoGroup {
	key   string
	label string
}

fn demo_groups() []DemoGroup {
	return [
		DemoGroup{
			key:   'welcome'
			label: 'Welcome'
		},
		DemoGroup{
			key:   'input'
			label: 'Input'
		},
		DemoGroup{
			key:   'selection'
			label: 'Selection'
		},
		DemoGroup{
			key:   'data'
			label: 'Data Display'
		},
		DemoGroup{
			key:   'layout'
			label: 'Layout'
		},
		DemoGroup{
			key:   'navigation'
			label: 'Navigation'
		},
		DemoGroup{
			key:   'feedback'
			label: 'Feedback'
		},
		DemoGroup{
			key:   'overlays'
			label: 'Overlays'
		},
		DemoGroup{
			key:   'text'
			label: 'Text'
		},
		DemoGroup{
			key:   'graphics'
			label: 'Graphics'
		},
	]
}

fn demo_entries() []DemoEntry {
	return [
		DemoEntry{
			id:      'welcome'
			label:   'Welcome'
			group:   'welcome'
			summary: 'Start here for a quick introduction to v-gui and this showcase.'
			tags:    ['start', 'intro', 'overview']
		},
		DemoEntry{
			id:      'doc_get_started'
			label:   'Get Started'
			group:   'welcome'
			summary: 'Step-by-step guide to building your first v-gui application.'
			tags:    ['guide', 'tutorial', 'setup']
		},
		DemoEntry{
			id:      'doc_animations'
			label:   'Animations'
			group:   'welcome'
			summary: 'Guide to tween, spring, keyframe, and transition APIs.'
			tags:    ['doc', 'animation', 'tween', 'spring']
		},
		DemoEntry{
			id:      'doc_architecture'
			label:   'Architecture'
			group:   'welcome'
			summary: 'Internal architecture and design decisions of the framework.'
			tags:    ['doc', 'design', 'internals', 'structure']
		},
		DemoEntry{
			id:      'doc_containers'
			label:   'Containers'
			group:   'welcome'
			summary: 'Row, column, wrap, canvas, and circle container reference.'
			tags:    ['doc', 'container', 'row', 'column', 'wrap', 'layout']
		},
		DemoEntry{
			id:      'doc_custom_widgets'
			label:   'Custom Widgets'
			group:   'welcome'
			summary: 'Build third-party widgets via composition or View implementation.'
			tags:    ['doc', 'widget', 'custom', 'extend']
		},
		DemoEntry{
			id:      'doc_data_grid'
			label:   'Data Grid'
			group:   'welcome'
			summary: 'Data grid component documentation and usage patterns.'
			tags:    ['doc', 'grid', 'table', 'data']
		},
		DemoEntry{
			id:      'doc_forms'
			label:   'Forms'
			group:   'welcome'
			summary: 'Form validation model and field adapter documentation.'
			tags:    ['doc', 'forms', 'validation', 'async']
		},
		DemoEntry{
			id:      'doc_gradients'
			label:   'Gradients'
			group:   'welcome'
			summary: 'Guide to linear and radial gradient APIs.'
			tags:    ['doc', 'gradient', 'linear', 'radial']
		},
		DemoEntry{
			id:      'doc_layout_algorithm'
			label:   'Layout Algorithm'
			group:   'welcome'
			summary: 'How the layout engine measures and arranges views.'
			tags:    ['doc', 'layout', 'sizing', 'algorithm']
		},
		DemoEntry{
			id:      'doc_locales'
			label:   'Locales'
			group:   'welcome'
			summary: 'Locale bundles, translation, and runtime language switching.'
			tags:    ['doc', 'locale', 'i18n', 'translation', 'rtl']
		},
		DemoEntry{
			id:      'doc_markdown'
			label:   'Markdown'
			group:   'welcome'
			summary: 'Guide to the markdown renderer and its options.'
			tags:    ['doc', 'markdown', 'renderer']
		},
		DemoEntry{
			id:      'doc_native_dialogs'
			label:   'Native Dialogs'
			group:   'welcome'
			summary: 'Guide to native file, save, and alert dialog APIs.'
			tags:    ['doc', 'dialog', 'native', 'file']
		},
		DemoEntry{
			id:      'doc_performance'
			label:   'Performance'
			group:   'welcome'
			summary: 'Performance optimization tips and best practices.'
			tags:    ['doc', 'performance', 'optimization', 'speed']
		},
		DemoEntry{
			id:      'doc_printing'
			label:   'Printing'
			group:   'welcome'
			summary: 'Guide to PDF export and native print dialog APIs.'
			tags:    ['doc', 'print', 'pdf', 'export']
		},
		DemoEntry{
			id:      'doc_shaders'
			label:   'Shaders'
			group:   'welcome'
			summary: 'Guide to custom fragment shader integration.'
			tags:    ['doc', 'shader', 'glsl', 'metal']
		},
		DemoEntry{
			id:      'doc_splitter'
			label:   'Splitter'
			group:   'welcome'
			summary: 'Guide to resizable split panel APIs.'
			tags:    ['doc', 'splitter', 'panel', 'resize']
		},
		DemoEntry{
			id:      'doc_svg'
			label:   'SVG'
			group:   'welcome'
			summary: 'Guide to SVG rendering and inline SVG APIs.'
			tags:    ['doc', 'svg', 'vector', 'path']
		},
		DemoEntry{
			id:      'doc_tables'
			label:   'Tables'
			group:   'welcome'
			summary: 'Table component documentation and column configuration.'
			tags:    ['doc', 'table', 'columns', 'data']
		},
		DemoEntry{
			id:      'doc_themes'
			label:   'Themes'
			group:   'welcome'
			summary: 'Theme system: presets, custom themes, JSON, runtime switching.'
			tags:    ['doc', 'theme', 'color', 'style']
		},
		DemoEntry{
			id:      'color_picker'
			label:   'Color Picker'
			group:   'input'
			summary: 'Pick RGBA and optional HSV values'
			tags:    ['color', 'hsv', 'rgba']
		},
		DemoEntry{
			id:      'date_picker'
			label:   'Date Picker'
			group:   'input'
			summary: 'Select one or many dates from a calendar'
			tags:    ['calendar', 'dates', 'input']
		},
		DemoEntry{
			id:      'date_picker_roller'
			label:   'Date Picker Roller'
			group:   'input'
			summary: 'Roll wheel-style month/day/year controls'
			tags:    ['date', 'roller', 'time']
		},
		DemoEntry{
			id:      'input'
			label:   'Input'
			group:   'input'
			summary: 'Single-line, password, and multiline text input'
			tags:    ['text', 'textarea', 'password']
		},
		DemoEntry{
			id:      'input_date'
			label:   'Input Date'
			group:   'input'
			summary: 'Text input with date picker dropdown'
			tags:    ['date', 'input', 'calendar']
		},
		DemoEntry{
			id:      'numeric_input'
			label:   'Numeric Input'
			group:   'input'
			summary: 'Locale-aware number input with step controls'
			tags:    ['number', 'decimal', 'locale', 'spinner']
		},
		DemoEntry{
			id:      'forms'
			label:   'Forms'
			group:   'input'
			summary: 'Form runtime with sync/async validation and slots'
			tags:    ['form', 'validation', 'async', 'touched', 'dirty']
		},
		DemoEntry{
			id:      'listbox'
			label:   'List Box'
			group:   'selection'
			summary: 'Single and multi-select list options'
			tags:    ['list', 'multi', 'select']
		},
		DemoEntry{
			id:      'radio'
			label:   'Radio'
			group:   'selection'
			summary: 'Single radio control'
			tags:    ['option', 'boolean', 'choice']
		},
		DemoEntry{
			id:      'radio_group'
			label:   'Radio Button Group'
			group:   'selection'
			summary: 'Mutually exclusive options in row or column'
			tags:    ['group', 'options', 'select']
		},
		DemoEntry{
			id:      'range_slider'
			label:   'Range Slider'
			group:   'selection'
			summary: 'Drag horizontal or vertical value controls'
			tags:    ['slider', 'value', 'range']
		},
		DemoEntry{
			id:      'drag_reorder'
			label:   'Drag Reorder'
			group:   'selection'
			summary: 'Drag-to-reorder items in lists, tabs, and trees'
			tags:    ['drag', 'reorder', 'list', 'tabs', 'tree', 'keyboard']
		},
		DemoEntry{
			id:      'combobox'
			label:   'Combobox'
			group:   'selection'
			summary: 'Single-select with typeahead filtering'
			tags:    ['dropdown', 'filter', 'typeahead', 'autocomplete']
		},
		DemoEntry{
			id:      'select'
			label:   'Select'
			group:   'selection'
			summary: 'Dropdown with optional multi-select'
			tags:    ['dropdown', 'pick', 'options']
		},
		DemoEntry{
			id:      'switch'
			label:   'Switch'
			group:   'selection'
			summary: 'On/off switch control'
			tags:    ['toggle', 'boolean', 'control']
		},
		DemoEntry{
			id:      'toggle'
			label:   'Toggle'
			group:   'selection'
			summary: 'Checkbox-style and icon toggles'
			tags:    ['checkbox', 'boolean', 'control']
		},
		DemoEntry{
			id:      'image'
			label:   'Image'
			group:   'graphics'
			summary: 'Render local or remote image assets'
			tags:    ['photo', 'asset', 'media']
		},
		DemoEntry{
			id:      'markdown'
			label:   'Markdown'
			group:   'text'
			summary: 'Render markdown into styled rich content'
			tags:    ['docs', 'text', 'rich']
		},
		DemoEntry{
			id:      'rectangle'
			label:   'Rectangle'
			group:   'graphics'
			summary: 'Draw colored shapes with border and radius'
			tags:    ['shape', 'primitive', 'box']
		},
		DemoEntry{
			id:      'rtf'
			label:   'Rich Text Format'
			group:   'text'
			summary: 'Mixed styles, links, and inline rich runs'
			tags:    ['rich text', 'link', 'style']
		},
		DemoEntry{
			id:      'svg'
			label:   'SVG'
			group:   'graphics'
			summary: 'Render vector graphics from svg strings'
			tags:    ['vector', 'icon', 'path']
		},
		DemoEntry{
			id:      'table'
			label:   'Table'
			group:   'data'
			summary: 'Declarative and sortable table data'
			tags:    ['rows', 'columns', 'csv']
		},
		DemoEntry{
			id:      'data_grid'
			label:   'Data Grid'
			group:   'data'
			summary: 'Controlled virtualized grid for interactive tabular data'
			tags:    ['grid', 'virtualized', 'data']
		},
		DemoEntry{
			id:      'data_source'
			label:   'Data Source'
			group:   'data'
			summary: 'Async data-source backed grid with CRUD'
			tags:    ['async', 'pagination', 'crud', 'source']
		},
		DemoEntry{
			id:      'text'
			label:   'Text'
			group:   'text'
			summary: 'Typography, gradients, outlines, and curved text'
			tags:    ['font', 'type', 'styles', 'gradient', 'outline', 'stroke', 'curve']
		},
		DemoEntry{
			id:      'tree'
			label:   'Tree View'
			group:   'data'
			summary: 'Hierarchical expandable node display'
			tags:    ['nodes', 'hierarchy', 'outline']
		},
		DemoEntry{
			id:      'printing'
			label:   'Printing'
			group:   'graphics'
			summary: 'Export current view to PDF and open native print dialog'
			tags:    ['print', 'pdf', 'export']
		},
		DemoEntry{
			id:      'breadcrumb'
			label:   'Breadcrumb'
			group:   'navigation'
			summary: 'Trail navigation with optional content panels'
			tags:    ['breadcrumb', 'navigation', 'trail', 'path']
		},
		DemoEntry{
			id:      'menus'
			label:   'Menus + Menubar'
			group:   'navigation'
			summary: 'Nested menus, separators, and custom menu items'
			tags:    ['menu', 'menubar', 'submenu']
		},
		DemoEntry{
			id:      'scrollbar'
			label:   'Scrollable Containers'
			group:   'navigation'
			summary: 'Bind scrollable layouts to shared scroll ids'
			tags:    ['scrollbar', 'scroll', 'container']
		},
		DemoEntry{
			id:      'splitter'
			label:   'Splitter'
			group:   'navigation'
			summary: 'Resizable panes with drag, keyboard, and collapse'
			tags:    ['split', 'pane', 'resize']
		},
		DemoEntry{
			id:      'tab_control'
			label:   'Tab Control'
			group:   'navigation'
			summary: 'Switch content panels with keyboard-friendly tabs'
			tags:    ['tabs', 'navigation', 'panes']
		},
		DemoEntry{
			id:      'button'
			label:   'Button'
			group:   'feedback'
			summary: 'Trigger actions with click and keyboard focus'
			tags:    ['action', 'press', 'click']
		},
		DemoEntry{
			id:      'progress_bar'
			label:   'Progress Bar'
			group:   'feedback'
			summary: 'Determinate and indeterminate progress indicators'
			tags:    ['progress', 'loader', 'status']
		},
		DemoEntry{
			id:      'pulsar'
			label:   'Pulsar'
			group:   'feedback'
			summary: 'Animated pulse indicator with optional icons'
			tags:    ['pulse', 'loading', 'indicator']
		},
		DemoEntry{
			id:      'toast'
			label:   'Toast'
			group:   'feedback'
			summary: 'Non-blocking notifications with auto-dismiss and actions'
			tags:    ['notification', 'alert', 'severity', 'stack']
		},
		DemoEntry{
			id:      'badge'
			label:   'Badge'
			group:   'feedback'
			summary: 'Numeric and colored pill labels for counts and status'
			tags:    ['badge', 'count', 'status', 'pill', 'label']
		},
		DemoEntry{
			id:      'dialog'
			label:   'Dialog'
			group:   'overlays'
			summary: 'Message, confirm, prompt, and custom dialogs'
			tags:    ['modal', 'confirm', 'prompt']
		},
		DemoEntry{
			id:      'expand_panel'
			label:   'Expand Panel'
			group:   'overlays'
			summary: 'Collapsible region with custom header and content'
			tags:    ['accordion', 'collapse', 'panel']
		},
		DemoEntry{
			id:      'command_palette'
			label:   'Command Palette'
			group:   'overlays'
			summary: 'Keyboard-first searchable action list'
			tags:    ['command', 'search', 'palette', 'keyboard']
		},
		DemoEntry{
			id:      'tooltip'
			label:   'Tooltip'
			group:   'overlays'
			summary: 'Hover hints with custom placement and content'
			tags:    ['hover', 'hint', 'floating']
		},
		DemoEntry{
			id:      'row'
			label:   'Row'
			group:   'layout'
			summary: 'Horizontal container arranging children left-to-right'
			tags:    ['row', 'horizontal', 'container', 'layout']
		},
		DemoEntry{
			id:      'column_demo'
			label:   'Column'
			group:   'layout'
			summary: 'Vertical container arranging children top-to-bottom'
			tags:    ['column', 'vertical', 'container', 'layout']
		},
		DemoEntry{
			id:      'wrap_panel'
			label:   'Wrap Panel'
			group:   'layout'
			summary: 'Flow layout that wraps children to the next line'
			tags:    ['wrap', 'flow', 'reflow', 'layout']
		},
		DemoEntry{
			id:      'overflow_panel'
			label:   'Overflow Panel'
			group:   'layout'
			summary: 'Row that hides non-fitting children in a dropdown'
			tags:    ['overflow', 'toolbar', 'responsive', 'layout']
		},
		DemoEntry{
			id:      'sidebar'
			label:   'Sidebar'
			group:   'layout'
			summary: 'Animated panel that slides in/out'
			tags:    ['sidebar', 'panel', 'slide', 'layout']
		},
		DemoEntry{
			id:      'animations'
			label:   'Animations'
			group:   'graphics'
			summary: 'Tween, spring, and layout transition samples'
			tags:    ['motion', 'tween', 'spring']
		},
		DemoEntry{
			id:      'gradient'
			label:   'Gradients'
			group:   'graphics'
			summary: 'Linear and radial gradient fills'
			tags:    ['gradient', 'linear', 'radial', 'fill']
		},
		DemoEntry{
			id:      'box_shadows'
			label:   'Box Shadows'
			group:   'graphics'
			summary: 'Shadow presets with spread_radius behavior notes'
			tags:    ['shadow', 'depth', 'blur']
		},
		DemoEntry{
			id:      'shader'
			label:   'Custom Shaders'
			group:   'graphics'
			summary: 'Custom fragment shaders for dynamic fills'
			tags:    ['shader', 'glsl', 'metal']
		},
		DemoEntry{
			id:      'theme_gen'
			label:   'Theme'
			group:   'graphics'
			summary: 'Generate a theme from a seed color, tint level, and palette strategy'
			tags:    ['theme', 'color', 'palette', 'generator']
		},
		DemoEntry{
			id:      'icons'
			label:   'Icons'
			group:   'text'
			summary: 'Icon font catalog and glyph references'
			tags:    ['icon', 'font', 'glyph']
		},
	]
}

fn entry_matches_query(entry DemoEntry, query string) bool {
	if query.len == 0 {
		return true
	}
	q := query.to_lower()
	if entry.id.to_lower().contains(q) || entry.label.to_lower().contains(q)
		|| entry.summary.to_lower().contains(q) || entry.group.to_lower().contains(q) {
		return true
	}
	for tag in entry.tags {
		if tag.to_lower().contains(q) {
			return true
		}
	}
	return false
}

fn filtered_entries(app &ShowcaseApp) []DemoEntry {
	mut out := []DemoEntry{}
	for entry in demo_entries() {
		if app.selected_group != 'all' && entry.group != app.selected_group {
			continue
		}
		if !entry_matches_query(entry, app.nav_query) {
			continue
		}
		out << entry
	}
	return out
}

fn has_entry(entries []DemoEntry, selected string) bool {
	for entry in entries {
		if entry.id == selected {
			return true
		}
	}
	return false
}

fn selected_entry(entries []DemoEntry, selected string) DemoEntry {
	for entry in entries {
		if entry.id == selected {
			return entry
		}
	}
	return entries[0]
}

fn preferred_component_for_group(group string, entries []DemoEntry) string {
	if entries.len == 0 {
		return ''
	}
	mut best := entries[0]
	for entry in entries[1..] {
		if entry_sort_before(entry, best) {
			best = entry
		}
	}
	return best.id
}

fn entry_sort_before(a DemoEntry, b DemoEntry) bool {
	a_pin := if a.id == 'welcome' {
		0
	} else if a.id == 'doc_get_started' {
		1
	} else {
		2
	}
	b_pin := if b.id == 'welcome' {
		0
	} else if b.id == 'doc_get_started' {
		1
	} else {
		2
	}
	if a_pin != b_pin {
		return a_pin < b_pin
	}
	a_label := a.label.to_lower()
	b_label := b.label.to_lower()
	if a_label != b_label {
		return a_label < b_label
	}
	return a.id.to_lower() < b.id.to_lower()
}

fn catalog_panel(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	entries := filtered_entries(app)
	if entries.len == 0 {
		app.selected_component = ''
		app.show_docs = false
		w.scroll_vertical_to(id_scroll_gallery, 0)
		w.scroll_horizontal_to(id_scroll_gallery, 0)
	} else if !has_entry(entries, app.selected_component) {
		app.selected_component = preferred_component_for_group(app.selected_group, entries)
		app.show_docs = false
		w.scroll_vertical_to(id_scroll_gallery, 0)
		w.scroll_horizontal_to(id_scroll_gallery, 0)
	}
	return gui.column(
		width:   300
		sizing:  gui.fixed_fill
		color:   gui.theme().color_panel
		padding: gui.theme().padding_small
		spacing: gui.theme().spacing_small
		content: [
			gui.text(text: 'Component Catalog', text_style: gui.theme().b3),
			gui.input(
				id:              'showcase_catalog_query'
				id_focus:        10
				text:            app.nav_query
				mode:            .single_line
				placeholder:     'Search controls...'
				sizing:          gui.fill_fit
				on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.nav_query = s
				}
			),
			group_picker(app),
			line(),
			gui.column(
				id_scroll:       id_scroll_catalog
				sizing:          gui.fill_fill
				spacing:         2
				padding:         gui.Padding{
					...gui.padding_none
					right: gui.theme().scrollbar_style.size + 4
				}
				scrollbar_cfg_y: &gui.ScrollbarCfg{
					gap_edge: 3
				}
				content:         catalog_rows(entries, app)
			),
			gui.row(
				padding: gui.padding_none
				spacing: 8
				sizing:  gui.fill_fit
				h_align: .end
				v_align: .middle
				content: [
					toggle_locale(app),
					w.theme_toggle(gui.ThemeToggleCfg{
						id:            'showcase_theme'
						id_focus:      9190
						float_anchor:  .top_right
						float_tie_off: .bottom_right
						on_select:     fn (name string, mut _ gui.Event, mut w gui.Window) {
							t := gui.theme_get(name) or { return }
							mut app := w.state[ShowcaseApp]()
							sync_theme_gen_from_cfg(mut app, t.cfg)
						}
					}),
				]
			),
		]
	)
}

fn group_picker(app &ShowcaseApp) gui.View {
	return gui.wrap(
		sizing:  gui.fill_fit
		spacing: 3
		content: [
			group_picker_item('Welcome', 'welcome', app),
			group_picker_item('All', 'all', app),
			group_picker_item('Text', 'text', app),
			group_picker_item('Input', 'input', app),
			group_picker_item('Selection', 'selection', app),
			group_picker_item('Data', 'data', app),
			group_picker_item('Graphics', 'graphics', app),
			group_picker_item('Nav', 'navigation', app),
			group_picker_item('Layout', 'layout', app),
			group_picker_item('Feedback', 'feedback', app),
			group_picker_item('Overlays', 'overlays', app),
		]
	)
}

fn group_picker_item(label string, key string, app &ShowcaseApp) gui.View {
	is_selected := app.selected_group == key
	return gui.row(
		padding:  gui.padding(3, 6, 3, 6)
		color:    if is_selected {
			gui.theme().color_active
		} else {
			gui.theme().color_background
		}
		radius:   3
		content:  [gui.text(text: label, text_style: gui.theme().n5)]
		on_click: fn [key] (_ voidptr, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.selected_group = key
			app.show_docs = false
			app.nav_query = ''
			entries := filtered_entries(app)
			app.selected_component = preferred_component_for_group(key, entries)
			w.scroll_vertical_to(id_scroll_catalog, 0)
			w.scroll_vertical_to(id_scroll_gallery, 0)
			w.scroll_horizontal_to(id_scroll_gallery, 0)
			e.is_handled = true
		}
		on_hover: fn (mut _ gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.set_mouse_cursor_pointing_hand()
		}
	)
}

fn catalog_rows(entries []DemoEntry, app &ShowcaseApp) []gui.View {
	mut rows := []gui.View{}
	if entries.len == 0 {
		rows << gui.text(text: 'No matching components', text_style: gui.theme().n4)
		return rows
	}
	for group in demo_groups() {
		mut group_entries := []DemoEntry{}
		for entry in entries {
			if entry.group == group.key {
				group_entries << entry
			}
		}
		if group_entries.len == 0 {
			continue
		}
		group_entries.sort_with_compare(fn (a &DemoEntry, b &DemoEntry) int {
			a_pin := if a.id == 'welcome' {
				0
			} else if a.id == 'doc_get_started' {
				1
			} else {
				2
			}
			b_pin := if b.id == 'welcome' {
				0
			} else if b.id == 'doc_get_started' {
				1
			} else {
				2
			}
			if a_pin != b_pin {
				return a_pin - b_pin
			}
			a_label := a.label.to_lower()
			b_label := b.label.to_lower()
			if a_label < b_label {
				return -1
			}
			if a_label > b_label {
				return 1
			}
			a_id := a.id.to_lower()
			b_id := b.id.to_lower()
			if a_id < b_id {
				return -1
			}
			if a_id > b_id {
				return 1
			}
			return 0
		})
		if rows.len > 0 {
			rows << gui.row(
				height:  6
				sizing:  gui.fill_fixed
				padding: gui.padding_none
			)
		}
		rows << gui.text(text: group.label, text_style: gui.theme().b5)
		for entry in group_entries {
			rows << catalog_row(entry, app)
		}
	}
	return rows
}

fn catalog_row(entry DemoEntry, app &ShowcaseApp) gui.View {
	is_selected := app.selected_component == entry.id
	return gui.row(
		color:    if is_selected { gui.theme().color_active } else { gui.color_transparent }
		padding:  gui.padding(3, 6, 3, 6)
		radius:   4
		sizing:   gui.fill_fit
		content:  [
			gui.text(text: entry.label, text_style: gui.theme().n4),
			gui.row(sizing: gui.fill_fit, padding: gui.padding_none),
		]
		on_click: fn [entry] (_ voidptr, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.selected_component = entry.id
			app.show_docs = false
			w.scroll_vertical_to(id_scroll_gallery, 0)
			w.scroll_horizontal_to(id_scroll_gallery, 0)
			e.is_handled = true
		}
		on_hover: fn [is_selected] (mut layout gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.set_mouse_cursor_pointing_hand()
			if !is_selected {
				layout.shape.color = gui.theme().menubar_style.color_select
			}
		}
	)
}

fn detail_panel_padding() gui.Padding {
	base := gui.theme().padding_large
	return gui.Padding{
		...base
		right: base.right + gui.theme().scrollbar_style.size + f32(4)
	}
}

fn detail_panel(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	entries := filtered_entries(app)
	if entries.len == 0 {
		return gui.column(
			id_scroll:       id_scroll_gallery
			radius:          0
			scrollbar_cfg_y: &gui.ScrollbarCfg{
				gap_edge: 4
			}
			sizing:          gui.fill_fill
			padding:         detail_panel_padding()
			content:         [
				gui.text(text: 'No component matches filter', text_style: gui.theme().b2),
			]
		)
	}
	if !has_entry(entries, app.selected_component) {
		app.selected_component = preferred_component_for_group(app.selected_group, entries)
	}
	entry := selected_entry(entries, app.selected_component)
	mut content := []gui.View{}
	content << view_title_bar(entry.id, entry.label, app.show_docs)
	content << gui.text(text: entry.summary, text_style: gui.theme().n3)
	if app.show_docs && entry.group != 'welcome' {
		content << w.markdown(
			id:     'doc_${entry.id}'
			source: component_doc(entry.id)
			mode:   .wrap
		)
	} else {
		content << component_demo(mut w, entry.id)
	}
	content << line()
	content << gui.text(
		text:       'Related examples: ${related_examples(entry.id)}'
		text_style: gui.theme().n5
	)
	return gui.column(
		id_scroll:       id_scroll_gallery
		radius:          0
		scrollbar_cfg_y: &gui.ScrollbarCfg{
			gap_edge: 4
		}
		sizing:          gui.fill_fill
		padding:         detail_panel_padding()
		spacing:         gui.spacing_large
		content:         content
	)
}

fn component_demo(mut w gui.Window, id string) gui.View {
	return match id {
		'welcome' { demo_welcome(mut w) }
		'button' { demo_button(mut w) }
		'input' { demo_input(w) }
		'toggle' { demo_toggle(w) }
		'switch' { demo_switch(w) }
		'radio' { demo_radio(w) }
		'radio_group' { demo_radio_group(w) }
		'combobox' { demo_combobox(mut w) }
		'select' { demo_select(w) }
		'listbox' { demo_list_box(mut w) }
		'range_slider' { demo_range_slider(w) }
		'progress_bar' { demo_progress_bar(w) }
		'pulsar' { demo_pulsar(mut w) }
		'toast' { demo_toast(mut w) }
		'badge' { demo_badge() }
		'breadcrumb' { demo_breadcrumb(mut w) }
		'menus' { demo_menu(mut w) }
		'dialog' { demo_dialog() }
		'tree' { demo_tree(mut w) }
		'drag_reorder' { demo_drag_reorder(mut w) }
		'printing' { demo_printing(w) }
		'text' { demo_text() }
		'rtf' { demo_rtf() }
		'table' { demo_table(mut w) }
		'data_grid' { demo_data_grid(mut w) }
		'data_source' { demo_data_source(mut w) }
		'date_picker' { demo_date_picker(mut w) }
		'input_date' { demo_input_date(mut w) }
		'numeric_input' { demo_numeric_input(w) }
		'forms' { demo_forms(w) }
		'date_picker_roller' { demo_date_picker_roller(mut w) }
		'svg' { demo_svg() }
		'image' { demo_image() }
		'expand_panel' { demo_expand_panel(w) }
		'icons' { demo_icons() }
		'gradient' { demo_gradient() }
		'box_shadows' { demo_box_shadows() }
		'shader' { demo_shader() }
		'animations' { demo_animations(mut w) }
		'color_picker' { demo_color_picker(w) }
		'theme_gen' { demo_theme_gen(mut w) }
		'markdown' { demo_markdown(mut w) }
		'tab_control' { demo_tab_control(w) }
		'command_palette' { demo_command_palette(mut w) }
		'tooltip' { demo_tooltip() }
		'rectangle' { demo_rectangle() }
		'scrollbar' { demo_scrollbar() }
		'splitter' { demo_splitter(w) }
		'row' { demo_row() }
		'column_demo' { demo_column() }
		'wrap_panel' { demo_wrap_panel(w) }
		'overflow_panel' { demo_overflow_panel(w) }
		'sidebar' { demo_sidebar(mut w) }
		'doc_get_started' { demo_doc(mut w, 'doc_get_started', doc_get_started_source) }
		'doc_animations' { demo_doc(mut w, 'doc_animations', doc_animations_source) }
		'doc_architecture' { demo_doc(mut w, 'doc_architecture', doc_architecture_source) }
		'doc_containers' { demo_doc(mut w, 'doc_containers', doc_containers_source) }
		'doc_custom_widgets' { demo_doc(mut w, 'doc_custom_widgets', doc_custom_widgets_source) }
		'doc_data_grid' { demo_doc(mut w, 'doc_data_grid', doc_data_grid_source) }
		'doc_forms' { demo_doc(mut w, 'doc_forms', doc_forms_source) }
		'doc_gradients' { demo_doc(mut w, 'doc_gradients', doc_gradients_source) }
		'doc_layout_algorithm' { demo_doc(mut w, 'doc_layout_algorithm', doc_layout_algorithm_source) }
		'doc_locales' { demo_doc(mut w, 'doc_locales', doc_locales_source) }
		'doc_markdown' { demo_doc(mut w, 'doc_markdown', doc_markdown_source) }
		'doc_native_dialogs' { demo_doc(mut w, 'doc_native_dialogs', doc_native_dialogs_source) }
		'doc_performance' { demo_doc(mut w, 'doc_performance', doc_performance_source) }
		'doc_printing' { demo_doc(mut w, 'doc_printing', doc_printing_source) }
		'doc_shaders' { demo_doc(mut w, 'doc_shaders', doc_shaders_source) }
		'doc_splitter' { demo_doc(mut w, 'doc_splitter', doc_splitter_source) }
		'doc_svg' { demo_doc(mut w, 'doc_svg', doc_svg_source) }
		'doc_tables' { demo_doc(mut w, 'doc_tables', doc_tables_source) }
		'doc_themes' { demo_doc(mut w, 'doc_themes', doc_themes_source) }
		else { gui.text(text: 'No demo configured') }
	}
}

fn related_examples(id string) string {
	return match id {
		'welcome' { 'examples/showcase.v, examples/README.md' }
		'button' { 'examples/buttons.v' }
		'input' { 'examples/inputs.v, examples/multiline_input.v' }
		'toggle', 'switch' { 'examples/toggles.v' }
		'radio', 'radio_group' { 'examples/radio_button_group.v' }
		'combobox' { 'examples/combobox.v' }
		'select' { 'examples/select_demo.v, docs/FORMS.md' }
		'listbox' { 'examples/listbox.v' }
		'range_slider' { 'examples/range_sliders.v' }
		'progress_bar' { 'examples/progress_bars.v' }
		'pulsar' { 'examples/pulsars.v' }
		'toast' { 'examples/toast.v' }
		'badge' { 'examples/badge.v' }
		'breadcrumb' { 'examples/breadcrumb.v' }
		'menus' { 'examples/menu_demo.v, examples/context_menu_demo.v' }
		'dialog' { 'examples/dialogs.v' }
		'tree' { 'examples/tree_view.v' }
		'drag_reorder' { 'examples/drag_reorder.v' }
		'printing' { 'examples/printing.v' }
		'text' { 'examples/fonts.v, examples/gradient_text.v, examples/text_transform.v' }
		'rtf' { 'examples/rtf.v' }
		'table' { 'examples/table_demo.v' }
		'data_grid' { 'examples/data_grid_demo.v, docs/DATA_GRID.md' }
		'data_source' { 'examples/data_grid_data_source_demo.v' }
		'numeric_input' { 'examples/numeric_input.v' }
		'forms' { 'examples/form_validation.v, docs/FORMS.md' }
		'date_picker', 'input_date' { 'examples/date_picker_options.v, examples/date_time.v' }
		'date_picker_roller' { 'examples/date_picker_roller.v' }
		'svg' { 'examples/svg_demo.v, examples/tiger.v' }
		'image' { 'examples/image_demo.v, examples/remote_image.v' }
		'expand_panel' { 'examples/expand_panel.v' }
		'icons' { 'examples/icon_font_demo.v' }
		'gradient' { 'examples/gradient_demo.v, examples/gradient_border_demo.v' }
		'box_shadows' { 'examples/shadow_demo.v' }
		'shader' { 'examples/custom_shader.v' }
		'animations' { 'examples/animations.v, examples/animation_stress.v' }
		'color_picker' { 'examples/color_picker.v' }
		'theme_gen' { 'examples/showcase.v' }
		'markdown' { 'examples/markdown.v, examples/doc_viewer.v' }
		'tab_control' { 'examples/tab_view.v' }
		'command_palette' { 'examples/command_palette.v' }
		'tooltip' { 'examples/tooltips.v' }
		'rectangle' { 'examples/border_demo.v, examples/gradient_border_demo.v' }
		'scrollbar' { 'examples/scroll_demo.v, examples/column_scroll.v' }
		'splitter' { 'examples/split_panel.v' }
		'row' { 'examples/showcase.v' }
		'column_demo' { 'examples/column_scroll.v' }
		'wrap_panel' { 'examples/wrap_panel.v' }
		'overflow_panel' { 'examples/overflow_panel_demo.v' }
		'sidebar' { 'examples/sidebar.v' }
		else { 'examples/showcase.v' }
	}
}

fn component_doc(id string) string {
	return match id {
		'button' { button_doc }
		'input' { input_doc }
		'toggle' { toggle_doc }
		'switch' { switch_doc }
		'radio' { radio_doc }
		'radio_group' { radio_group_doc }
		'combobox' { combobox_doc }
		'select' { select_doc }
		'listbox' { listbox_doc }
		'range_slider' { range_slider_doc }
		'progress_bar' { progress_bar_doc }
		'pulsar' { pulsar_doc }
		'toast' { toast_doc }
		'badge' { badge_doc }
		'breadcrumb' { breadcrumb_doc }
		'menus' { menus_doc }
		'dialog' { dialog_doc }
		'tree' { tree_doc }
		'drag_reorder' { drag_reorder_doc }
		'printing' { printing_doc }
		'text' { text_doc }
		'rtf' { rtf_doc }
		'table' { table_doc }
		'data_grid' { data_grid_doc }
		'data_source' { data_source_doc }
		'date_picker' { date_picker_doc }
		'input_date' { input_date_doc }
		'numeric_input' { numeric_input_doc }
		'forms' { forms_doc }
		'date_picker_roller' { date_picker_roller_doc }
		'svg' { svg_doc }
		'image' { image_doc }
		'expand_panel' { expand_panel_doc }
		'icons' { icons_doc }
		'gradient' { gradient_doc }
		'box_shadows' { box_shadows_doc }
		'shader' { shader_doc }
		'animations' { animations_doc }
		'color_picker' { color_picker_doc }
		'theme_gen' { theme_gen_doc }
		'markdown' { markdown_doc }
		'tab_control' { tab_control_doc }
		'command_palette' { command_palette_doc }
		'tooltip' { tooltip_doc }
		'rectangle' { rectangle_doc }
		'scrollbar' { scrollbar_doc }
		'splitter' { splitter_doc }
		'row' { row_doc }
		'column_demo' { column_doc }
		'wrap_panel' { wrap_panel_doc }
		'overflow_panel' { overflow_panel_doc }
		'sidebar' { sidebar_doc }
		else { '*Documentation coming soon.*' }
	}
}

fn doc_button(show_docs bool) gui.View {
	return gui.row(
		padding:  gui.padding(2, 4, 2, 4)
		radius:   3
		color:    if show_docs { gui.theme().color_active } else { gui.color_transparent }
		content:  [
			gui.text(
				text:       gui.icon_book
				text_style: gui.theme().icon4
			),
		]
		on_click: fn (_ voidptr, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.show_docs = !app.show_docs
			e.is_handled = true
		}
		on_hover: fn (mut _ gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.set_mouse_cursor_pointing_hand()
		}
	)
}

fn view_title_bar(id string, label string, show_docs bool) gui.View {
	mut title_content := [
		gui.text(text: label, text_style: gui.theme().b1),
	]
	if id != 'welcome' && !id.starts_with('doc_') {
		title_content << gui.row(sizing: gui.fill_fit, padding: gui.padding_none)
		title_content << doc_button(show_docs)
	}
	return gui.column(
		spacing: 0
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				padding: gui.padding_none
				content: title_content
			),
			line(),
		]
	)
}

fn line() gui.View {
	return gui.row(
		padding: gui.padding(2, 5, 0, 0)
		sizing:  gui.fill_fit
		content: [
			gui.row(
				height:  1
				sizing:  gui.fill_fit
				padding: gui.padding_none
				color:   gui.theme().color_active
			),
		]
	)
}

const showcase_locale_data = [
	$embed_file('locales/de-DE.json'),
	$embed_file('locales/ar-SA.json'),
	$embed_file('locales/ja-JP.json'),
]!
const showcase_locale_ids = ['en-US', 'de-DE', 'ar-SA', 'ja-JP']!
const showcase_locale_labels = ['EN', 'DE', 'AR', 'JA']!
const showcase_locale_count = 4

fn showcase_locale(idx int) gui.Locale {
	return gui.locale_get(showcase_locale_ids[idx]) or { gui.locale_en_us }
}

fn toggle_locale(app &ShowcaseApp) gui.View {
	idx := app.locale_index
	return gui.button(
		content:      [
			gui.text(
				text:       showcase_locale_labels[idx]
				text_style: gui.theme().b5
			),
		]
		padding:      gui.padding_two_five
		color_border: gui.color_transparent
		on_click:     fn [idx] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			mut a := w.state[ShowcaseApp]()
			a.locale_index = (idx + 1) % showcase_locale_count
			w.set_locale(showcase_locale(a.locale_index))
		}
	)
}

// ==============================================================
// Buttons
// ==============================================================

fn button_feature_rows(w &gui.Window, base_focus u32) []gui.View {
	app := w.state[ShowcaseApp]()
	button_text := '${app.button_clicks} Clicks Given'
	button_width := f32(160)
	progress := f32(math.fmod(f64(app.button_clicks) / 25.0, 1.0))
	return [
		showcase_button_row('Plain ole button', gui.button(
			id_focus:    base_focus + 0
			min_width:   button_width
			max_width:   button_width
			size_border: 0
			content:     [gui.text(text: button_text)]
			on_click:    showcase_button_click
		)),
		showcase_button_row('Disabled button', gui.button(
			id_focus:  base_focus + 1
			min_width: button_width
			max_width: button_width
			disabled:  true
			content:   [gui.text(text: button_text)]
			on_click:  showcase_button_click
		)),
		showcase_button_row('With border', gui.button(
			id_focus:    base_focus + 2
			min_width:   button_width
			max_width:   button_width
			size_border: 2
			content:     [gui.text(text: button_text)]
			on_click:    showcase_button_click
		)),
		showcase_button_row('With focus border', gui.button(
			id_focus:    base_focus + 3
			min_width:   button_width
			max_width:   button_width
			size_border: 2
			content:     [gui.text(text: button_text)]
			on_click:    showcase_button_click
		)),
		showcase_button_row('With other content', gui.button(
			id:           'showcase-button-progress'
			id_focus:     base_focus + 4
			min_width:    200
			max_width:    200
			color:        gui.rgb(195, 105, 0)
			color_hover:  gui.rgb(195, 105, 0)
			color_click:  gui.rgb(205, 115, 0)
			size_border:  2
			color_border: gui.rgb(160, 160, 160)
			padding:      gui.padding_medium
			v_align:      .middle
			content:      [gui.text(text: '${app.button_clicks}', min_width: 25),
				gui.progress_bar(
					width:   75
					height:  gui.theme().text_style.size
					percent: progress
				)]
			on_click:     showcase_button_click
		)),
		showcase_button_row('Copy feedback', gui.button(
			id:           'showcase-button-copy'
			id_focus:     base_focus + 5
			min_width:    button_width
			max_width:    button_width
			show_alt:     w.has_animation('btn_alt_showcase-button-copy')
			content:      [gui.text(text: 'Copy to clipboard')]
			alt_content:  [gui.text(text: 'Copied ✓')]
			alt_duration: 2 * time.second
			on_click:     showcase_button_click
		)),
	]
}

fn showcase_button_row(label string, button gui.View) gui.View {
	return gui.row(
		padding: gui.padding_none
		sizing:  gui.fill_fit
		v_align: .middle
		content: [
			gui.row(
				padding: gui.padding_none
				content: [gui.text(text: label, mode: .single_line)]
			),
			gui.row(sizing: gui.fill_fit),
			button,
		]
	)
}

fn showcase_button_click(_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	app.button_clicks += 1
}

// ==============================================================
// Inputs
// ==============================================================

fn text_changed(_ &gui.Layout, s string, mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	app.input_text = s
}

// ==============================================================
// Toggles
// ==============================================================

fn menu(mut window gui.Window) gui.View {
	app := window.state[ShowcaseApp]()

	return window.menubar(
		id_focus: 500
		action:   fn (id string, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.selected_menu_id = id
		}
		items:    [
			gui.MenuItemCfg{
				id:      'file'
				text:    'File'
				submenu: [
					gui.menu_submenu('new', 'New', [
						gui.menu_item_text('here', 'Here'),
						gui.menu_item_text('there', 'There'),
					]),
					gui.menu_submenu('open', 'Open', [
						gui.menu_item_text('no-where', 'No Where'),
						gui.menu_item_text('some-where', 'Some Where'),
						gui.menu_submenu('keep-going', 'Keep Going', [
							gui.menu_item_text('you-are-done', "OK, you're done"),
						]),
					]),
					gui.menu_separator(),
					gui.menu_item_text('exit', 'Exit'),
				]
			},
			gui.MenuItemCfg{
				id:      'edit'
				text:    'Edit'
				submenu: [
					gui.menu_item_text('cut', 'Cut'),
					gui.menu_item_text('copy', 'Copy'),
					gui.menu_item_text('paste', 'Paste'),
					gui.menu_separator(),
					gui.menu_item_text('emoji', 'Emoji & Symbols'),
					gui.menu_item_text('too-long', 'Long menu text item to test line wrappping in menu'),
				]
			},
			gui.MenuItemCfg{
				id:      'view'
				text:    'View'
				submenu: [
					gui.menu_item_text('zoom-in', 'Zoom In'),
					gui.menu_item_text('zoom-out', 'Zoom Out'),
					gui.menu_item_text('zoom-reset', 'Reset Zoom'),
					gui.menu_separator(),
					gui.menu_item_text('project-panel', 'Project Panel'),
					gui.menu_item_text('outline-panel', 'Outline Panel'),
					gui.menu_item_text('terminal-panel', 'Terminal Panel'),
					gui.menu_separator(),
					gui.menu_item_text('full-screen', 'Enter Full Screen'),
				]
			},
			gui.MenuItemCfg{
				id:      'go'
				text:    'Go'
				submenu: [
					gui.menu_item_text('go-back', 'Back'),
					gui.menu_item_text('go-forward', 'Forward'),
					gui.menu_separator(),
					gui.menu_item_text('go-definition', 'Go to Definition'),
					gui.menu_item_text('go-declaration', 'Go to Declaration'),
					gui.menu_item_text('go-to-moon-alice', 'Go to the Moon Alice'),
				]
			},
			gui.MenuItemCfg{
				id:      'window'
				text:    'Window'
				submenu: [
					gui.menu_item_text('window-fill', 'Fill'),
					gui.menu_item_text('window-center', 'Center'),
					gui.menu_separator(),
					gui.menu_submenu('window-move', 'Move & Resize', [
						gui.menu_subtitle('Halves'),
						gui.menu_item_text('half-left', 'Left'),
						gui.menu_item_text('half-top', 'Top'),
						gui.menu_item_text('half-right', 'Right'),
						gui.menu_item_text('half-bottom', 'Bottom'),
						gui.menu_separator(),
						gui.menu_subtitle('Quarters'),
						gui.menu_item_text('quarter-top-left', 'Top Left'),
						gui.menu_item_text('quarter-top-right', 'Top Right'),
						gui.menu_item_text('quarter-bottom-left', 'Bottom Left'),
						gui.menu_item_text('quarter-bottom-right', 'Bottom Right'),
					]),
					gui.menu_item_text('window-full-screen-tile', 'Full Screen Tile'),
				]
			},
			gui.MenuItemCfg{
				id:      'help'
				text:    'Help'
				submenu: [
					gui.MenuItemCfg{
						id:          'search'
						padding:     gui.padding_none
						custom_view: gui.input(
							text:              app.search_text
							id_focus:          100
							width:             100
							min_width:         100
							max_width:         100
							sizing:            gui.fixed_fill
							placeholder:       'Search'
							padding:           gui.Padding{
								...gui.theme().input_style.padding
								top:    2
								bottom: 2
							}
							radius:            0
							radius_border:     0
							text_style:        gui.theme().menubar_style.text_style
							placeholder_style: gui.theme().menubar_style.text_style
							on_text_changed:   fn (_ &gui.Layout, s string, mut w gui.Window) {
								mut app := w.state[ShowcaseApp]()
								app.search_text = s
							}
						)
					},
					gui.menu_separator(),
					gui.menu_item_text('help-me', 'Help'),
				]
			},
		]
	)
}

// ==============================================================
// SVG
// ==============================================================

const svg_home = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/></svg>'
const svg_settings = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"/></svg>'
const svg_star = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>'
const svg_heart = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>'
const svg_check = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>'
const svg_clip_demo = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 80"><defs><clipPath id="c"><circle cx="40" cy="40" r="28"/></clipPath></defs><rect x="4" y="4" width="112" height="72" fill="#3f80ff" clip-path="url(#c)"/><circle cx="80" cy="40" r="28" fill="#ff8c00"/></svg>'
const svg_stroke_demo = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 130 80"><line x1="12" y1="16" x2="118" y2="16" stroke="#56b6ff" stroke-width="10" stroke-linecap="butt"/><line x1="12" y1="40" x2="118" y2="40" stroke="#9be564" stroke-width="10" stroke-linecap="round"/><polyline points="12,68 45,52 78,68 111,52" fill="none" stroke="#ff8c66" stroke-width="8" stroke-linejoin="round"/></svg>'
const svg_transform_demo = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 140 90"><rect x="8" y="10" width="24" height="24" fill="#7aa2ff"/><g transform="translate(48,22) rotate(20)"><rect x="-12" y="-12" width="24" height="24" fill="#57d39b"/></g><g transform="translate(94,26) rotate(-30) scale(1.3,0.8)"><rect x="-12" y="-12" width="24" height="24" fill="#ffb04d"/></g><g transform="translate(120,62) skewX(25)"><rect x="-12" y="-10" width="24" height="20" fill="#ff7d9c"/></g></svg>'
const svg_inherit_demo = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 140 90"><g fill="#7fd1ff" stroke="#11314a" stroke-width="3"><rect x="10" y="14" width="34" height="24" rx="5"/><circle cx="74" cy="26" r="12"/><rect x="96" y="14" width="34" height="24" rx="5" fill="#ff8c96"/></g><g transform="translate(0,40)" fill="#7fd1ff" stroke="#11314a" stroke-width="3"><circle cx="26" cy="20" r="12" fill="#90e87a"/><rect x="56" y="8" width="30" height="24" rx="5"/><rect x="96" y="8" width="34" height="24" rx="5"/></g></svg>'
const tiger_svg_data = $embed_file('../assets/svgs/tiger.svg').to_string()
const missing_svg_path = os.join_path(os.dir(@FILE), 'missing-icon.svg')
const image_clip_asset_data = $embed_file('../assets/image_clip_face.jpg')
const image_clip_asset_fallback_path = os.join_path(os.dir(@FILE), '..', 'assets', 'image_clip_face.jpg')
const image_clip_asset_embedded_path = os.join_path(os.temp_dir(), 'gui_showcase_image_clip_face.jpg')

fn ensure_showcase_embedded_image() {
	if os.exists(image_clip_asset_embedded_path) {
		return
	}
	os.write_file_array(image_clip_asset_embedded_path, image_clip_asset_data.to_bytes()) or {
		eprintln('showcase image embed write failed: ${err.msg()}')
	}
}

fn showcase_image_path() string {
	if os.exists(image_clip_asset_embedded_path) {
		return image_clip_asset_embedded_path
	}
	return image_clip_asset_fallback_path
}

fn on_select(id string, mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	app.tree_id = id
}

fn on_lazy_load(tree_id string, node_id string, mut w gui.Window) {
	spawn fn [tree_id, node_id] (mut w gui.Window) {
		time.sleep(800 * time.millisecond)
		children := match node_id {
			'remote_a' {
				[
					gui.tree_node(text: 'alpha.txt'),
					gui.tree_node(text: 'beta.txt'),
					gui.tree_node(text: 'gamma.txt'),
				]
			}
			'remote_b' {
				[
					gui.tree_node(text: 'one.rs'),
					gui.tree_node(text: 'two.rs'),
				]
			}
			else {
				[gui.tree_node(text: '(empty)')]
			}
		}
		w.queue_command(fn [node_id, children] (mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.lazy_nodes[node_id] = children
			w.update_window()
		})
	}(mut w)
}

fn make_big_tree() []gui.TreeNodeCfg {
	mut nodes := []gui.TreeNodeCfg{cap: 20}
	for i in 0 .. 20 {
		mut children := []gui.TreeNodeCfg{cap: 10}
		for j in 0 .. 10 {
			children << gui.tree_node(text: 'Item ${i}-${j}')
		}
		nodes << gui.TreeNodeCfg{
			text:  'Group ${i}'
			icon:  gui.icon_folder
			nodes: children
		}
	}
	return nodes
}

fn tree_view_sample(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()

	// Build lazy subtree nodes from loaded data.
	remote_a_nodes := app.lazy_nodes['remote_a'] or { []gui.TreeNodeCfg{} }
	remote_b_nodes := app.lazy_nodes['remote_b'] or { []gui.TreeNodeCfg{} }

	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.text(text: 'selected: ${app.tree_id}'),
			gui.text(text: 'Basic tree'),
			w.tree(
				id:        'animals'
				on_select: on_select
				nodes:     [
					gui.tree_node(
						text:  'Mammals'
						icon:  gui.icon_github_alt
						nodes: [
							gui.tree_node(text: 'Lion'),
							gui.tree_node(text: 'Cat'),
							gui.tree_node(text: 'Human', icon: gui.icon_user),
						]
					),
					gui.tree_node(
						text:  'Birds'
						icon:  gui.icon_twitter
						nodes: [
							gui.tree_node(text: 'Condor'),
							gui.tree_node(
								text:  'Eagle'
								nodes: [
									gui.tree_node(text: 'Bald'),
									gui.tree_node(text: 'Golden'),
									gui.tree_node(text: 'Sea'),
								]
							),
							gui.tree_node(text: 'Parrot', icon: gui.icon_cage),
							gui.tree_node(text: 'Robin'),
						]
					),
				]
			),
			gui.text(text: 'Virtualized tree (scroll)'),
			w.tree(
				id:         'big_tree'
				on_select:  on_select
				id_scroll:  id_scroll_tree
				max_height: 200
				nodes:      make_big_tree()
			),
			gui.text(text: 'Lazy-loading tree'),
			w.tree(
				id:           'lazy_tree'
				on_select:    on_select
				on_lazy_load: on_lazy_load
				nodes:        [
					gui.TreeNodeCfg{
						id:    'remote_a'
						text:  'Remote folder A'
						icon:  gui.icon_folder
						lazy:  true
						nodes: remote_a_nodes
					},
					gui.TreeNodeCfg{
						id:    'remote_b'
						text:  'Remote folder B'
						icon:  gui.icon_folder
						lazy:  true
						nodes: remote_b_nodes
					},
					gui.tree_node(text: 'Local item'),
				]
			),
		]
	)
}

// ==============================================================
// Expand Panel
// ==============================================================

fn expand_panel_sample(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.expand_panel(
		open:      app.open_expand_panel
		max_width: 500
		sizing:    gui.fill_fit
		head:      gui.row(
			padding: gui.theme().padding_small
			sizing:  gui.fill_fit
			v_align: .middle
			content: [
				gui.text(text: 'Brazil'),
				gui.row(sizing: gui.fill_fit),
				gui.text(text: 'South America', text_style: gui.theme().n4),
			]
		)
		content:   gui.column(
			sizing:  gui.fill_fit
			padding: gui.padding_small
			content: [
				gui.text(
					text:       brazil_text
					text_style: gui.theme().n4
					mode:       .wrap
				),
			]
		)
		on_toggle: fn (mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.open_expand_panel = !app.open_expand_panel
		}
	)
}

const brazil_text = 'The word "Brazil" likely comes from the Portuguese word for brazilwood, a tree that once grew plentifully along the Brazilian coast. In Portuguese, brazilwood is called pau-brasil, with the word brasil commonly given the etymology "red like an ember", formed from brasa ("ember") and the suffix -il (from -iculum or -ilium). As brazilwood produces a deep red dye, it was highly valued by the European textile industry and was the earliest commercially exploited product from Brazil. Throughout the 16th century, massive amounts of brazilwood were harvested by indigenous peoples (mostly Tupi) along the Brazilian coast, who sold the timber to European traders (mostly Portuguese, but also French) in return for assorted European consumer goods.'

// ==============================================================
// Pulsars
// ==============================================================

fn start_tween(mut w gui.Window, easing gui.EasingFn) {
	app := w.state[ShowcaseApp]()
	target := if app.anim_tween_x < 200 { f32(400) } else { f32(0) }
	w.animation_add(mut gui.TweenAnimation{
		id:       'tween_demo'
		from:     app.anim_tween_x
		to:       target
		duration: 600 * time.millisecond
		easing:   easing
		on_value: fn (v f32, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.anim_tween_x = v
		}
	})
}

fn start_spring(mut w gui.Window, config gui.SpringCfg) {
	app := w.state[ShowcaseApp]()
	target := if app.anim_spring_x < 200 { f32(400) } else { f32(0) }
	mut spring := gui.SpringAnimation{
		id:       'spring_demo'
		config:   config
		on_value: fn (v f32, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.anim_spring_x = v
		}
	}
	spring.spring_to(app.anim_spring_x, target)
	w.animation_add(mut spring)
}

fn start_keyframe(mut w gui.Window) {
	app := w.state[ShowcaseApp]()
	target := if app.anim_keyframe_x < 180 { f32(320) } else { f32(20) }
	w.animation_add(mut gui.KeyframeAnimation{
		id:        'keyframe_demo'
		duration:  550 * time.millisecond
		keyframes: [
			gui.Keyframe{
				at:    0.0
				value: app.anim_keyframe_x
			},
			gui.Keyframe{
				at:     0.35
				value:  target + 35
				easing: gui.ease_out_cubic
			},
			gui.Keyframe{
				at:     0.70
				value:  target - 14
				easing: gui.ease_out_quad
			},
			gui.Keyframe{
				at:     1.0
				value:  target
				easing: gui.ease_out_quad
			},
		]
		on_value:  fn (v f32, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.anim_keyframe_x = v
		}
	})
}

fn layout_boxes(expanded bool, color gui.Color) []gui.View {
	if expanded {
		return [
			gui.row(id: 'box_a', width: 40, height: 40, color: color, radius: 4),
			gui.row(sizing: gui.fill_fit, padding: gui.padding_none),
			gui.row(id: 'box_b', width: 40, height: 40, color: color, radius: 4),
			gui.row(sizing: gui.fill_fit, padding: gui.padding_none),
			gui.row(id: 'box_c', width: 40, height: 40, color: color, radius: 4),
		]
	}
	return [
		gui.row(id: 'box_a', width: 40, height: 40, color: color, radius: 4),
		gui.row(id: 'box_b', width: 40, height: 40, color: color, radius: 4),
		gui.row(id: 'box_c', width: 40, height: 40, color: color, radius: 4),
	]
}

const showcase_welcome_source = '# 👋 Welcome to v-gui

`v-gui` is a declarative GUI framework for V focused on building desktop interfaces with
clear, composable code. Views are described with rows, columns, and controls, while the
framework handles layout, painting, focus, and event routing.

The toolkit targets real app workflows, not toy demos. It includes built-in theming,
keyboard-first navigation, text input with IME support, and modern rendering features so
native-feeling UI can be built quickly and maintained without UI boilerplate.

## ✨ Top Features

- Declarative layout primitives (`row`, `column`, fixed/fill sizing, spacing, padding)
- Rich control set (inputs, selects, tables, tabs, dialogs, trees, date pickers, more)
- Theme system with light/dark palettes and consistent component styling
- Rendering effects: gradients, shadows, blur, SVG, markdown, and custom shaders
- Animation support for tween, spring, keyframe, and layout transitions
- Accessibility and productivity features: focus ids, keyboard nav, IME-aware input

## 🧭 About Showcase

This program is an interactive component catalog.
Use the left panel to filter categories and components, then inspect live demos on
the right.
Each demo includes related example files for deeper reference.'

const doc_get_started_source = $embed_file('../docs/GET_STARTED.md').to_string()
const doc_animations_source = $embed_file('../docs/ANIMATIONS.md').to_string()
const doc_architecture_source = $embed_file('../docs/ARCHITECTURE.md').to_string()
const doc_containers_source = $embed_file('../docs/CONTAINERS.md').to_string()
const doc_custom_widgets_source = $embed_file('../docs/CUSTOM_WIDGETS.md').to_string()
const doc_data_grid_source = $embed_file('../docs/DATA_GRID.md').to_string()
const doc_forms_source = $embed_file('../docs/FORMS.md').to_string()
const doc_gradients_source = $embed_file('../docs/GRADIENTS.md').to_string()
const doc_layout_algorithm_source = $embed_file('../docs/LAYOUT_ALGORITHM.md').to_string()
const doc_locales_source = $embed_file('../docs/LOCALES.md').to_string()
const doc_markdown_source = $embed_file('../docs/MARKDOWN.md').to_string()
const doc_native_dialogs_source = $embed_file('../docs/NATIVE_DIALOGS.md').to_string()
const doc_performance_source = $embed_file('../docs/PERFORMANCE.md').to_string()
const doc_printing_source = $embed_file('../docs/PRINTING.md').to_string()
const doc_shaders_source = $embed_file('../docs/SHADERS.md').to_string()
const doc_splitter_source = $embed_file('../docs/SPLITTER.md').to_string()
const doc_svg_source = $embed_file('../docs/SVG.md').to_string()
const doc_tables_source = $embed_file('../docs/TABLES.md').to_string()
const doc_themes_source = $embed_file('../docs/THEMES.md').to_string()

const showcase_markdown_source = '# Markdown Demo

This panel demonstrates the markdown renderer with real content.
Use this as a quick visual sanity check while building docs-heavy apps.

## Why This Demo Exists

The showcase focuses on discoverability and practical snippets.
Examples include **bold**, *italic*, ~~strikethrough~~, and `inline code`.

## Supported Markdown Features

### Block Elements

- [x] Headings (`#` through `######`)
- [x] Paragraphs and line wrapping
- [x] Unordered and ordered lists
- [x] Task lists (`- [x] done`)
- [x] Blockquotes (including nested)
- [x] Horizontal rules (`---` / `***`)
- [x] Fenced code blocks with highlighting
- [x] Tables with column alignment
- [x] Images (PNG/JPG via `image()`, SVG via `svg()`)
- [x] Mermaid diagrams (fenced `mermaid`)
- [x] Display math (`$$...$$` and fenced `math`)

### Inline Elements

- [x] Bold, italic, and bold-italic
- [x] Strikethrough
- [x] Inline code
- [x] Links
- [x] Inline math (`$...$`)
- [x] Emoji shortcodes (`:smile:` → GitHub-standard names)

### Extended Elements

- [x] Footnotes
- [x] Definition lists
- [x] Abbreviations

### Blockquote Example

> Blockquote: keep each demo focused and discoverable.
>
> Render quality matters as much as parser correctness.

### Code Example

```v
import gui

fn markdown_preview(window &gui.Window) gui.View {
	return gui.column(
		padding: gui.theme().padding_medium
		content: [
			gui.text(text: "Markdown Preview"),
			gui.button(content: [gui.text(text: "Render")]),
		]
	)
}
```

## Feature Matrix Table

| Component | Group   | Status |
|-----------|---------|--------|
| Input     | Input   | Ready  |
| Table     | Data    | Ready  |
| Dialog    | Overlay | Ready  |'

const showcase_data_grid_features_source = '# Data Grid Features

- Virtual row rendering
- Single and multi-column sorting (shift-click)
- Per-column filter row + quick filter input
- Row selection: single, toggle, range
- Keyboard navigation + `ctrl/cmd+a`
- Header keyboard controls (sort/reorder/resize/pin/focus)
- Column resize drag + double-click auto-fit
- Controlled column reorder (`<` / `>` header controls)
- Controlled column pin cycle (`•` -> `↤` -> `↦`)
- Controlled column chooser (`show_column_chooser`, `hidden_column_ids`)
- Group headers (`group_by`) with optional aggregates
- Controlled master-detail rows
- Controlled row edit mode + typed cell editors (`text/select/date/checkbox`)
- Conditional cell formatting (`on_cell_format`)
- Controlled pagination (`page_size`, `page_index`)
- Controlled top frozen rows (`frozen_top_row_ids`)
- Optional frozen header row (`freeze_header`)
- Clipboard copy (`ctrl/cmd+c`) to TSV
- CSV import helper
- CSV helper export
- XLSX helper export
- PDF helper export'

const button_doc = '# Button

Trigger actions with click and keyboard focus.

## Usage

```v
gui.button(
    content:  [gui.text(text: "Save")],
    on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
        // handle click
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| content | []View | Child views inside the button |
| alt_content | []View | Temporary replacement content |
| alt_duration | time.Duration | How long alt_content is shown |
| tooltip | &TooltipCfg | Tooltip shown on hover |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_click | fn (&Layout, mut Event, mut Window) | Click or Enter key |
| on_hover | fn (&Layout, mut Event, mut Window) | Pointer enters bounds |

## Example

```v
gui.button(
    content:      [gui.text(text: "Submit")],
    alt_content:  [gui.text(text: "Sent!")],
    alt_duration: time.second,
    on_click:     fn (_ &gui.Layout, mut e gui.Event, mut _ gui.Window) {
        e.is_handled = true
    },
)
```'

fn demo_button(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Clicks: ${app.button_clicks}'
				text_style: gui.theme().n5
			),
			gui.column(
				sizing:  gui.fill_fit
				spacing: gui.spacing_small
				content: button_feature_rows(w, 9100)
			),
		]
	)
}

const input_doc = '# Input

Single-line, password, and multiline text input with optional mask and icon.
Supports formatter pipeline hooks for edit-time filtering and commit-time normalization.

## Usage

```v
gui.input(
    text:            state.value,
    placeholder:     "Enter text",
    pre_commit_transform: fn (_ string, proposed string) ?string {
        // reject invalid delta
        if proposed.contains("!") {
            return none
        }
        return proposed
    },
    post_commit_normalize: fn (text string, _ gui.InputCommitReason) string {
        // normalize on Enter/blur
        return text.trim_space()
    },
    on_text_changed: fn (_ &gui.Layout, val string, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.value = val
    },
    on_text_commit: fn (_ &gui.Layout, val string, reason gui.InputCommitReason, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.value = val
        println(reason)
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| text | string | Current input value |
| placeholder | string | Hint text when empty |
| mode | InputMode | .single_line, .multiline |
| is_password | bool | Mask characters |
| mask | string | Input mask pattern |
| icon | string | Trailing icon glyph |
| id_focus | u32 | Focus identifier for tab navigation |
| pre_commit_transform | fn (string, string) ?string | Filter or transform edit delta |
| post_commit_normalize | fn (string, InputCommitReason) string | Normalize committed text |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_text_changed | fn (&Layout, string, mut Window) | Text content changes |
| on_text_commit | fn (&Layout, string, InputCommitReason, mut Window) | Text committed on Enter/blur |
| on_enter | fn (&Layout, mut Event, mut Window) | Enter key pressed |
| on_key_down | fn (&Layout, mut Event, mut Window) | Any key pressed |
| on_blur | fn (&Layout, mut Window) | Input loses focus |
| on_click_icon | fn (&Layout, mut Event, mut Window) | Icon clicked |

## Commit Reasons

- `InputCommitReason.enter`
- `InputCommitReason.blur`'

fn demo_input(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Accessibility: supports IME composition, keyboard tab focus, and masked input.'
				text_style: gui.theme().b5
				mode:       .wrap
			),
			gui.text(
				text:       'Designed to work with VoiceOver and other screen-reader/assistive technologies.'
				text_style: gui.theme().b5
				mode:       .wrap
			),
			gui.row(
				v_align: .middle
				content: [
					gui.text(text: 'Text', min_width: 80),
					gui.input(
						id_focus:        9110
						width:           280
						sizing:          gui.fixed_fit
						text:            app.input_text
						placeholder:     'Single line input...'
						mode:            .single_line
						on_text_changed: text_changed
					),
				]
			),
			gui.row(
				v_align: .middle
				content: [
					gui.text(text: 'Password', min_width: 80),
					gui.input(
						id_focus:        9111
						width:           280
						sizing:          gui.fixed_fit
						text:            app.input_password
						placeholder:     'Enter password...'
						is_password:     true
						mode:            .single_line
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.input_password = s
						}
					),
				]
			),
			gui.row(
				v_align: .middle
				content: [
					gui.text(text: 'Phone', min_width: 80),
					gui.input(
						id_focus:        9112
						width:           280
						sizing:          gui.fixed_fit
						text:            app.input_phone
						mask_preset:     .phone_us
						placeholder:     '(555) 123-4567'
						mode:            .single_line
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.input_phone = s
						}
					),
				]
			),
			gui.row(
				v_align: .middle
				content: [
					gui.text(text: 'Expiry', min_width: 80),
					gui.input(
						id_focus:        9113
						width:           280
						sizing:          gui.fixed_fit
						text:            app.input_expiry
						mask_preset:     .expiry_mm_yy
						placeholder:     '12/28'
						mode:            .single_line
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.input_expiry = s
						}
					),
				]
			),
			gui.row(
				v_align: .middle
				content: [
					gui.text(text: 'Multiline', min_width: 80),
					gui.input(
						id_focus:        9114
						width:           360
						sizing:          gui.fixed_fit
						text:            app.input_multiline
						placeholder:     'Multiline input...'
						mode:            .multiline
						on_text_changed: fn (_ &gui.Layout, s string, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.input_multiline = s
						}
					),
				]
			),
		]
	)
}

const toggle_doc = '# Toggle

Checkbox-style and icon toggles with labels.

## Usage

```v
gui.toggle(
    label:    "Accept terms",
    select:   state.accepted,
    on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.accepted = !s.accepted
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| label | string | Text displayed next to toggle |
| select | bool | Current checked state |
| text_select | string | Icon/text shown when selected |
| text_unselect | string | Icon/text shown when unselected |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_click | fn (&Layout, mut Event, mut Window) | Toggle clicked (required) |'

fn demo_toggle(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.toggle(
				label:    'Toggle this option'
				select:   app.select_checkbox
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.select_checkbox = !app.select_checkbox
				}
			),
			gui.toggle(
				label:         'Icon toggle'
				select:        app.select_toggle
				text_select:   gui.icon_heart
				text_unselect: gui.icon_heart_o
				text_style:    gui.theme().icon2
				on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.select_toggle = !app.select_toggle
				}
			),
		]
	)
}

const switch_doc = '# Switch

On/off switch control with animated thumb.

## Usage

```v
gui.switch_(
    label:    "Dark mode",
    select:   state.dark_mode,
    on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.dark_mode = !s.dark_mode
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| label | string | Text next to the switch |
| select | bool | Current on/off state |
| width | f32 | Switch track width |
| height | f32 | Switch track height |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_click | fn (&Layout, mut Event, mut Window) | Switch toggled (required) |'

fn demo_switch(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.switch(
		label:    'Enable switch'
		select:   app.select_switch
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.select_switch = !app.select_switch
		}
	)
}

const radio_doc = '# Radio

Single radio control for selecting one option from a group.

## Usage

```v
gui.radio(
    label:    "Option A",
    select:   state.choice == "a",
    on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.choice = "a"
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| label | string | Text next to radio circle |
| select | bool | Whether this option is selected |
| size | f32 | Radio button diameter |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_click | fn (&Layout, mut Event, mut Window) | Radio clicked (required) |'

fn demo_radio(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.radio(
		label:    'Radio option'
		select:   app.select_radio
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.select_radio = !app.select_radio
		}
	)
}

const radio_group_doc = '# Radio Button Group

Mutually exclusive options arranged in a titled group.

## Usage

```v
gui.radio_button_group(
    value:     state.selected,
    options:   [
        gui.RadioOption{label: "Small", value: "s"},
        gui.RadioOption{label: "Medium", value: "m"},
        gui.RadioOption{label: "Large", value: "l"},
    ],
    on_select: fn (val string, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.selected = val
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| value | string | Currently selected option value |
| options | []RadioOption | Available choices |
| title | string | Group title text |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_select | fn (string, mut Window) | Option changed (required) |'

fn demo_radio_group(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	options := [
		gui.radio_option('New York', 'ny'),
		gui.radio_option('Chicago', 'chi'),
		gui.radio_option('Denver', 'den'),
	]
	return gui.row(
		content: [
			gui.radio_button_group_column(
				title:     'City (Vertical)'
				id_focus:  9103
				value:     app.select_city
				options:   options
				on_select: fn (value string, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.select_city = value
				}
			),
			gui.radio_button_group_row(
				title:     'City (Horizontal)'
				id_focus:  9104
				value:     app.select_city
				options:   options
				on_select: fn (value string, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.select_city = value
				}
			),
		]
	)
}

const select_doc = '# Select

Dropdown with optional multi-select.

## Usage

```v
gui.select(
    id:        "color_select",
    select:    [state.color],
    options:   ["Red", "Green", "Blue"],
    on_select: fn (vals []string, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.color = vals[0]
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| select | []string | Currently selected values |
| options | []string | Available choices |
| placeholder | string | Text when nothing selected |
| select_multiple | bool | Allow multiple selections |
| no_wrap | bool | Prevent text wrapping |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_select | fn ([]string, mut Event, mut Window) | Selection changed (required) |'

fn demo_select(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	multi_value := if app.selected_1.len > 0 { app.selected_1.join(', ') } else { 'none' }
	single_value := if app.selected_2.len > 0 { app.selected_2[0] } else { 'none' }
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Keyboard: Tab to focus, Space/Enter to open, arrows to move, Escape to close.'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.row(
				v_align: .top
				spacing: gui.theme().spacing_large
				content: [
					gui.column(
						spacing: gui.theme().spacing_small
						content: [
							gui.text(text: 'Multi-select', text_style: gui.theme().b5),
							w.select(
								id:              'catalog_select_multi'
								id_focus:        9120
								min_width:       280
								max_width:       280
								select:          app.selected_1
								placeholder:     'Pick one or more states'
								select_multiple: true
								options:         [
									'Alabama',
									'Alaska',
									'Arizona',
									'Arkansas',
									'California',
									'Colorado',
									'Florida',
									'New York',
									'Texas',
								]
								on_select:       fn (s []string, mut e gui.Event, mut w gui.Window) {
									mut app := w.state[ShowcaseApp]()
									app.selected_1 = s
									e.is_handled = true
								}
							),
							gui.text(
								text:       'Selected: ${multi_value}'
								text_style: gui.theme().n5
								mode:       .wrap
							),
						]
					),
					gui.column(
						spacing: gui.theme().spacing_small
						content: [
							gui.text(text: 'Single-select + groups', text_style: gui.theme().b5),
							w.select(
								id:          'catalog_select_single'
								id_focus:    9121
								min_width:   200
								max_width:   200
								select:      app.selected_2
								placeholder: 'Pick one city'
								options:     [
									'---West',
									'Los Angeles',
									'San Francisco',
									'Seattle',
									'---East',
									'Boston',
									'Miami',
									'New York',
								]
								on_select:   fn (s []string, mut e gui.Event, mut w gui.Window) {
									mut app := w.state[ShowcaseApp]()
									app.selected_2 = s
									e.is_handled = true
								}
							),
							gui.text(text: 'Selected: ${single_value}', text_style: gui.theme().n5),
						]
					),
				]
			),
		]
	)
}

const listbox_doc = '# List Box

Single and multi-select list with optional async data source.

## Usage

```v
gui.listbox(
    data: [
        gui.ListBoxOption{id: "1", label: "First"},
        gui.ListBoxOption{id: "2", label: "Second"},
    ],
    selected_ids: state.selected,
    on_select: fn (ids []string, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.selected = ids
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| data | []ListBoxOption | Static list items |
| data_source | ?ListBoxDataSource | Async data provider |
| selected_ids | []string | Currently selected item IDs |
| query | string | Filter/search text |
| multiple | bool | Allow multiple selections |
| loading | bool | Show loading indicator |
| reorderable | bool | Enable drag-to-reorder |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_select | fn ([]string, mut Event, mut Window) | Selection changed |
| on_reorder | fn (string, string, mut Window) | Item reordered (moved_id, before_id) |'

fn demo_list_box(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'List boxes support virtualization for large datasets.'
				text_style: gui.theme().n5
			),
			gui.text(
				text:       'Enable with id_scroll + bounded height/max_height.'
				text_style: gui.theme().n5
			),
			w.list_box(
				id_scroll:    id_scroll_list_box
				height:       180
				sizing:       gui.fill_fixed
				multiple:     app.list_box_multiple_select
				selected_ids: app.list_box_selected_ids
				data:         [
					gui.list_box_subheading('states-header', 'States'),
					gui.list_box_option('CA', 'California', 'CA'),
					gui.list_box_option('CO', 'Colorado', 'CO'),
					gui.list_box_option('FL', 'Florida', 'FL'),
					gui.list_box_option('NY', 'New York', 'NY'),
					gui.list_box_option('WA', 'Washington', 'WA'),
				]
				on_select:    fn (ids []string, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.list_box_selected_ids = ids
					e.is_handled = true
				}
			),
			gui.toggle(
				label:    'Multi-select'
				select:   app.list_box_multiple_select
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.list_box_multiple_select = !app.list_box_multiple_select
					app.list_box_selected_ids.clear()
				}
			),
		]
	)
}

const range_slider_doc = '# Range Slider

Drag horizontal or vertical value controls.

## Usage

```v
gui.range_slider(
    id:        "volume",
    value:     state.volume,
    min:       0,
    max:       100,
    on_change: fn (val f32, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.volume = val
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| value | f32 | Current position |
| min | f32 | Minimum value |
| max | f32 | Maximum value |
| step | f32 | Snap increment |
| vertical | bool | Vertical orientation |
| round_value | bool | Round to nearest step |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_change | fn (f32, mut Event, mut Window) | Value changed (required) |'

fn demo_range_slider(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.row(
		v_align: .middle
		spacing: gui.theme().spacing_large
		content: [
			gui.column(
				width:   220
				sizing:  gui.fit_fit
				padding: gui.padding_none
				content: [
					gui.range_slider(
						id:          'catalog_slider'
						value:       app.range_value
						round_value: true
						sizing:      gui.fill_fit
						on_change:   fn (value f32, mut _ gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.range_value = value
						}
					),
					gui.text(text: 'Value: ${int(app.range_value)}'),
				]
			),
			gui.column(
				height:  90
				sizing:  gui.fit_fixed
				h_align: .center
				padding: gui.padding_none
				content: [
					gui.range_slider(
						id:          'catalog_slider_vertical'
						value:       app.range_value
						round_value: true
						vertical:    true
						sizing:      gui.fit_fill
						on_change:   fn (value f32, mut _ gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.range_value = value
						}
					),
				]
			),
		]
	)
}

const progress_bar_doc = '# Progress Bar

Determinate and indeterminate progress indicators.

## Usage

```v
gui.progress_bar(percent: 0.65, text_show: true)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| percent | f32 | Progress 0.0 to 1.0 |
| indefinite | bool | Animated indeterminate mode |
| vertical | bool | Vertical orientation |
| text_show | bool | Show percentage label |
| text | string | Custom label text |
| color_bar | Color | Fill color |

## Example

```v
gui.progress_bar(
    indefinite: true,
    color_bar:  gui.Color{80, 160, 240, 255},
)
```'

fn demo_progress_bar(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	percent := app.range_value / f32(100)
	return gui.column(
		width:   250
		spacing: gui.theme().spacing_small
		content: [
			gui.progress_bar(
				sizing:  gui.fill_fit
				percent: percent
			),
			gui.progress_bar(
				sizing:     gui.fill_fit
				indefinite: true
			),
		]
	)
}

const pulsar_doc = '# Pulsar

Animated pulse indicator with optional icons.

## Usage

```v
gui.pulsar()

gui.pulsar(
    icon1: gui.icon_heart,
    icon2: gui.icon_star,
    size:  24,
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| icon1 | string | First alternating icon glyph |
| icon2 | string | Second alternating icon glyph |
| color | Color | Pulse color |
| size | u32 | Icon font size |
| width | f32 | Pulsar width |'

fn demo_pulsar(mut w gui.Window) gui.View {
	return gui.row(
		content: [
			w.pulsar(),
			w.pulsar(size: 20),
			w.pulsar(size: 28, color: gui.orange),
		]
	)
}

const toast_doc = '# Toast

Non-blocking notifications with severity, auto-dismiss, and action buttons.

## Usage

```v
w.toast(gui.ToastCfg{
    title:    "Saved",
    body:     "Document saved.",
    severity: .success,
})
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| title | string | Bold heading (optional) |
| body | string | Message text |
| severity | ToastSeverity | info, success, warning, error |
| duration | time.Duration | Auto-dismiss delay (0 = manual) |
| action_label | string | Optional action button text |
| on_action | fn (mut Window) | Action button callback |

## API

| Method | Description |
|--------|-------------|
| w.toast(cfg) | Show toast, returns id |
| w.toast_dismiss(id) | Dismiss specific toast |
| w.toast_dismiss_all() | Dismiss all toasts |'

fn demo_toast(mut w gui.Window) gui.View {
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.row(
				color:       gui.color_transparent
				size_border: 0
				spacing:     gui.theme().spacing_small
				content:     [
					gui.button(
						content:  [gui.text(text: 'Info')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast(gui.ToastCfg{
								title:    'Info'
								body:     'Informational message.'
								severity: .info
							})
						}
					),
					gui.button(
						content:  [gui.text(text: 'Success')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast(gui.ToastCfg{
								title:    'Saved'
								body:     'Document saved.'
								severity: .success
							})
						}
					),
					gui.button(
						content:  [gui.text(text: 'Warning')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast(gui.ToastCfg{
								title:    'Warning'
								body:     'Disk space running low.'
								severity: .warning
							})
						}
					),
					gui.button(
						content:  [gui.text(text: 'Error')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast(gui.ToastCfg{
								title:    'Error'
								body:     'Connection failed.'
								severity: .error
								duration: 5 * time.second
							})
						}
					),
				]
			),
			gui.row(
				color:       gui.color_transparent
				size_border: 0
				spacing:     gui.theme().spacing_small
				content:     [
					gui.button(
						content:  [gui.text(text: 'With Action')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast(gui.ToastCfg{
								title:        'Deleted'
								body:         'Item removed.'
								severity:     .info
								action_label: 'Undo'
								on_action:    fn (mut w gui.Window) {
									w.toast(gui.ToastCfg{
										title:    'Undone'
										body:     'Item restored.'
										severity: .success
									})
								}
							})
						}
					),
					gui.button(
						content:  [gui.text(text: 'Dismiss All')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.toast_dismiss_all()
						}
					),
				]
			),
			gui.text(
				text:       'Hover a toast to pause auto-dismiss.'
				text_style: gui.TextStyle{
					...gui.theme().n4
					color: gui.theme().color_active
				}
			),
		]
	)
}

const badge_doc = '# Badge

Numeric and colored pill labels for notification counts and status indicators.

## Usage

```v
gui.badge(label: "3", variant: .info)
gui.badge(label: "99+", variant: .error)
gui.badge(dot: true, variant: .success)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| label | string | Text to display |
| variant | BadgeVariant | default\\_, info, success, warning, error |
| max | int | Cap value; shows "max+" when exceeded (0=no cap) |
| dot | bool | Dot-only mode, no label |
| color | Color | Background color (default variant only) |

## Variants

| Variant | Use case |
|---------|----------|
| default\\_ | Custom color via `color` field |
| info | Informational counts |
| success | Positive status |
| warning | Needs attention |
| error | Critical counts |'

fn demo_badge() gui.View {
	return gui.column(
		spacing: gui.theme().spacing_medium
		content: [
			gui.text(text: 'Variants', text_style: gui.theme().b4),
			gui.row(
				color:       gui.color_transparent
				size_border: 0
				spacing:     gui.theme().spacing_small
				v_align:     .middle
				content:     [
					gui.badge(label: '5'),
					gui.badge(label: '3', variant: .info),
					gui.badge(label: '12', variant: .success),
					gui.badge(label: '7', variant: .warning),
					gui.badge(label: '99', variant: .error),
				]
			),
			gui.text(text: 'Max cap', text_style: gui.theme().b4),
			gui.row(
				color:       gui.color_transparent
				size_border: 0
				spacing:     gui.theme().spacing_small
				v_align:     .middle
				content:     [
					gui.badge(label: '5', max: 99),
					gui.badge(label: '150', max: 99, variant: .error),
					gui.badge(label: '1000', max: 999, variant: .info),
				]
			),
			gui.text(text: 'Dot mode', text_style: gui.theme().b4),
			gui.row(
				color:       gui.color_transparent
				size_border: 0
				spacing:     gui.theme().spacing_small
				v_align:     .middle
				content:     [
					gui.badge(dot: true),
					gui.badge(dot: true, variant: .info),
					gui.badge(dot: true, variant: .success),
					gui.badge(dot: true, variant: .warning),
					gui.badge(dot: true, variant: .error),
				]
			),
		]
	)
}

const menus_doc = '# Menus + Menubar

Nested menus with separators, submenus, and custom items.

## Usage

```v
gui.menubar(
    id_focus: 100,
    items: [
        gui.MenuItemCfg{id: "file", text: "File", submenu: [
            gui.MenuItemCfg{id: "new", text: "New"},
            gui.MenuItemCfg{separator: true},
            gui.MenuItemCfg{id: "quit", text: "Quit"},
        ]},
    ],
    action: fn (id string, mut _ gui.Event, mut w gui.Window) {
        match id {
            "new" { /* handle */ }
            else {}
        }
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id_focus | u32 | Focus id for keyboard nav (required) |
| items | []MenuItemCfg | Top-level menu items |
| width_submenu_min | f32 | Minimum submenu width |
| width_submenu_max | f32 | Maximum submenu width |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| action | fn (string, mut Event, mut Window) | Menu item activated |'

fn demo_menu(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			menu(mut w),
			gui.text(
				text: if app.selected_menu_id.len > 0 {
					'Selected: ${app.selected_menu_id}'
				} else {
					'Select a menu item'
				}
			),
		]
	)
}

const dialog_doc = '# Dialog

Message, confirm, prompt, and custom dialogs.

## Usage

```v
gui.dialog(
    title:       "Confirm",
    body:        "Delete this item?",
    dialog_type: .confirm,
    on_ok_yes:   fn (mut w gui.Window) { /* confirmed */ },
    on_cancel_no: fn (mut w gui.Window) { /* cancelled */ },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| title | string | Dialog title |
| body | string | Message body text |
| dialog_type | DialogType | .message, .confirm, .prompt, .custom |
| reply | string | Current prompt input value |
| custom_content | []View | Views for .custom type |
| min_width | f32 | Minimum dialog width |
| max_width | f32 | Maximum dialog width |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_ok_yes | fn (mut Window) | OK/Yes pressed |
| on_cancel_no | fn (mut Window) | Cancel/No pressed |
| on_reply | fn (string, mut Window) | Prompt submitted |

See also: docs/NATIVE_DIALOGS.md'

fn demo_dialog() gui.View {
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Dialog types and native file/folder dialogs'
				text_style: gui.theme().n5
			),
			gui.row(
				content: [
					gui.button(
						content:  [gui.text(text: 'Message')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.dialog(
								align_buttons: .end
								dialog_type:   .message
								title:         'Message'
								body:          '
Dialog body text.

Multi-line text supported.
Buttons can be left/center/right aligned.'.trim_indent()
							)
						}
					),
					gui.button(
						content:  [gui.text(text: 'Confirm')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.dialog(
								dialog_type:  .confirm
								title:        'Destroy all data?'
								body:         'Are you sure?'
								on_ok_yes:    fn (mut w gui.Window) {
									w.dialog(title: 'Clicked Yes')
								}
								on_cancel_no: fn (mut w gui.Window) {
									w.dialog(title: 'Clicked No')
								}
							)
						}
					),
					gui.button(
						content:  [gui.text(text: 'Prompt')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.dialog(
								dialog_type:  .prompt
								title:        'Monty Python Quiz'
								body:         'What is your quest?'
								on_reply:     fn (reply string, mut w gui.Window) {
									w.dialog(title: 'Replied', body: reply)
								}
								on_cancel_no: fn (mut w gui.Window) {
									w.dialog(title: 'Canceled')
								}
							)
						}
					),
					gui.button(
						content:  [gui.text(text: 'Custom')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.dialog(
								dialog_type:    .custom
								custom_content: [
									gui.column(
										h_align: .center
										v_align: .middle
										content: [
											gui.text(text: 'Custom Content'),
											gui.button(
												id_focus: gui.dialog_base_id_focus
												content:  [gui.text(text: 'Close')]
												on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
													w.dialog_dismiss()
												}
											),
										]
									),
								]
							)
						}
					),
				]
			),
			gui.row(
				content: [
					gui.button(
						content:  [
							gui.text(text: 'Native Open'),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.native_open_dialog(
								title:          'Open Files'
								allow_multiple: true
								filters:        [
									gui.NativeFileFilter{
										name:       'Images'
										extensions: [
											'png',
											'jpg',
											'jpeg',
										]
									},
									gui.NativeFileFilter{
										name:       'Docs'
										extensions: [
											'txt',
											'md',
										]
									},
								]
								on_done:        fn (result gui.NativeDialogResult, mut w gui.Window) {
									demo_dialog_show_native_result('native_open_dialog()',
										result, mut w)
								}
							)
						}
					),
					gui.button(
						content:  [
							gui.text(text: 'Native Save'),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.native_save_dialog(
								title:             'Save As'
								default_name:      'untitled'
								default_extension: 'txt'
								filters:           [
									gui.NativeFileFilter{
										name:       'Text'
										extensions: [
											'txt',
										]
									},
								]
								on_done:           fn (result gui.NativeDialogResult, mut w gui.Window) {
									demo_dialog_show_native_result('native_save_dialog()',
										result, mut w)
								}
							)
						}
					),
					gui.button(
						content:  [
							gui.text(text: 'Native Folder'),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.native_folder_dialog(
								title:                  'Choose Folder'
								can_create_directories: true
								on_done:                fn (result gui.NativeDialogResult, mut w gui.Window) {
									demo_dialog_show_native_result('native_folder_dialog()',
										result, mut w)
								}
							)
						}
					),
				]
			),
		]
	)
}

fn demo_dialog_show_native_result(kind string, result gui.NativeDialogResult, mut w gui.Window) {
	body := match result.status {
		.ok {
			if result.paths.len == 0 {
				'No paths returned.'
			} else {
				result.path_strings().join('\n')
			}
		}
		.cancel {
			'Canceled.'
		}
		.error {
			if result.error_code.len > 0 && result.error_message.len > 0 {
				'${result.error_code}: ${result.error_message}'
			} else if result.error_message.len > 0 {
				result.error_message
			} else {
				'Unknown error.'
			}
		}
	}
	w.dialog(title: kind, body: body)
}

const tree_doc = '# Tree View

Hierarchical expandable node display with virtualization and
lazy-loading support.

## Basic Usage

```v
w.tree(
    id:        "animals",
    on_select: on_select,
    nodes:     [
        gui.tree_node(text: "Mammals", icon: gui.icon_github_alt,
            nodes: [
                gui.tree_node(text: "Lion"),
                gui.tree_node(text: "Cat"),
            ]),
        gui.tree_node(text: "Birds", icon: gui.icon_twitter,
            nodes: [
                gui.tree_node(text: "Condor"),
                gui.tree_node(text: "Eagle"),
            ]),
    ],
)
```

## Virtualized Tree

Large trees are virtualized with flat-row rendering. Set `id_scroll`
and `max_height` to enable scrollable viewport.

```v
w.tree(
    id:         "big_tree",
    on_select:  on_select,
    id_scroll:  1,
    max_height: 200,
    nodes:      make_big_tree(),
)
```

## Lazy Loading

Nodes with `lazy: true` fire `on_lazy_load` when expanded and
`nodes.len == 0`. Deliver children asynchronously via
`queue_command`.

```v
w.tree(
    id:           "lazy_tree",
    on_select:    on_select,
    on_lazy_load: on_lazy_load,
    nodes:        [
        gui.TreeNodeCfg{
            id: "remote_a", text: "Remote folder A",
            icon: gui.icon_folder, lazy: true,
            nodes: remote_a_nodes,
        },
    ],
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| nodes | []TreeNodeCfg | Root-level tree nodes |
| indent | f32 | Indentation per nesting level |
| spacing | f32 | Vertical spacing between nodes |
| id_scroll | u32 | Scroll container ID (enables virtualization) |
| max_height | f32 | Max height before scrolling |
| height | f32 | Fixed height |
| reorderable | bool | Enable drag-to-reorder siblings |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_select | fn (string, mut Window) | Node selected |
| on_lazy_load | fn (string, string, mut Window) | Lazy node expanded (tree_id, node_id) |
| on_reorder | fn (string, string, string, mut Window) | Node reordered (moved_id, before_id, parent_id) |

## TreeNodeCfg

| Property | Type | Description |
|----------|------|-------------|
| id | string | Node identifier (defaults to text) |
| text | string | Display text |
| icon | string | Icon name (gui.icon_xxx) |
| nodes | []TreeNodeCfg | Child nodes |
| lazy | bool | Load children on demand |'

fn demo_tree(mut w gui.Window) gui.View {
	return tree_view_sample(mut w)
}

const drag_reorder_doc = '# Drag Reorder

Drag items to reorder within lists, tabs, and tree views. Keyboard shortcuts
provide an accessible alternative to mouse dragging.

## List Box

```v
w.list_box(
    id:          "items",
    reorderable: true,
    data:        app.items,
    on_reorder:  fn (moved_id string, before_id string, mut w gui.Window) {
        mut app := w.state[MyApp]()
        from, to := gui.reorder_indices(app.items.map(it.id), moved_id, before_id)
        if from >= 0 {
            item := app.items[from]
            app.items.delete(from)
            app.items.insert(to, item)
        }
    },
)
```

## Tab Control

```v
w.tab_control(
    id:          "tabs",
    reorderable: true,
    items:       app.tabs,
    on_reorder:  fn (moved_id string, before_id string, mut w gui.Window) {
        mut app := w.state[MyApp]()
        from, to := gui.reorder_indices(app.tabs.map(it.id), moved_id, before_id)
        if from >= 0 {
            tab := app.tabs[from]
            app.tabs.delete(from)
            app.tabs.insert(to, tab)
        }
    },
)
```

## Tree View

Tree reorder is scoped to siblings under the same parent. The callback
receives `parent_id` so you can locate the correct child list.

```v
w.tree(
    id:          "tree",
    reorderable: true,
    nodes:       app.nodes,
    on_reorder:  fn (moved_id string, before_id string, parent_id string, mut w gui.Window) {
        // Recursively find parent and reorder children
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| reorderable | bool | Enable drag-to-reorder |
| on_reorder | fn | Callback fired after drop (see signatures below) |

## Callback Signatures

| Widget | Signature |
|--------|-----------|
| ListBox | fn (moved_id string, before_id string, mut Window) |
| TabControl | fn (moved_id string, before_id string, mut Window) |
| Tree | fn (moved_id string, before_id string, parent_id string, mut Window) |

## Helper

`gui.reorder_indices(ids, moved_id, before_id)` returns `(from, to)` indices
for the array splice. Returns `(-1, -1)` if no move is needed.

## Keyboard

- **ListBox / Tree**: Alt+Up / Alt+Down
- **TabControl**: Alt+Left / Alt+Right
- **Escape**: Cancel active drag'

fn demo_drag_reorder(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Drag items to reorder, or use Alt+Arrow keys. Escape cancels.'
				text_style: gui.theme().n5
			),
			gui.row(
				sizing:  gui.fill_fit
				spacing: gui.theme().spacing_large
				content: [
					gui.column(
						sizing:  gui.fill_fit
						spacing: 4
						content: [
							gui.text(text: 'List Box', text_style: gui.theme().b3),
							w.list_box(
								id:           'dr_lb'
								id_focus:     9170
								min_width:    160
								max_height:   200
								selected_ids: app.drag_reorder_selected
								data:         app.drag_reorder_items
								reorderable:  true
								on_reorder:   fn (moved_id string, before_id string, mut w gui.Window) {
									mut a := w.state[ShowcaseApp]()
									from, to := gui.reorder_indices(a.drag_reorder_items.map(it.id),
										moved_id, before_id)
									if from >= 0 {
										item := a.drag_reorder_items[from]
										a.drag_reorder_items.delete(from)
										a.drag_reorder_items.insert(to, item)
									}
								}
								on_select:    fn (ids []string, mut e gui.Event, mut w gui.Window) {
									mut a := w.state[ShowcaseApp]()
									a.drag_reorder_selected = ids
								}
							),
						]
					),
					gui.column(
						sizing:  gui.fill_fit
						spacing: 4
						content: [
							gui.text(text: 'Tab Control', text_style: gui.theme().b3),
							w.tab_control(
								id:          'dr_tc'
								id_focus:    9171
								sizing:      gui.fill_fit
								items:       app.drag_reorder_tabs
								selected:    app.drag_reorder_tab_sel
								reorderable: true
								on_select:   fn (id string, mut _e gui.Event, mut w gui.Window) {
									w.state[ShowcaseApp]().drag_reorder_tab_sel = id
								}
								on_reorder:  fn (moved_id string, before_id string, mut w gui.Window) {
									mut a := w.state[ShowcaseApp]()
									from, to := gui.reorder_indices(a.drag_reorder_tabs.map(it.id),
										moved_id, before_id)
									if from >= 0 {
										tab := a.drag_reorder_tabs[from]
										a.drag_reorder_tabs.delete(from)
										a.drag_reorder_tabs.insert(to, tab)
									}
								}
							),
						]
					),
				]
			),
			gui.column(
				sizing:  gui.fill_fit
				spacing: 4
				content: [
					gui.text(text: 'Tree View', text_style: gui.theme().b3),
					w.tree(
						id:          'dr_tree'
						id_scroll:   id_scroll_drag_reorder_tree
						id_focus:    9175
						max_height:  200
						nodes:       app.drag_reorder_nodes
						reorderable: true
						on_select:   fn (_ string, mut _ gui.Window) {}
						on_reorder:  fn (moved_id string, before_id string, parent_id string, mut w gui.Window) {
							mut a := w.state[ShowcaseApp]()
							showcase_reorder_tree_nodes(mut a.drag_reorder_nodes, moved_id,
								before_id, parent_id)
						}
					),
				]
			),
		]
	)
}

fn showcase_reorder_tree_nodes(mut nodes []gui.TreeNodeCfg, moved_id string, before_id string, parent_id string) {
	if parent_id.len == 0 {
		from, to := gui.reorder_indices(nodes.map(it.id), moved_id, before_id)
		if from >= 0 {
			node := nodes[from]
			nodes.delete(from)
			nodes.insert(to, node)
		}
		return
	}
	for mut node in nodes {
		id := if node.id.len == 0 { node.text } else { node.id }
		if id == parent_id {
			from, to := gui.reorder_indices(node.nodes.map(it.id), moved_id, before_id)
			if from >= 0 {
				child := node.nodes[from]
				node.nodes.delete(from)
				node.nodes.insert(to, child)
			}
			return
		}
		showcase_reorder_tree_nodes(mut node.nodes, moved_id, before_id, parent_id)
	}
}

fn drag_reorder_demo_items() []gui.ListBoxOption {
	return [
		gui.list_box_option('apple', 'Apple', ''),
		gui.list_box_option('banana', 'Banana', ''),
		gui.list_box_option('cherry', 'Cherry', ''),
		gui.list_box_option('date', 'Date', ''),
		gui.list_box_option('elderberry', 'Elderberry', ''),
		gui.list_box_option('fig', 'Fig', ''),
	]
}

fn drag_reorder_demo_tabs() []gui.TabItemCfg {
	return [
		gui.tab_item('alpha', 'Alpha', [gui.text(text: 'Alpha content')]),
		gui.tab_item('beta', 'Beta', [gui.text(text: 'Beta content')]),
		gui.tab_item('gamma', 'Gamma', [gui.text(text: 'Gamma content')]),
		gui.tab_item('delta', 'Delta', [gui.text(text: 'Delta content')]),
	]
}

fn drag_reorder_demo_nodes() []gui.TreeNodeCfg {
	return [
		gui.TreeNodeCfg{
			id:    'src'
			text:  'src'
			nodes: [
				gui.TreeNodeCfg{
					id:   'main.v'
					text: 'main.v'
				},
				gui.TreeNodeCfg{
					id:   'util.v'
					text: 'util.v'
				},
				gui.TreeNodeCfg{
					id:   'app.v'
					text: 'app.v'
				},
			]
		},
		gui.TreeNodeCfg{
			id:    'docs'
			text:  'docs'
			nodes: [
				gui.TreeNodeCfg{
					id:   'readme'
					text: 'README.md'
				},
				gui.TreeNodeCfg{
					id:   'guide'
					text: 'GUIDE.md'
				},
			]
		},
		gui.TreeNodeCfg{
			id:   'tests'
			text: 'tests'
		},
		gui.TreeNodeCfg{
			id:   'build'
			text: 'build'
		},
	]
}

const printing_doc = '# Printing

Export current view to PDF and open native print dialog with `PrintJob`.

## Usage

```v
// Export to PDF
w.export_print_job(gui.PrintJob{
    output_path: "/tmp/output.pdf",
    paper:       .a4,
    source:      gui.PrintJobSource{kind: .current_view},
})

// Native print dialog
result := w.run_print_job(gui.PrintJob{
    title:  "Print Document",
    paper:  .letter,
    source: gui.PrintJobSource{kind: .current_view},
})
```

## Key Properties (PrintJob)

| Property | Type | Description |
|----------|------|-------------|
| output_path | string | Export output file path |
| paper | PaperSize | .letter, .legal, .a4, .a3 |
| orientation | PrintOrientation | .portrait, .landscape |
| margins | PrintMargins | Page margins in points |
| paginate | bool | Enable multi-page vertical tiling |
| scale_mode | PrintScaleMode | .fit_to_page or .actual_size |
| source | PrintJobSource | .current_view or .pdf_path |

See also: docs/PRINTING.md'

fn demo_printing(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	last_path := if app.printing_last_path.len > 0 {
		app.printing_last_path
	} else {
		'(none)'
	}
	status := if app.printing_status.len > 0 {
		app.printing_status
	} else {
		'No print action yet.'
	}
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Export this view to PDF, print the current view, or print the exported file.'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.row(
				spacing: gui.theme().spacing_small
				content: [
					gui.button(
						content:  [gui.text(text: 'Export PDF')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							path := os.join_path(os.temp_dir(), 'v_gui_showcase_print_${time.now().unix_micro()}.pdf')
							result := w.export_print_job(gui.PrintJob{
								output_path: path
								source:      gui.PrintJobSource{
									kind: .current_view
								}
							})
							mut app := w.state[ShowcaseApp]()
							if result.is_ok() {
								app.printing_last_path = result.path
								app.printing_status = 'Exported: ${result.path}'
							} else {
								app.printing_status = 'Export failed: ${result.error_code}: ${result.error_message}'
							}
						}
					),
					gui.button(
						content:  [gui.text(text: 'Print Current View')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							result := w.run_print_job(gui.PrintJob{
								title:  'Showcase Print Current View'
								source: gui.PrintJobSource{
									kind: .current_view
								}
							})
							mut app := w.state[ShowcaseApp]()
							match result.status {
								.ok {
									app.printing_last_path = result.pdf_path
									app.printing_status = 'Printed: ${result.pdf_path}'
								}
								.cancel {
									app.printing_status = 'Print canceled.'
								}
								.error {
									app.printing_status = 'Print failed: ${result.error_code}: ${result.error_message}'
								}
							}
						}
					),
					gui.button(
						content:  [gui.text(text: 'Print Exported PDF')]
						disabled: app.printing_last_path.len == 0
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							path := w.state[ShowcaseApp]().printing_last_path
							if path.len == 0 {
								return
							}
							result := w.run_print_job(gui.PrintJob{
								title:  'Showcase Print Existing PDF'
								source: gui.PrintJobSource{
									kind:     .pdf_path
									pdf_path: path
								}
							})
							mut app := w.state[ShowcaseApp]()
							match result.status {
								.ok {
									app.printing_status = 'Printed: ${result.pdf_path}'
								}
								.cancel {
									app.printing_status = 'Print canceled.'
								}
								.error {
									app.printing_status = 'Print failed: ${result.error_code}: ${result.error_message}'
								}
							}
						}
					),
				]
			),
			gui.text(
				text:       'Last exported path: ${last_path}'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.text(text: 'Last result: ${status}', text_style: gui.theme().n5, mode: .wrap),
			gui.column(
				color:        gui.theme().color_panel
				color_border: gui.theme().color_border
				size_border:  1
				padding:      gui.padding_small
				spacing:      gui.theme().spacing_small
				content:      [
					gui.text(text: 'Preview content exported to PDF', text_style: gui.theme().b5),
					gui.text(
						text:       'Shapes, text, and layout in this panel are included in exported output.'
						text_style: gui.theme().n5
						mode:       .wrap
					),
					gui.row(
						spacing: gui.theme().spacing_small
						content: [
							gui.rectangle(
								width:  80
								height: 40
								color:  gui.cornflower_blue
								radius: 4
							),
							gui.rectangle(
								width:        80
								height:       40
								color:        gui.color_transparent
								color_border: gui.theme().color_active
								size_border:  2
								radius:       4
							),
						]
					),
				]
			),
		]
	)
}

const text_doc = '# Text

Theme typography sizes, weights, and styles.

## Usage

```v
gui.text(text: "Hello, world")

gui.text(
    text:       "Styled heading",
    text_style: gui.theme().h1,
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| text | string | Display text content |
| text_style | TextStyle | Font, size, color, weight |
| mode | TextMode | .single_line, .wrap, .ellipsis |
| is_password | bool | Mask characters |
| tab_size | u32 | Tab stop width |
| hero | bool | Enable hero transition matching |
| opacity | f32 | Render opacity (0.0–1.0) |'

fn demo_text() gui.View {
	wrap_sample := 'Wrap mode collapses repeated spaces and wraps words to fit the available width.'
	keep_spaces_sample := 'wrap_keep_spaces keeps    repeated spaces.\nColumns:\nName\tRole\nAlex\tDesigner\nRiley\tEngineer'
	emoji_sample := 'Emoji: 😀 🚀 🎉 👍🏽 👩‍💻 🧑‍🚀'
	grapheme_sample := 'Multi-grapheme: 👨‍👩‍👧‍👦  🇺🇸  1️⃣  café'
	i18n_sample := 'i18n: English | Español | العربية | हिन्दी | 日本語 | 한국어 | עברית | ไทย'
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Text supports style variants, alignment, wrapping modes, tabs, and selection/copy.'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.row(
				v_align: .middle
				content: [
					gui.text(text: 'Theme n3 text', text_style: gui.theme().n3),
					gui.text(text: 'Theme b3 text', text_style: gui.theme().b3),
					gui.text(text: 'Theme i3 text', text_style: gui.theme().i3),
					gui.text(text: 'Theme m3 text', text_style: gui.theme().m3),
				]
			),
			gui.row(
				v_align: .middle
				content: [
					gui.text(
						text:       'Underlined'
						text_style: gui.TextStyle{
							...gui.theme().n4
							underline: true
						}
					),
					gui.text(
						text:       'Strikethrough'
						text_style: gui.TextStyle{
							...gui.theme().n4
							strikethrough: true
						}
					),
					gui.text(
						text:       'Background color'
						text_style: gui.TextStyle{
							...gui.theme().n4
							color:    gui.white
							bg_color: gui.dark_blue
						}
					),
				]
			),
			gui.column(
				sizing:       gui.fill_fit
				color:        gui.theme().color_panel
				color_border: gui.theme().color_border
				size_border:  1
				padding:      gui.padding_small
				spacing:      gui.theme().spacing_small
				content:      [
					gui.text(text: 'Emoji, Multi-grapheme, and i18n', text_style: gui.theme().b5),
					gui.text(text: emoji_sample, mode: .wrap, text_style: gui.theme().n4),
					gui.text(text: grapheme_sample, mode: .wrap, text_style: gui.theme().n4),
					gui.text(text: i18n_sample, mode: .wrap, text_style: gui.theme().n4),
					gui.text(
						text:       'RTL sample: العربية עברית'
						mode:       .wrap
						text_style: gui.TextStyle{
							...gui.theme().n4
							align: .right
						}
					),
				]
			),
			gui.row(
				spacing: gui.theme().spacing_small
				v_align: .top
				content: [
					gui.column(
						width:        260
						sizing:       gui.fixed_fit
						color:        gui.theme().color_panel
						color_border: gui.theme().color_border
						size_border:  1
						padding:      gui.padding_small
						spacing:      gui.theme().spacing_small
						content:      [
							gui.text(text: 'mode: .wrap + alignment', text_style: gui.theme().b5),
							gui.text(
								text:       wrap_sample
								mode:       .wrap
								text_style: gui.TextStyle{
									...gui.theme().n5
									align: .left
								}
							),
							gui.text(
								text:       'Center aligned text'
								mode:       .wrap
								text_style: gui.TextStyle{
									...gui.theme().n5
									align: .center
								}
							),
							gui.text(
								text:       'Right aligned text'
								mode:       .wrap
								text_style: gui.TextStyle{
									...gui.theme().n5
									align: .right
								}
							),
						]
					),
					gui.column(
						width:        260
						sizing:       gui.fixed_fit
						color:        gui.theme().color_panel
						color_border: gui.theme().color_border
						size_border:  1
						padding:      gui.padding_small
						spacing:      gui.theme().spacing_small
						content:      [
							gui.text(text: 'mode: .wrap_keep_spaces', text_style: gui.theme().b5),
							gui.text(
								text:       keep_spaces_sample
								mode:       .wrap_keep_spaces
								tab_size:   8
								text_style: gui.theme().m5
							),
						]
					),
				]
			),
			gui.column(
				sizing:       gui.fill_fit
				color:        gui.theme().color_panel
				color_border: gui.theme().color_border
				size_border:  1
				padding:      gui.padding_small
				spacing:      gui.theme().spacing_small
				content:      [
					gui.text(
						text:       'Focus/select/copy: click inside block, drag selection, then Cmd/Ctrl+C.'
						text_style: gui.theme().n5
						mode:       .wrap
					),
					gui.text(
						id_focus:   9155
						focus_skip: false
						mode:       .multiline
						text:       'Selectable text block\n- Click to focus\n- Drag to select range\n- Copy with Cmd/Ctrl+C'
						text_style: gui.TextStyle{
							...gui.theme().n4
							bg_color: gui.theme().color_panel
						}
					),
				]
			),
			gui.column(
				sizing:       gui.fill_fit
				color:        gui.theme().color_panel
				color_border: gui.theme().color_border
				size_border:  1
				padding:      gui.padding_small
				spacing:      gui.theme().spacing_small
				content:      [
					gui.text(text: 'Transforms', text_style: gui.theme().b5),
					gui.row(
						sizing:  gui.fill_fixed
						height:  gui.theme().b4.size * 4
						v_align: .top
						content: [
							gui.text(
								text:       'Rotated text via TextStyle.rotation_radians'
								text_style: gui.TextStyle{
									...gui.theme().b4
									rotation_radians: 0.35
								}
							),
						]
					),
					gui.row(
						sizing:  gui.fill_fixed
						height:  gui.theme().b4.size * 4
						v_align: .top
						content: [
							gui.text(
								text:       'Affine text: skew + translate'
								text_style: gui.TextStyle{
									...gui.theme().b4
									affine_transform: vglyph.AffineTransform{
										xx: 1.0
										xy: -0.35
										yx: 0.15
										yy: 1.0
										x0: 24
										y0: 0
									}
								}
							),
						]
					),
				]
			),
			gui.column(
				sizing:       gui.fill_fit
				color:        gui.theme().color_panel
				color_border: gui.theme().color_border
				size_border:  1
				padding:      gui.padding_small
				spacing:      gui.theme().spacing_small
				content:      [
					gui.text(text: 'Gradient Text', text_style: gui.theme().b5),
					gui.text(
						text:       'Horizontal Rainbow Gradient'
						mode:       .wrap
						text_style: gui.TextStyle{
							...gui.theme().b2
							gradient: &vglyph.GradientConfig{
								stops: [
									vglyph.GradientStop{
										color:    gg.Color{255, 0, 0, 255}
										position: 0.0
									},
									vglyph.GradientStop{
										color:    gg.Color{255, 200, 0, 255}
										position: 0.33
									},
									vglyph.GradientStop{
										color:    gg.Color{0, 180, 255, 255}
										position: 0.66
									},
									vglyph.GradientStop{
										color:    gg.Color{180, 0, 255, 255}
										position: 1.0
									},
								]
							}
						}
					),
					gui.text(
						text:       'Vertical Sunset Gradient'
						mode:       .wrap
						text_style: gui.TextStyle{
							...gui.theme().b2
							gradient: &vglyph.GradientConfig{
								stops:     [
									vglyph.GradientStop{
										color:    gg.Color{255, 100, 100, 255}
										position: 0.0
									},
									vglyph.GradientStop{
										color:    gg.Color{255, 200, 80, 255}
										position: 0.5
									},
									vglyph.GradientStop{
										color:    gg.Color{180, 80, 200, 255}
										position: 1.0
									},
								]
								direction: .vertical
							}
						}
					),
				]
			),
			gui.column(
				sizing:       gui.fill_fit
				color:        gui.theme().color_panel
				color_border: gui.theme().color_border
				size_border:  1
				padding:      gui.padding_small
				spacing:      gui.theme().spacing_small
				content:      [
					gui.text(
						text:       'Outlined & Hollow Text'
						text_style: gui.theme().b5
					),
					gui.text(
						text:       'Outlined text (fill + stroke)'
						mode:       .wrap
						text_style: gui.TextStyle{
							...gui.theme().b2
							stroke_width: 1.5
							stroke_color: gui.red
						}
					),
					gui.text(
						text:       'Hollow text (stroke only)'
						mode:       .wrap
						text_style: gui.TextStyle{
							...gui.theme().b2
							color:        gui.color_transparent
							stroke_width: 1.5
							stroke_color: gui.theme().text_style.color
						}
					),
				]
			),
			gui.column(
				sizing:       gui.fill_fit
				color:        gui.theme().color_panel
				color_border: gui.theme().color_border
				size_border:  1
				padding:      gui.padding_small
				spacing:      gui.theme().spacing_small
				content:      [
					gui.text(text: 'Curved Text (SVG textPath)', text_style: gui.theme().b5),
					gui.svg(
						svg_data: '<svg viewBox="0 0 500 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <path id="curve" d="M20,80 Q250,10 480,80" fill="none"/>
  </defs>
  <text font-size="18" fill="#3399cc" font-weight="600">
    <textPath href="#curve" startOffset="50%" text-anchor="middle">Text flowing along a curved path</textPath>
  </text>
</svg>'
						width:    500
						height:   100
					),
				]
			),
		]
	)
}

const rtf_doc = '# Rich Text Format

Mixed styles, links, and inline rich text runs.
Right-click a link to open a context menu (copy, open, inspect URL).

## Usage

```v
gui.rtf(
    rich_text: gui.RichText{
        segments: [
            gui.RichSegment{text: "Bold ", style: gui.theme().b1},
            gui.RichSegment{text: "and normal"},
        ],
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| rich_text | RichText | Styled text segments |
| mode | TextMode | .single_line, .wrap |
| hanging_indent | f32 | Indent for wrapped lines |'

fn demo_rtf() gui.View {
	return gui.rtf(
		mode:      .wrap
		rich_text: gui.RichText{
			runs: [
				gui.rich_run('RTF supports ', gui.theme().n3),
				gui.rich_run('bold', gui.theme().b3),
				gui.rich_run(', ', gui.theme().n3),
				gui.rich_run('italic', gui.theme().i3),
				gui.rich_run(', and ', gui.theme().n3),
				gui.rich_link('links', 'https://github.com/mike-ward/gui', gui.theme().n3),
			]
		}
	)
}

fn showcase_data_grid_columns() []gui.GridColumnCfg {
	return [
		gui.GridColumnCfg{
			id:    'name'
			title: 'Name'
			width: 180
		},
		gui.GridColumnCfg{
			id:    'team'
			title: 'Team'
			width: 140
		},
		gui.GridColumnCfg{
			id:    'status'
			title: 'Status'
			width: 120
		},
	]
}

fn showcase_data_grid_rows() []gui.GridRow {
	return [
		gui.GridRow{
			id:    '1'
			cells: {
				'name':   'Alex'
				'team':   'Core'
				'status': 'Active'
			}
		},
		gui.GridRow{
			id:    '2'
			cells: {
				'name':   'Mina'
				'team':   'Data'
				'status': 'Active'
			}
		},
		gui.GridRow{
			id:    '3'
			cells: {
				'name':   'Noah'
				'team':   'Platform'
				'status': 'Paused'
			}
		},
		gui.GridRow{
			id:    '4'
			cells: {
				'name':   'Priya'
				'team':   'Core'
				'status': 'Active'
			}
		},
		gui.GridRow{
			id:    '5'
			cells: {
				'name':   'Sam'
				'team':   'Security'
				'status': 'Offline'
			}
		},
	]
}

fn showcase_data_grid_apply_query(rows []gui.GridRow, query gui.GridQueryState) []gui.GridRow {
	mut filtered := rows.filter(showcase_data_grid_row_matches_query(it, query))
	for sort_idx in 0 .. query.sorts.len {
		i := query.sorts.len - 1 - sort_idx
		sort := query.sorts[i]
		filtered.sort_with_compare(fn [sort] (a &gui.GridRow, b &gui.GridRow) int {
			a_val := a.cells[sort.col_id] or { '' }
			b_val := b.cells[sort.col_id] or { '' }
			if a_val == b_val {
				return 0
			}
			if sort.dir == .asc {
				return if a_val < b_val { -1 } else { 1 }
			}
			return if a_val > b_val { -1 } else { 1 }
		})
	}
	return filtered
}

fn showcase_data_grid_row_matches_query(row gui.GridRow, query gui.GridQueryState) bool {
	if query.quick_filter.len > 0 {
		needle := query.quick_filter.to_lower()
		mut any := false
		for _, value in row.cells {
			if value.to_lower().contains(needle) {
				any = true
				break
			}
		}
		if !any {
			return false
		}
	}
	for filter in query.filters {
		cell := row.cells[filter.col_id] or { '' }
		if !cell.to_lower().contains(filter.value.to_lower()) {
			return false
		}
	}
	return true
}

fn showcase_table_rows() [][]string {
	return [
		['Name', 'Role', 'Team', 'City'],
		['Alex', 'Designer', 'Foundations', 'Austin'],
		['Riley', 'Engineer', 'Core UI', 'Seattle'],
		['Jordan', 'PM', 'Platform', 'New York'],
		['Sam', 'QA', 'Core UI', 'Denver'],
		['Priya', 'Engineer', 'Platform', 'Chicago'],
		['Noah', 'Designer', 'Growth', 'Boston'],
		['Mina', 'Engineer', 'Foundations', 'San Diego'],
		['Omar', 'PM', 'Growth', 'Atlanta'],
	]
}

fn showcase_table_rows_sorted(sort_by int) [][]string {
	mut rows := showcase_table_rows().clone()
	if sort_by == 0 || rows.len <= 2 {
		return rows
	}
	is_ascending := sort_by > 0
	idx := math.abs(sort_by) - 1
	head := rows[0]
	mut body := rows[1..].clone()
	body.sort_with_compare(fn [is_ascending, idx] (mut a []string, mut b []string) int {
		if idx >= a.len || idx >= b.len {
			return 0
		}
		a_value := a[idx].to_lower()
		b_value := b[idx].to_lower()
		return match true {
			a_value < b_value && is_ascending { -1 }
			a_value > b_value && is_ascending { 1 }
			a_value < b_value && !is_ascending { 1 }
			a_value > b_value && !is_ascending { -1 }
			else { 0 }
		}
	})
	mut sorted := [][]string{cap: rows.len}
	sorted << head
	for row in body {
		sorted << row
	}
	return sorted
}

fn table_border_style_from_value(value string) gui.TableBorderStyle {
	return match value {
		'horizontal' { .horizontal }
		'header_only' { .header_only }
		'none' { .none }
		else { .all }
	}
}

const table_doc = '# Table

Declarative and sortable table data with row selection.

## Usage

```v
gui.table(
    data: [
        gui.TableRowCfg{cells: ["Name", "Age"]},
        gui.TableRowCfg{cells: ["Alice", "30"]},
        gui.TableRowCfg{cells: ["Bob", "25"]},
    ],
    column_width_default: 120,
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| data | []TableRowCfg | Row data (first row is header) |
| column_width_default | f32 | Default column width |
| column_alignments | []HorizontalAlign | Per-column alignment |
| selected | map[int]bool | Selected row indices |
| multi_select | bool | Allow multiple row selection |
| border_style | TableBorderStyle | Border rendering mode |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_select | fn (map[int]bool, int, mut Event, mut Window) | Row selection changed |

See also: docs/TABLES.md'

fn demo_table(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	mut table_cfg := gui.table_cfg_from_data(showcase_table_rows_sorted(app.table_sort_by))
	table_cfg = gui.TableCfg{
		...table_cfg
		id:                 'catalog_table'
		size_border:        1
		size_border_header: 2
		border_style:       table_border_style_from_value(app.table_border_style)
		color_border:       gui.gray
		text_style_head:    gui.theme().b4
	}
	mut head_cells := []gui.TableCellCfg{}
	for idx, cell in table_cfg.data[0].cells {
		col := idx + 1
		head_cells << gui.TableCellCfg{
			...cell
			value:    match true {
				app.table_sort_by == col { '${cell.value}  ↓' }
				app.table_sort_by == -col { '${cell.value} ↑' }
				else { cell.value }
			}
			on_click: fn [col] (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
				mut app := w.state[ShowcaseApp]()
				app.table_sort_by = match true {
					app.table_sort_by == col { -col }
					app.table_sort_by == -col { 0 }
					else { col }
				}
				e.is_handled = true
			}
		}
	}
	table_cfg.data.delete(0)
	table_cfg.data.insert(0, gui.tr(head_cells))
	border_options := [
		gui.radio_option('All', 'all'),
		gui.radio_option('Horizontal', 'horizontal'),
		gui.radio_option('Header only', 'header_only'),
		gui.radio_option('None', 'none'),
	]
	return gui.column(
		spacing: gui.theme().spacing_medium
		content: [
			gui.radio_button_group_row(
				title:     'Border style'
				id_focus:  9108
				padding:   gui.padding(2, 4, 2, 4)
				value:     app.table_border_style
				options:   border_options
				on_select: fn (value string, mut w gui.Window) {
					w.state[ShowcaseApp]().table_border_style = value
				}
			),
			gui.text(text: 'Click a column header to sort.', text_style: gui.theme().n5),
			w.table(table_cfg),
		]
	)
}

const data_grid_doc = '# Data Grid

Controlled virtualized grid for interactive tabular data. Supports sorting,
filtering, grouping, inline editing, and export.

## Usage

```v
gui.data_grid(
    id:      "grid1",
    columns: [
        gui.GridColumnCfg{id: "name", title: "Name", sortable: true},
        gui.GridColumnCfg{id: "age", title: "Age", width: 80},
    ],
    rows: [
        gui.GridRow{id: "1", cells: {"name": "Alice", "age": "30"}},
        gui.GridRow{id: "2", cells: {"name": "Bob", "age": "25"}},
    ],
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Grid identifier (required) |
| columns | []GridColumnCfg | Column definitions (required) |
| rows | []GridRow | Direct row data |
| data_source | &DataGridDataSource | Async data provider |
| group_by | []string | Column IDs to group by |
| query | GridQueryState | Sort, filter, and page state |
| selection | GridSelection | Current row selection state |

See also: docs/DATA_GRID.md'

fn demo_data_grid(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	rows := showcase_data_grid_apply_query(showcase_data_grid_rows(), app.data_grid_query)
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Simple controlled grid. Sort, filter, and select rows.'
				text_style: gui.theme().n5
			),
			gui.text(
				text:       'Rows: ${rows.len}  Selected: ${app.data_grid_selection.selected_row_ids.len}'
				text_style: gui.theme().n5
			),
			w.data_grid(
				id:                  'catalog_data_grid'
				id_focus:            9162
				sizing:              gui.fit_fit
				columns:             showcase_data_grid_columns()
				rows:                rows
				query:               app.data_grid_query
				selection:           app.data_grid_selection
				scrollbar:           .hidden
				max_height:          260
				on_query_change:     fn (query gui.GridQueryState, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.data_grid_query = query
				}
				on_selection_change: fn (selection gui.GridSelection, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.data_grid_selection = selection
				}
			),
			w.markdown(
				id:      'catalog_data_grid_features'
				source:  showcase_data_grid_features_source
				mode:    .wrap
				padding: gui.padding_none
			),
		]
	)
}

const data_source_doc = '# Data Source

Async data-source backed grid with CRUD operations.

## Usage

```v
source := gui.InMemoryDataSource{
    rows: my_rows,
}

gui.data_grid(
    id:          "ds_grid",
    columns:     my_columns,
    data_source: &source,
)
```

## DataGridDataSource Interface

| Method | Signature | Description |
|--------|-----------|-------------|
| capabilities | fn () GridDataCapabilities | Pagination and CRUD support |
| fetch_data | fn (GridDataRequest) !GridDataResult | Load rows for page |
| mutate_data | fn (GridMutationRequest) !GridMutationResult | Create/update/delete |

## InMemoryDataSource

| Property | Type | Description |
|----------|------|-------------|
| rows | []GridRow | In-memory row data |
| default_limit | int | Page size (default: 100) |
| latency_ms | int | Simulated latency for testing |
| supports_cursor | bool | Cursor pagination (default: true) |
| supports_offset | bool | Offset pagination (default: true) |

See also: docs/DATA_GRID.md'

fn demo_data_source(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	if app.data_source == none {
		rows := showcase_data_source_rows()
		app.data_source = &gui.InMemoryDataSource{
			rows:          rows
			default_limit: 50
			latency_ms:    140
		}
	}
	stats := w.data_grid_source_stats('catalog_data_source')
	loading := if stats.loading { 'yes' } else { 'no' }
	count_text := if count := stats.row_count {
		count.str()
	} else {
		'?'
	}
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'loading=${loading}  req=${stats.request_count}  rows=${stats.received_count}/${count_text}'
				text_style: gui.theme().n5
			),
			w.data_grid(
				id:                  'catalog_data_source'
				id_focus:            9175
				sizing:              gui.fit_fit
				columns:             showcase_data_grid_columns()
				data_source:         app.data_source
				pagination_kind:     .cursor
				page_limit:          50
				show_quick_filter:   true
				show_crud_toolbar:   true
				query:               app.data_source_query
				selection:           app.data_source_selection
				max_height:          260
				on_query_change:     fn (query gui.GridQueryState, mut _ gui.Event, mut w gui.Window) {
					mut a := w.state[ShowcaseApp]()
					a.data_source_query = query
				}
				on_selection_change: fn (selection gui.GridSelection, mut _ gui.Event, mut w gui.Window) {
					mut a := w.state[ShowcaseApp]()
					a.data_source_selection = selection
				}
			),
			gui.column(
				padding: gui.padding(gui.theme().spacing_large, 0, 0, 0)
				content: [
					gui.text(
						text:       '- DataGridDataSource interface for async backends'
						text_style: gui.theme().n5
					),
					gui.text(
						text:       '- InMemoryDataSource \u2014 cursor and/or offset pagination'
						text_style: gui.theme().n5
					),
					gui.text(
						text:       '- GridOrmDataSource \u2014 ORM-style with typed callbacks'
						text_style: gui.theme().n5
					),
					gui.text(
						text:       '- Async fetch with abort/cancellation signals'
						text_style: gui.theme().n5
					),
					gui.text(
						text:       '- Stale response detection and request dedup'
						text_style: gui.theme().n5
					),
					gui.text(
						text:       '- CRUD mutations (create, update, delete, batch delete)'
						text_style: gui.theme().n5
					),
					gui.text(
						text:       '- Capability discovery (pagination, mutations, row count)'
						text_style: gui.theme().n5
					),
					gui.text(
						text:       '- Simulated latency for testing loading states'
						text_style: gui.theme().n5
					),
				]
			),
		]
	)
}

fn showcase_data_source_rows() []gui.GridRow {
	names := ['Ada', 'Grace', 'Alan', 'Katherine', 'Barbara', 'Linus', 'Margaret', 'Edsger']
	teams := ['Core', 'Data', 'Platform', 'R&D', 'Web', 'Security']
	statuses := ['Open', 'Paused', 'Closed']
	mut rows := []gui.GridRow{cap: 200}
	for i in 0 .. 200 {
		id := i + 1
		rows << gui.GridRow{
			id:    '${id}'
			cells: {
				'name':   '${names[i % names.len]} ${id}'
				'team':   teams[(i / 30) % teams.len]
				'status': statuses[i % statuses.len]
			}
		}
	}
	return rows
}

const date_picker_doc = '# Date Picker

Select one or many dates from a calendar view.

## Usage

```v
gui.date_picker(
    id:    "cal",
    dates: [state.selected_date],
    on_select: fn (dates []time.Time, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.selected_date = dates[0]
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| dates | []time.Time | Selected dates (required) |
| select_multiple | bool | Allow multiple date selection |
| allowed_weekdays | []DatePickerWeekdays | Restrict to specific days |
| allowed_months | []DatePickerMonths | Restrict to specific months |
| allowed_years | []int | Restrict to specific years |
| monday_first_day_of_week | bool | Start week on Monday |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_select | fn ([]time.Time, mut Event, mut Window) | Date selected |'

fn demo_date_picker(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return w.date_picker(
		id:        'catalog_date_picker'
		dates:     app.date_picker_dates
		on_select: fn (dates []time.Time, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.date_picker_dates = dates
			e.is_handled = true
		}
	)
}

const input_date_doc = '# Input Date

Text input with date picker dropdown.

## Usage

```v
gui.input_date(
    id:   "birthday",
    date: state.date,
    on_select: fn (dates []time.Time, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.date = dates[0]
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| date | time.Time | Currently selected date |
| placeholder | string | Hint text when empty |
| select_multiple | bool | Allow multiple dates |
| allowed_weekdays | []DatePickerWeekdays | Restrict to specific days |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_select | fn ([]time.Time, mut Event, mut Window) | Date picked |
| on_enter | fn (&Layout, mut Event, mut Window) | Enter key pressed |'

fn demo_input_date(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return w.input_date(
		id:        'catalog_input_date'
		id_focus:  9104
		date:      app.input_date
		on_select: fn (dates []time.Time, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			if dates.len > 0 {
				app.input_date = dates[0]
			}
			e.is_handled = true
		}
	)
}

const date_picker_roller_doc = '# Date Picker Roller

Roll wheel-style month/day/year controls.

## Usage

```v
gui.date_picker_roller(
    id:            "roller",
    selected_date: state.date,
    on_change: fn (date time.Time, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.date = date
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| selected_date | time.Time | Current date (required) |
| display_mode | DatePickerRollerDisplayMode | Which rollers to show |
| min_year | int | Earliest year in roller |
| max_year | int | Latest year in roller |
| visible_items | int | Visible roller items |
| long_months | bool | Full month names |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_change | fn (time.Time, mut Window) | Date changed via roller |'

fn demo_date_picker_roller(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.date_picker_roller(
		id:            'catalog_date_picker_roller'
		id_focus:      9105
		selected_date: app.roller_date
		display_mode:  .month_day_year
		on_change:     fn (d time.Time, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.roller_date = d
		}
	)
}

const svg_doc = '# SVG

Render vector graphics from file or inline SVG data.

## Usage

```v
gui.svg(file_name: "icon.svg", width: 48, height: 48)

gui.svg(svg_data: "<svg>...</svg>", width: 100, height: 100)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| file_name | string | Path to SVG file |
| svg_data | string | Inline SVG markup |
| width | f32 | Display width |
| height | f32 | Display height |
| color | Color | Tint color |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_click | fn (&Layout, mut Event, mut Window) | SVG area clicked |

See also: docs/SVG.md'

fn demo_svg() gui.View {
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(text: 'Inline Icons', text_style: gui.theme().b4),
			gui.row(
				v_align: .middle
				content: [
					gui.svg(
						svg_data: svg_home
						width:    28
						height:   28
						color:    gui.theme().text_style.color
					),
					gui.svg(
						svg_data: svg_settings
						width:    28
						height:   28
						color:    gui.cornflower_blue
					),
					gui.svg(svg_data: svg_heart, width: 28, height: 28, color: gui.red),
				]
			),
			gui.text(text: 'clipPath', text_style: gui.theme().b4),
			gui.svg(
				svg_data: svg_clip_demo
				width:    220
				height:   150
			),
			gui.text(text: 'Stroke Styles', text_style: gui.theme().b4),
			gui.svg(
				svg_data: svg_stroke_demo
				width:    220
				height:   140
			),
			gui.text(text: 'Group Transforms', text_style: gui.theme().b4),
			gui.svg(
				svg_data: svg_transform_demo
				width:    240
				height:   150
			),
			gui.text(text: 'Style Inheritance', text_style: gui.theme().b4),
			gui.svg(
				svg_data: svg_inherit_demo
				width:    240
				height:   150
			),
			gui.text(text: 'Embedded SVG (small)', text_style: gui.theme().b4),
			gui.row(
				v_align: .middle
				content: [
					gui.svg(
						svg_data: tiger_svg_data
						width:    84
						height:   84
					),
					gui.text(text: 'Embedded `assets/svgs/tiger.svg`'),
				]
			),
			gui.text(text: 'Missing-file Fallback', text_style: gui.theme().b4),
			gui.svg(
				file_name: missing_svg_path
				width:     220
				height:    24
			),
		]
	)
}

const image_doc = '# Image

Render local or remote image assets.

## Usage

```v
gui.image(src: "photo.png", width: 200, height: 150)

gui.image(src: "https://example.com/photo.jpg")
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| src | string | File path or URL |
| width | f32 | Display width |
| height | f32 | Display height |
| min_width | f32 | Minimum width constraint |
| max_width | f32 | Maximum width constraint |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_click | fn (&Layout, mut Event, mut Window) | Image clicked |
| on_hover | fn (mut Layout, mut Event, mut Window) | Pointer enters image |'

fn demo_image() gui.View {
	image_path := showcase_image_path()
	return gui.column(
		padding: gui.padding_none
		spacing: 12
		content: [
			gui.row(
				spacing: 24
				content: [
					gui.column(
						spacing:     8
						padding:     gui.padding_none
						size_border: 0
						content:     [
							gui.text(text: 'Default', text_style: gui.theme().b4),
							gui.image(
								src:    image_path
								width:  120
								height: 120
								sizing: gui.fixed_fixed
							),
						]
					),
					gui.column(
						spacing:     8
						padding:     gui.padding_none
						size_border: 0
						content:     [
							gui.text(text: 'Rounded (radius: 10)', text_style: gui.theme().b4),
							gui.column(
								clip:        true
								radius:      10
								width:       120
								height:      120
								sizing:      gui.fixed_fixed
								padding:     gui.padding_none
								size_border: 0
								content:     [
									gui.image(
										src:    image_path
										width:  120
										height: 120
										sizing: gui.fixed_fixed
									),
								]
							),
						]
					),
					gui.column(
						spacing:     8
						padding:     gui.padding_none
						size_border: 0
						content:     [
							gui.text(text: 'Circle', text_style: gui.theme().b4),
							gui.circle(
								clip:        true
								width:       120
								height:      120
								sizing:      gui.fixed_fixed
								padding:     gui.padding_none
								size_border: 0
								content:     [
									gui.image(
										src:    image_path
										width:  120
										height: 120
										sizing: gui.fixed_fixed
									),
								]
							),
						]
					),
				]
			),
			gui.text(text: 'Embedded: assets/image_clip_face.jpg', text_style: gui.theme().n4),
		]
	)
}

const expand_panel_doc = '# Expand Panel

Collapsible region with custom header and content.

## Usage

```v
gui.expand_panel(
    head:    gui.text(text: "Details"),
    content: gui.text(text: "Expanded content here"),
    open:    state.panel_open,
    on_toggle: fn (mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.panel_open = !s.panel_open
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| head | View | Header view (always visible) |
| content | View | Body view (shown when open) |
| open | bool | Expanded state |
| radius | f32 | Corner radius |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_toggle | fn (mut Window) | Panel opened or closed |'

fn demo_expand_panel(w &gui.Window) gui.View {
	return expand_panel_sample(w)
}

const row_doc = '# Row

Horizontal container that arranges children left-to-right.

## Usage

```v
gui.row(
    spacing: 8,
    content: [
        gui.text(text: "Left"),
        gui.text(text: "Right"),
    ],
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| spacing | f32 | Gap between children |
| sizing | SizeCfg | Size behavior (fill, fit, fixed) |
| h_align | HorizontalAlign | Horizontal alignment |
| v_align | VerticalAlign | Vertical alignment |
| padding | Padding | Inner margin |
| content | []View | Child views |
| color | Color | Background (transparent default) |
| radius | f32 | Corner radius |

Sugar for `container(axis: .left_to_right, ...)`.'

const column_doc = '# Column

Vertical container that arranges children top-to-bottom.

## Usage

```v
gui.column(
    spacing: 8,
    content: [
        gui.text(text: "Top"),
        gui.text(text: "Bottom"),
    ],
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| spacing | f32 | Gap between children |
| sizing | SizeCfg | Size behavior (fill, fit, fixed) |
| h_align | HorizontalAlign | Horizontal alignment |
| v_align | VerticalAlign | Vertical alignment |
| padding | Padding | Inner margin |
| content | []View | Child views |
| color | Color | Background (transparent default) |
| radius | f32 | Corner radius |

Sugar for `container(axis: .top_to_bottom, ...)`.'

fn demo_row() gui.View {
	return gui.column(
		spacing: gui.spacing_large
		content: [
			gui.text(text: 'Children flow left-to-right.'),
			// basic row
			gui.row(
				spacing: 8
				content: [
					demo_box('A', gui.cornflower_blue),
					demo_box('B', gui.orange),
					demo_box('C', gui.dark_green),
				]
			),
			// row with alignment
			gui.text(text: 'Vertical alignment: middle'),
			gui.row(
				spacing: 8
				v_align: .middle
				content: [
					demo_box_sized('Tall', gui.cornflower_blue, 60, 80),
					demo_box('Mid', gui.orange),
					demo_box_sized('Short', gui.dark_green, 60, 30),
				]
			),
			// fill-width children
			gui.text(text: 'Fill-width children share space equally'),
			gui.row(
				sizing:  gui.fill_fit
				spacing: 8
				content: [
					gui.row(
						sizing:  gui.fill_fit
						height:  40
						padding: gui.padding(8, 8, 8, 8)
						radius:  6
						color:   gui.cornflower_blue
						content: [gui.text(text: '1/3')]
					),
					gui.row(
						sizing:  gui.fill_fit
						height:  40
						padding: gui.padding(8, 8, 8, 8)
						radius:  6
						color:   gui.orange
						content: [gui.text(text: '1/3')]
					),
					gui.row(
						sizing:  gui.fill_fit
						height:  40
						padding: gui.padding(8, 8, 8, 8)
						radius:  6
						color:   gui.dark_green
						content: [gui.text(text: '1/3')]
					),
				]
			),
		]
	)
}

fn demo_column() gui.View {
	return gui.column(
		spacing: gui.spacing_large
		content: [
			gui.text(text: 'Children flow top-to-bottom.'),
			gui.row(
				spacing: gui.spacing_large
				content: [
					// basic column
					gui.column(
						spacing: 8
						content: [
							demo_box('1', gui.cornflower_blue),
							demo_box('2', gui.orange),
							demo_box('3', gui.dark_green),
						]
					),
					// column with h_align center
					gui.column(
						width:   120
						sizing:  gui.fixed_fit
						spacing: 8
						h_align: .center
						color:   gui.theme().color_panel
						radius:  6
						padding: gui.padding(8, 8, 8, 8)
						content: [
							demo_box('A', gui.cornflower_blue),
							demo_box_sized('Wide', gui.orange, 100, 40),
							demo_box('B', gui.dark_green),
						]
					),
				]
			),
		]
	)
}

fn demo_box(label string, color gui.Color) gui.View {
	return demo_box_sized(label, color, 60, 40)
}

fn demo_box_sized(label string, color gui.Color, w f32, h f32) gui.View {
	return gui.row(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		radius:  6
		color:   color
		h_align: .center
		v_align: .middle
		content: [gui.text(text: label)]
	)
}

const wrap_panel_doc = '# Wrap Panel

Flow layout that arranges children left-to-right, wrapping to the
next line when the container width is exceeded.

## Usage

```v
gui.wrap(
    width:   300,
    sizing:  gui.fixed_fit,
    spacing: 8,
    content: [
        gui.button(content: [gui.text(text: "One")]),
        gui.button(content: [gui.text(text: "Two")]),
        gui.button(content: [gui.text(text: "Three")]),
    ],
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| width | f32 | Container width for line-break calculation |
| sizing | SizeCfg | Size behavior (typically fixed_fit) |
| spacing | f32 | Gap between items and between rows |
| padding | Padding | Inner margin |
| content | []View | Child views to flow |

Sugar for `gui.row(wrap: true, ...)`.'

fn demo_wrap_panel(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		sizing:  gui.fill_fit
		spacing: gui.spacing_large
		content: [
			gui.text(text: 'Resize the window to see items reflow.'),
			gui.wrap(
				sizing:  gui.fill_fit
				spacing: 8
				content: [
					wrap_tag('Checks'),
					gui.checkbox(
						label:    'Alpha'
						select:   app.wrap_check_a
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[ShowcaseApp]()
							a.wrap_check_a = !a.wrap_check_a
						}
					),
					gui.checkbox(
						label:    'Beta'
						select:   app.wrap_check_b
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[ShowcaseApp]()
							a.wrap_check_b = !a.wrap_check_b
						}
					),
					wrap_tag('Switches'),
					gui.switch(
						label:    'Dark mode'
						select:   app.wrap_switch_a
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[ShowcaseApp]()
							a.wrap_switch_a = !a.wrap_switch_a
						}
					),
					gui.switch(
						label:    'Auto-save'
						select:   app.wrap_switch_b
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[ShowcaseApp]()
							a.wrap_switch_b = !a.wrap_switch_b
						}
					),
					wrap_tag('Size'),
					gui.radio(
						label:    'Small'
						select:   app.wrap_radio == 0
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[ShowcaseApp]()
							a.wrap_radio = 0
						}
					),
					gui.radio(
						label:    'Medium'
						select:   app.wrap_radio == 1
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[ShowcaseApp]()
							a.wrap_radio = 1
						}
					),
					gui.radio(
						label:    'Large'
						select:   app.wrap_radio == 2
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[ShowcaseApp]()
							a.wrap_radio = 2
						}
					),
					gui.progress_bar(
						width:   120
						sizing:  gui.fixed_fit
						percent: 0.65
					),
					gui.button(
						content:  [gui.text(text: 'Reset')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut a := w.state[ShowcaseApp]()
							a.wrap_check_a = false
							a.wrap_check_b = false
							a.wrap_switch_a = false
							a.wrap_switch_b = false
							a.wrap_radio = 0
						}
					),
				]
			),
		]
	)
}

fn wrap_tag(label string) gui.View {
	return gui.row(
		padding: gui.padding(4, 12, 4, 12)
		radius:  12
		color:   gui.theme().color_active
		content: [gui.text(text: label)]
	)
}

const overflow_panel_doc = '# Overflow Panel

Row that shows children left-to-right; items that don\'t fit are hidden
and revealed in a floating dropdown menu via a trigger button.

## Usage

```v
window.overflow_panel(gui.OverflowPanelCfg{
    id:       "toolbar",
    id_focus: 1,
    items:    [
        gui.OverflowItem{
            id:   "home",
            text: "Home",
            view: gui.button(content: [gui.text(text: "Home")]),
        },
        gui.OverflowItem{
            id:   "edit",
            text: "Edit",
            view: gui.button(content: [gui.text(text: "Edit")]),
        },
    ],
})
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| id_focus | u32 | Focus index for the trigger button (required) |
| items | []OverflowItem | Toolbar items with view + menu fallback |
| trigger | []View | Custom trigger content; default: ellipsis icon |
| spacing | f32 | Gap between items |
| float_anchor | FloatAttach | Dropdown anchor point (default: bottom_right) |
| float_tie_off | FloatAttach | Dropdown tie-off (default: top_right) |

## OverflowItem

| Field | Type | Description |
|-------|------|-------------|
| id | string | Item identifier |
| view | View | Toolbar representation |
| text | string | Menu label when overflowed |
| action | fn | Callback when selected from dropdown |

Resize the container to see items collapse into the dropdown.'

fn demo_overflow_panel(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		spacing: gui.spacing_large
		content: [
			gui.text(
				text: 'Resize the window narrower to see items overflow into the dropdown.'
				mode: .wrap
			),
			w.overflow_panel(gui.OverflowPanelCfg{
				id:       'showcase_overflow'
				id_focus: 200
				items:    [
					overflow_demo_item('home', 'Home'),
					overflow_demo_item('edit', 'Edit'),
					overflow_demo_item('view', 'View'),
					overflow_demo_item('tools', 'Tools'),
					overflow_demo_item('help', 'Help'),
					overflow_demo_item('settings', 'Settings'),
					overflow_demo_item('about', 'About'),
				]
			}),
		]
	)
}

fn overflow_demo_item(id string, label string) gui.OverflowItem {
	return gui.OverflowItem{
		id:   id
		text: label
		view: gui.button(
			content: [gui.text(text: label)]
		)
	}
}

const combobox_doc = '# Combobox

Single-select dropdown with typeahead filtering. Accepts static options
or an async `ListBoxDataSource`.

## Usage

```v
w.combobox(
    id:          "fruit",
    id_focus:    1,
    id_scroll:   2,
    value:       state.selected,
    placeholder: "Pick a fruit...",
    options:     ["Apple", "Banana", "Cherry"],
    on_select:   fn (val string, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.selected = val
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| value | string | Current selection |
| options | []string | Static choices |
| data_source | ?ListBoxDataSource | Async data provider |
| placeholder | string | Text when empty |
| min_width | f32 | Minimum dropdown width |
| max_width | f32 | Maximum dropdown width |
| max_dropdown_height | f32 | Max dropdown height (default 200) |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_select | fn (string, mut Event, mut Window) | Selection changed (required) |'

fn demo_combobox(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Type to filter. Arrow keys to navigate, Enter to select, Escape to close.'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.row(
				v_align: .top
				spacing: gui.theme().spacing_large
				content: [
					gui.column(
						spacing: gui.theme().spacing_small
						content: [
							gui.text(text: 'Fruit picker', text_style: gui.theme().b5),
							w.combobox(
								id:          'showcase_combobox'
								id_focus:    9190
								id_scroll:   6
								value:       app.combobox_selected
								placeholder: 'Pick a fruit...'
								options:     [
									'Apple',
									'Banana',
									'Cherry',
									'Date',
									'Elderberry',
									'Fig',
									'Grape',
									'Honeydew',
									'Kiwi',
									'Lemon',
									'Mango',
									'Nectarine',
									'Orange',
									'Papaya',
									'Quince',
									'Raspberry',
									'Strawberry',
									'Tangerine',
									'Watermelon',
								]
								on_select:   fn (val string, mut _ gui.Event, mut w gui.Window) {
									mut a := w.state[ShowcaseApp]()
									a.combobox_selected = val
								}
							),
							gui.text(
								text:       'Selected: ${app.combobox_selected}'
								text_style: gui.theme().n5
							),
						]
					),
				]
			),
		]
	)
}

const command_palette_doc = '# Command Palette

Keyboard-first searchable command list with fuzzy matching.
Activated by a caller-defined hotkey. Full-screen backdrop with
centered floating card.

## Usage

```v
w.command_palette(
    id_focus:  5,
    id_scroll: 6,
    items:     my_items,
    on_action: fn (id string, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.last_action = id
    },
)

// Toggle in on_event:
gui.command_palette_toggle("__cmd_palette__", 5, mut w)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| items | []CommandPaletteItem | Available commands |
| placeholder | string | Input placeholder text |
| width | f32 | Card width |
| max_height | f32 | Max card height |
| backdrop_color | Color | Backdrop overlay color |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_action | fn (string, mut Event, mut Window) | Command selected (required) |
| on_dismiss | fn (mut Window) | Palette closed without action |'

fn demo_command_palette(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Click the button below to open. Type to filter, arrows to navigate, Enter to run.'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.button(
				content:  [gui.text(text: 'Open Command Palette')]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					gui.command_palette_show('__cmd_palette__', 9191, mut w)
				}
			),
			gui.text(
				text:       'Last action: ${app.last_palette_action}'
				text_style: gui.theme().n5
			),
			w.command_palette(
				id_focus:  9191
				id_scroll: 7
				items:     showcase_palette_items()
				on_action: fn (id string, mut _ gui.Event, mut w gui.Window) {
					mut a := w.state[ShowcaseApp]()
					a.last_palette_action = id
				}
			),
		]
	)
}

fn showcase_palette_items() []gui.CommandPaletteItem {
	return [
		gui.CommandPaletteItem{
			id:     'file.new'
			label:  'New File'
			detail: 'Ctrl+N'
		},
		gui.CommandPaletteItem{
			id:     'file.open'
			label:  'Open File'
			detail: 'Ctrl+O'
		},
		gui.CommandPaletteItem{
			id:     'file.save'
			label:  'Save'
			detail: 'Ctrl+S'
		},
		gui.CommandPaletteItem{
			id:     'file.save_as'
			label:  'Save As...'
			detail: 'Ctrl+Shift+S'
		},
		gui.CommandPaletteItem{
			id:     'edit.undo'
			label:  'Undo'
			detail: 'Ctrl+Z'
		},
		gui.CommandPaletteItem{
			id:     'edit.redo'
			label:  'Redo'
			detail: 'Ctrl+Shift+Z'
		},
		gui.CommandPaletteItem{
			id:     'edit.find'
			label:  'Find'
			detail: 'Ctrl+F'
		},
		gui.CommandPaletteItem{
			id:     'edit.replace'
			label:  'Find and Replace'
			detail: 'Ctrl+H'
		},
		gui.CommandPaletteItem{
			id:     'view.zoom_in'
			label:  'Zoom In'
			detail: 'Ctrl+='
		},
		gui.CommandPaletteItem{
			id:     'view.zoom_out'
			label:  'Zoom Out'
			detail: 'Ctrl+-'
		},
		gui.CommandPaletteItem{
			id:     'view.fullscreen'
			label:  'Toggle Fullscreen'
			detail: 'F11'
		},
		gui.CommandPaletteItem{
			id:     'term.new'
			label:  'New Terminal'
			detail: 'Ctrl+`'
		},
		gui.CommandPaletteItem{
			id:    'git.commit'
			label: 'Git: Commit'
		},
		gui.CommandPaletteItem{
			id:    'git.push'
			label: 'Git: Push'
		},
		gui.CommandPaletteItem{
			id:    'git.pull'
			label: 'Git: Pull'
		},
	]
}

const sidebar_doc = '# Sidebar

Animated panel that slides in/out. Width animates between 0 and the
configured width so a parent row redistributes space naturally.

## Usage

```v
window.sidebar(
    id:    "nav",
    open:  state.sidebar_open,
    width: 250,
    content: [gui.text(text: "Nav")],
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| open | bool | Whether the panel is expanded |
| width | f32 | Expanded width (default 250) |
| content | []View | Child views |
| spring | SpringCfg | Spring config (used when tween_duration is 0) |
| tween_duration | Duration | Tween length; 0 to use spring instead |
| tween_easing | EasingFn | Easing curve for tween |
| color | Color | Background color |
| radius | f32 | Corner radius |
| clip | bool | Clip children (default true) |

Tween and spring are mutually exclusive — tween wins when
`tween_duration > 0`.'

fn demo_sidebar(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		sizing:  gui.fill_fit
		spacing: gui.spacing_large
		content: [
			gui.text(
				text: 'Toggle the sidebar open/closed. Width animates so siblings redistribute.'
				mode: .wrap
			),
			gui.button(
				content:  [
					gui.text(
						text: if app.sidebar_open { 'Close Sidebar' } else { 'Open Sidebar' }
					),
				]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut a := w.state[ShowcaseApp]()
					a.sidebar_open = !a.sidebar_open
				}
			),
			gui.row(
				sizing:  gui.fill_fixed
				height:  200
				spacing: 0
				content: [
					w.sidebar(
						id:      'showcase_sidebar'
						open:    app.sidebar_open
						width:   180
						color:   gui.Color{50, 55, 65, 255}
						radius:  6
						content: [
							gui.text(
								text:       'Sidebar'
								text_style: gui.TextStyle{
									...gui.theme().b2
									color: gui.white
								}
							),
						]
					),
					gui.column(
						sizing:  gui.fill_fill
						padding: gui.padding(8, 12, 8, 12)
						color:   gui.theme().color_panel
						content: [
							gui.text(text: 'Main content area', mode: .wrap),
						]
					),
				]
			),
		]
	)
}

const icons_doc = '# Icons

Icon font catalog with 256 glyph constants from the Feather icon set.

## Usage

```v
gui.text(text: gui.icon_check, text_style: gui.theme().icon4)

gui.text(text: gui.icon_home, text_style: gui.theme().icon2)
```

## Common Icons

| Constant | Glyph |
|----------|-------|
| icon_check | Checkmark |
| icon_close | X mark |
| icon_search | Magnifier |
| icon_home | House |
| icon_plus / icon_minus | Add / Remove |
| icon_arrow_up / down / left / right | Directional arrows |
| icon_heart / icon_star | Common symbols |
| icon_eye / icon_lock | Visibility / Security |

Use `gui.icons_map` for programmatic access to all icon names.
Icons require `gui.theme().icon*` text styles for correct sizing.'

fn demo_icons() gui.View {
	keys := gui.icons_map.keys()
	mut rows := []gui.View{}
	for i := 0; i < keys.len; i += 5 {
		mut icons := []gui.View{}
		end := if i + 5 < keys.len { i + 5 } else { keys.len }
		for j := i; j < end; j++ {
			key := keys[j]
			icons << gui.column(
				min_width: 100
				h_align:   .center
				padding:   gui.padding_small
				content:   [
					gui.text(
						text:       gui.icons_map[key]
						text_style: gui.theme().icon1
					),
					gui.text(
						text:       key.replace('icon_', '')
						text_style: gui.theme().n5
					),
				]
			)
		}
		rows << gui.row(
			spacing: 0
			content: icons
		)
	}
	return gui.column(
		spacing: gui.spacing_small
		content: rows
	)
}

const gradient_doc = '# Gradients

Linear and radial gradient fills for containers and rectangles.

## Usage

```v
gui.rectangle(
    width: 200, height: 100,
    gradient: &gui.Gradient{
        stops: [
            gui.GradientStop{color: gui.color_blue, pos: 0},
            gui.GradientStop{color: gui.color_red, pos: 1},
        ],
        direction: .to_right,
    },
)
```

## Key Properties (Gradient)

| Property | Type | Description |
|----------|------|-------------|
| stops | []GradientStop | Color stops (max 5) |
| type | GradientType | .linear, .radial |
| direction | GradientDirection | .to_top, .to_right, etc. |
| angle | ?f32 | Explicit angle in degrees |

## GradientStop

| Property | Type | Description |
|----------|------|-------------|
| color | Color | Stop color |
| pos | f32 | Position 0.0 to 1.0 |

See also: docs/GRADIENTS.md'

fn demo_gradient() gui.View {
	linear := &gui.Gradient{
		direction: .to_bottom_right
		stops:     [
			gui.GradientStop{
				color: gui.cornflower_blue
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.dark_blue
				pos:   1.0
			},
		]
	}
	radial := &gui.Gradient{
		type:  .radial
		stops: [
			gui.GradientStop{
				color: gui.yellow
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.orange
				pos:   0.55
			},
			gui.GradientStop{
				color: gui.red
				pos:   1.0
			},
		]
	}
	border_grad := &gui.Gradient{
		direction: .to_bottom_right
		stops:     [
			gui.GradientStop{
				color: gui.red
				pos:   0.0
			},
			gui.GradientStop{
				color: gui.blue
				pos:   1.0
			},
		]
	}
	return gui.column(
		spacing: gui.theme().spacing_large
		content: [
			gui.row(
				spacing: gui.theme().spacing_small
				content: [
					gui.text(text: 'Linear', text_style: gui.theme().b5),
					gui.rectangle(
						width:        220
						height:       120
						sizing:       gui.fixed_fixed
						radius:       10
						gradient:     linear
						color_border: gui.theme().color_border
						size_border:  1
					),
				]
			),
			gui.row(
				spacing: gui.theme().spacing_small
				content: [
					gui.text(text: 'Radial', text_style: gui.theme().b5),
					gui.rectangle(
						width:        220
						height:       120
						sizing:       gui.fixed_fixed
						radius:       10
						gradient:     radial
						color_border: gui.theme().color_border
						size_border:  1
					),
				]
			),
			gui.row(
				spacing: gui.theme().spacing_small
				content: [
					gui.text(text: 'Border', text_style: gui.theme().b5),
					gui.rectangle(
						width:           220
						height:          120
						sizing:          gui.fixed_fixed
						radius:          10
						border_gradient: border_grad
						size_border:     3
					),
				]
			),
		]
	)
}

fn showcase_shadow_card(title string, note string, bg gui.Color, shadow_color gui.Color, shadow_offset_x f32, shadow_offset_y f32, shadow_blur f32, shadow_spread f32) gui.View {
	return gui.column(
		width:        170
		height:       96
		sizing:       gui.fixed_fixed
		padding:      gui.padding_small
		spacing:      2
		radius:       10
		color:        bg
		color_border: gui.theme().color_border
		size_border:  1
		shadow:       &gui.BoxShadow{
			color:         shadow_color
			offset_x:      shadow_offset_x
			offset_y:      shadow_offset_y
			blur_radius:   shadow_blur
			spread_radius: shadow_spread
		}
		content:      [
			gui.text(text: title, text_style: gui.theme().b5),
			gui.text(text: note, text_style: gui.theme().n5, mode: .wrap),
		]
	)
}

const box_shadows_doc = '# Box Shadows

Shadow presets applied to containers and rectangles.

## Usage

```v
gui.rectangle(
    width: 150, height: 80,
    color: gui.color_white,
    shadow: &gui.BoxShadow{
        color:         gui.Color{0, 0, 0, 60},
        offset_x:      0,
        offset_y:      4,
        blur_radius:   8,
        spread_radius: 0,
    },
)
```

## Key Properties (BoxShadow)

| Property | Type | Description |
|----------|------|-------------|
| color | Color | Shadow color (use alpha for softness) |
| offset_x | f32 | Horizontal offset |
| offset_y | f32 | Vertical offset |
| blur_radius | f32 | Blur amount |
| spread_radius | f32 | Positive expands, negative contracts |

Combine offset and blur for depth effects. Positive `spread_radius`
enlarges the shadow silhouette; negative values shrink it.'

fn demo_box_shadows() gui.View {
	card_color := gui.theme().color_background
	return gui.column(
		spacing: gui.theme().spacing_medium
		content: [
			gui.text(
				text:       'offset_x/offset_y move the shadow. blur_radius controls softness.'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.text(
				text:       'spread_radius exists in gui.BoxShadow, but this render path does not apply it.'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.row(
				spacing: 40
				content: [
					showcase_shadow_card('Soft depth', 'Blur 12, Y 3', card_color, gui.Color{0, 0, 0, 40},
						0, 3, 12, 0),
					showcase_shadow_card('Elevated', 'Blur 22, Y 10', card_color, gui.Color{0, 0, 0, 55},
						0, 10, 22, 0),
				]
			),
			gui.row(
				spacing: 40
				content: [
					showcase_shadow_card('Directional', 'Blur 10, X 8, Y 8', card_color,
						gui.Color{0, 0, 0, 65}, 8, 8, 10, 0),
					showcase_shadow_card('Blue glow', 'Blur 24, no offset', card_color,
						gui.Color{80, 120, 255, 85}, 0, 0, 24, 0),
				]
			),
			gui.text(
				text:       'spread_radius compare: cards below should match today.'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.row(
				spacing: 40
				content: [
					showcase_shadow_card('Spread 0', 'spread_radius: 0', card_color, gui.Color{0, 0, 0, 70},
						4, 6, 14, 0),
					showcase_shadow_card('Spread 16', 'spread_radius: 16', card_color,
						gui.Color{0, 0, 0, 70}, 4, 6, 14, 16),
				]
			),
		]
	)
}

const shader_doc = '# Custom Shaders

Custom fragment shaders for dynamic fills on containers and rectangles.
The framework wraps user code with SDF round-rect clipping, so shaders
automatically respect corner radius.

## Usage

```v
gui.rectangle(
    width: 200, height: 200, radius: 8,
    shader: &gui.Shader{
        metal: "
            float d = length(pos - 0.5);
            return half4(half3(d, 1.0 - d, 0.5), 1.0);
        ",
        glsl: "
            float d = length(pos - 0.5);
            frag_color = vec4(d, 1.0 - d, 0.5, 1.0);
        ",
    },
)
```

## Key Properties (Shader)

| Property | Type | Description |
|----------|------|-------------|
| metal | string | MSL fragment body |
| glsl | string | GLSL 3.3 fragment body |
| params | []f32 | Up to 16 custom floats |

Built-in uniforms: `pos` (normalized 0..1), `size` (pixels),
`time` (seconds), `radius`, and the params array via the `tm` matrix.

See also: docs/SHADERS.md'

fn demo_shader() gui.View {
	band_shader := &gui.Shader{
		metal: '
			float2 st = in.uv * 0.5 + 0.5;
			float bands = 0.5 + 0.5 * sin((st.x + st.y) * 16.0);
			float3 c1 = float3(0.12, 0.22, 0.85);
			float3 c2 = float3(0.10, 0.85, 0.80);
			float3 c = c1 * (1.0 - bands) + c2 * bands;
			float4 frag_color = float4(c, 1.0);
		'
		glsl:  '
			vec2 st = uv * 0.5 + 0.5;
			float bands = 0.5 + 0.5 * sin((st.x + st.y) * 16.0);
			vec3 c1 = vec3(0.12, 0.22, 0.85);
			vec3 c2 = vec3(0.10, 0.85, 0.80);
			vec3 c = c1 * (1.0 - bands) + c2 * bands;
			vec4 frag_color = vec4(c, 1.0);
		'
	}
	orb_shader := &gui.Shader{
		metal: '
			float2 st = in.uv;
			float r = length(st);
			float core = 1.0 - smoothstep(0.0, 0.35, r);
			float halo = 1.0 - smoothstep(0.35, 0.9, r);
			float3 c = float3(1.00, 0.65, 0.25) * core
				+ float3(0.25, 0.65, 1.00) * (halo * 0.75);
			float4 frag_color = float4(c, 1.0);
		'
		glsl:  '
			vec2 st = uv;
			float r = length(st);
			float core = 1.0 - smoothstep(0.0, 0.35, r);
			float halo = 1.0 - smoothstep(0.35, 0.9, r);
			vec3 c = vec3(1.00, 0.65, 0.25) * core
				+ vec3(0.25, 0.65, 1.00) * (halo * 0.75);
			vec4 frag_color = vec4(c, 1.0);
		'
	}
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Fragment shader bodies for Metal and GLSL.'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.row(
				spacing: gui.theme().spacing_large
				content: [
					gui.column(
						spacing: gui.theme().spacing_small
						content: [
							gui.text(text: 'Band Shader', text_style: gui.theme().b5),
							gui.rectangle(
								width:        220
								height:       120
								sizing:       gui.fixed_fixed
								radius:       10
								shader:       band_shader
								color_border: gui.theme().color_border
								size_border:  1
							),
							gui.text(text: 'GLSL + Metal', text_style: gui.theme().n5),
						]
					),
					gui.column(
						spacing: gui.theme().spacing_small
						content: [
							gui.text(text: 'Orb Shader', text_style: gui.theme().b5),
							gui.rectangle(
								width:        220
								height:       120
								sizing:       gui.fixed_fixed
								radius:       10
								shader:       orb_shader
								color_border: gui.theme().color_border
								size_border:  1
							),
							gui.text(text: 'Custom Fragment', text_style: gui.theme().n5),
						]
					),
				]
			),
		]
	)
}

const animations_doc = '# Animations

Tween, spring, keyframe, and layout transition animations.

## Usage

```v
// Tween
mut tween := gui.TweenAnimation{
    id:       "fade",
    from:     0, to: 1,
    duration: 300 * time.millisecond,
    on_value: fn (val f32, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.opacity = val
    },
}
w.animation_add(mut tween)

// Spring
mut spring := gui.SpringAnimation{
    id:     "bounce",
    config: gui.spring_bouncy,
    on_value: fn (val f32, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.offset = val
    },
}
w.animation_add(mut spring)
```

## Key Types

| Type | Description |
|------|-------------|
| TweenAnimation | Value interpolation with easing |
| SpringAnimation | Physics-based spring motion |
| KeyframeAnimation | Multi-point timeline animation |
| LayoutTransitionCfg | Animate layout position changes |
| HeroTransitionCfg | Cross-view element transitions |

## Spring Presets

| Preset | Stiffness | Damping | Character |
|--------|-----------|---------|-----------|
| spring_default | 100 | 10 | Balanced |
| spring_gentle | 50 | 8 | Soft, slow |
| spring_bouncy | 300 | 15 | Springy |
| spring_stiff | 500 | 30 | Snappy |

See also: docs/ANIMATIONS.md'

fn demo_animations(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	box_color := if gui.theme().titlebar_dark { gui.cornflower_blue } else { gui.dark_blue }
	return gui.column(
		sizing:  gui.fill_fit
		spacing: gui.theme().spacing_medium
		content: [
			gui.row(
				content: [
					gui.button(
						content:  [gui.text(text: 'Tween')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							start_tween(mut w, gui.ease_out_cubic)
						}
					),
					gui.button(
						content:  [gui.text(text: 'Spring')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							start_spring(mut w, gui.spring_default)
						}
					),
					gui.button(
						content:  [gui.text(text: 'Keyframe')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							start_keyframe(mut w)
						}
					),
					gui.button(
						content:  [gui.text(text: 'Layout')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.animate_layout(duration: 350 * time.millisecond)
							mut app := w.state[ShowcaseApp]()
							app.anim_layout_expanded = !app.anim_layout_expanded
						}
					),
					gui.button(
						content:  [gui.text(text: 'Hero')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.transition_to_view(showcase_hero_detail_view,
								duration: 550 * time.millisecond
							)
						}
					),
				]
			),
			gui.text(text: 'Tween', text_style: gui.theme().n5),
			gui.row(
				height:  28
				sizing:  gui.fill_fixed
				padding: gui.padding_none
				content: [
					gui.row(
						width:   int(app.anim_tween_x)
						sizing:  gui.fixed_fit
						padding: gui.padding_none
					),
					gui.row(
						width:  22
						height: 22
						sizing: gui.fixed_fixed
						color:  box_color
						radius: 4
					),
				]
			),
			gui.text(text: 'Spring', text_style: gui.theme().n5),
			gui.row(
				height:  28
				sizing:  gui.fill_fixed
				padding: gui.padding_none
				content: [
					gui.row(
						width:   int(app.anim_spring_x)
						sizing:  gui.fixed_fit
						padding: gui.padding_none
					),
					gui.row(
						width:  22
						height: 22
						sizing: gui.fixed_fixed
						color:  gui.green
						radius: 11
					),
				]
			),
			gui.text(text: 'Keyframe', text_style: gui.theme().n5),
			gui.row(
				height:  28
				sizing:  gui.fill_fixed
				padding: gui.padding_none
				content: [
					gui.row(
						width:   int(app.anim_keyframe_x)
						sizing:  gui.fixed_fit
						padding: gui.padding_none
					),
					gui.row(
						width:  22
						height: 22
						sizing: gui.fixed_fixed
						color:  gui.orange
						radius: 4
					),
				]
			),
			gui.text(text: 'Layout Transition', text_style: gui.theme().n5),
			gui.row(
				height:  52
				sizing:  gui.fill_fixed
				padding: gui.padding_none
				content: layout_boxes(app.anim_layout_expanded, box_color)
			),
			gui.text(text: 'Hero Source Card', text_style: gui.theme().n5),
			gui.row(
				v_align: .middle
				content: [
					gui.column(
						id:      'showcase_anim_hero_card'
						hero:    true
						width:   120
						height:  72
						sizing:  gui.fixed_fixed
						color:   gui.orange
						radius:  10
						h_align: .center
						v_align: .middle
						content: [
							gui.text(
								id:         'showcase_anim_hero_title'
								hero:       true
								text:       'Hero'
								text_style: gui.theme().b4
							),
						]
					),
					gui.text(text: 'Press Hero to transition', text_style: gui.theme().n5),
				]
			),
		]
	)
}

fn showcase_hero_detail_view(mut window gui.Window) gui.View {
	w, h := window.window_size()
	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.theme().padding_large
		spacing: gui.theme().spacing_medium
		content: [
			gui.button(
				content:  [gui.text(text: 'Back')]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					w.transition_to_view(main_view, duration: 550 * time.millisecond)
				}
			),
			gui.column(
				id:      'showcase_anim_hero_card'
				hero:    true
				sizing:  gui.fill_fill
				color:   gui.orange
				radius:  16
				h_align: .center
				v_align: .middle
				content: [
					gui.text(
						id:         'showcase_anim_hero_title'
						hero:       true
						text:       'Hero Detail'
						text_style: gui.theme().b2
					),
				]
			),
		]
	)
}

const color_picker_doc = '# Color Picker

Pick RGBA and optional HSV values with visual selectors.

## Usage

```v
gui.color_picker(
    id:    "picker",
    color: state.color,
    on_color_change: fn (c gui.Color, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.color = c
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| color | Color | Current selected color |
| on_color_change | fn (Color, mut Event, mut Window) | Color changed (required) |
| style | ColorPickerStyle | Visual style preset |
| show_hsv | bool | Show HSV sliders |'

fn demo_color_picker(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.switch(
				label:    'HSV mode'
				select:   app.color_picker_hsv
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.color_picker_hsv = !app.color_picker_hsv
				}
			),
			gui.color_picker(
				id:              'catalog_color_picker'
				color:           app.color_picker_color
				id_focus:        9106
				show_hsv:        app.color_picker_hsv
				on_color_change: fn (c gui.Color, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.color_picker_color = c
				}
			),
		]
	)
}

const theme_gen_doc = '# Theme Generator

Generate a complete color theme from a single seed color.

The generator works in HSV color space. It extracts the hue and
saturation from the seed color, then builds a full `ThemeCfg` with
nine semantic palette colors, each at a different brightness step.

## Tint

**Tint** (0–100%) controls how much of the seed color bleeds into
UI surfaces (background, panel, interior, hover). At 0% every
surface is pure gray. At 100% surfaces carry the full seed
saturation. Accent colors (`color_select`, `color_border_focus`)
always use full saturation so interactive highlights stay vivid
regardless of tint.

## Palette Strategies

Each strategy determines how the **primary hue** (surfaces) and
**accent hue** (focus, active, borders, selection) relate:

| Strategy | Relationship | Character |
|----------|-------------|-----------|
| Mono | Same hue for both | Single-hue; variation from brightness only |
| Complement | Accent is 180° opposite | Strong surface/accent contrast |
| Analogous | Accent is 30° from seed | Subtle warm/cool shift |
| Triadic | Accent is 120° from seed | Balanced without full clash |
| Warm | Forces primary into 0–60° | Red-yellow palette regardless of seed |
| Cool | Forces primary into 180–270° | Cyan-blue palette regardless of seed |

## Other Controls

| Control | Description |
|---------|-------------|
| Radius | Corner rounding for all widgets |
| Border | Border thickness for all widgets |
| Edit text color | Switches the color picker to edit text color instead of seed |

## Programmatic Usage

```v
cfg := gui.ThemeCfg{
    color_select:    seed_color,
    color_background: gui.color_from_hsv(hue, saturation, 0.19),
    // ... remaining palette colors
    radius:          5.5,
    size_border:     1.5,
}
theme := gui.theme_maker(&cfg)
w.set_theme(theme)
```

Themes can be saved and loaded as JSON:

```v
gui.theme_save("my_theme.json", theme)!
loaded := gui.theme_load("my_theme.json")!
w.set_theme(loaded)
```

See also: docs/THEMES.md'

// ==============================================================
// Theme Generator
//
// Generates a complete ThemeCfg from a single seed color
// using HSV color-space manipulation. The seed's hue drives
// all palette colors; its saturation is modulated by the
// tint slider.
//
// Two hue variables control the output:
//   ph — "primary hue": used for backgrounds, panels, hover
//   ah — "accent hue":  used for focus, active, borders,
//                        select highlight
//
// The palette strategy determines how ph and ah relate to
// the seed hue (see match block below).
//
// Tint (0–100%) controls how much of the seed's saturation
// bleeds into the neutral UI surfaces (backgrounds, panels,
// inputs, hover states). At 0% every surface is pure gray;
// at 100% surfaces carry the full seed saturation. Accent
// colors (select, border_focus) always use full saturation
// regardless of tint, so interactive highlights stay vivid.
//
// Palette strategies:
//   mono       — ph and ah equal the seed hue. Single-hue
//                theme; variation comes only from value steps.
//   complement — ah is 180° opposite the seed. Strong
//                contrast between surfaces and accents.
//   analogous  — ah is 30° from the seed. Subtle warm/cool
//                shift between surfaces and accents.
//   triadic    — ah is 120° from the seed. Balanced contrast
//                without the clash of a full complement.
//   warm       — forces ph into the 0–60° (red-yellow) range
//                and ah 15° ahead. Cozy palette regardless
//                of seed hue.
//   cool       — forces ph into the 180–270° (cyan-blue)
//                range and ah 20° ahead. Cool palette
//                regardless of seed hue.
// ==============================================================

fn wrap_hue(h f32) f32 {
	m := f32(math.fmod(f64(h), 360))
	return if m < 0 { m + 360 } else { m }
}

fn generate_theme_cfg(seed gui.Color, strategy string, is_dark bool, tint f32, text_color gui.Color, radius f32, border f32) gui.ThemeCfg {
	h, s, _ := seed.to_hsv()
	tint_factor := tint / 100.0

	mut ph := h // primary hue (surfaces)
	mut ah := h // accent hue (interactive states)
	accent_s := gui.f32_clamp(s, 0.5, 1.0)
	accent_v := if is_dark { f32(0.85) } else { f32(0.65) }

	match strategy {
		'complement' {
			ah = wrap_hue(h + 180)
		}
		'analogous' {
			ah = wrap_hue(h + 30)
		}
		'triadic' {
			ah = wrap_hue(h + 120)
		}
		'warm' {
			ph = f32(math.fmod(f64(h), 60))
			ah = ph + 15
		}
		'cool' {
			ph = 180 + f32(math.fmod(f64(h), 90))
			ah = ph + 20
		}
		else {} // mono: ph=h, ah=h
	}

	// s_tint scales the seed saturation by the tint slider.
	// Dark themes use the full tint; light themes halve it
	// so surfaces don't look washed out.
	if is_dark {
		s_tint := gui.f32_clamp(s, 0.3, 1.0) * tint_factor
		// Value steps ascend from background (darkest) to
		// active (lightest). Accent colors (select,
		// border_focus) ignore s_tint and stay vivid.
		return gui.ThemeCfg{
			name:               'generated'
			color_background:   gui.color_from_hsv(ph, s_tint, 0.19)
			color_panel:        gui.color_from_hsv(ph, s_tint, 0.25)
			color_interior:     gui.color_from_hsv(ph, s_tint, 0.29)
			color_hover:        gui.color_from_hsv(ph, s_tint, 0.33)
			color_focus:        gui.color_from_hsv(ah, s_tint, 0.37)
			color_active:       gui.color_from_hsv(ah, s_tint, 0.41)
			color_border:       gui.color_from_hsv(ah, s_tint * 0.8, 0.39)
			color_select:       gui.color_from_hsv(ah, accent_s, accent_v)
			color_border_focus: gui.color_from_hsv(ah, accent_s * 0.7, accent_v * 0.9)
			text_style:         gui.TextStyle{
				...gui.theme_dark_cfg.text_style
				color: text_color
			}
			titlebar_dark:      true
			size_border:        border
			radius:             radius
			radius_small:       radius * 0.64
			radius_medium:      radius
			radius_large:       radius * 1.36
			radius_border:      radius + 2
		}
	}
	// Light theme: value steps descend from background
	// (lightest) to active (darkest).
	s_tint := gui.f32_clamp(s, 0.3, 1.0) * tint_factor * 0.5
	return gui.ThemeCfg{
		name:               'generated'
		color_background:   gui.color_from_hsv(ph, s_tint * 0.6, 0.96)
		color_panel:        gui.color_from_hsv(ph, s_tint, 0.90)
		color_interior:     gui.color_from_hsv(ph, s_tint, 0.86)
		color_hover:        gui.color_from_hsv(ph, s_tint, 0.82)
		color_focus:        gui.color_from_hsv(ah, s_tint, 0.78)
		color_active:       gui.color_from_hsv(ah, s_tint, 0.74)
		color_border:       gui.color_from_hsv(ah, s_tint * 1.5, 0.55)
		color_select:       gui.color_from_hsv(ah, accent_s, accent_v * 0.75)
		color_border_focus: gui.color_from_hsv(ah, accent_s * 0.8, accent_v * 0.6)
		text_style:         gui.TextStyle{
			...gui.theme_light_cfg.text_style
			color: text_color
		}
		titlebar_dark:      false
		size_border:        border
		radius:             radius
		radius_small:       radius * 0.64
		radius_medium:      radius
		radius_large:       radius * 1.36
		radius_border:      radius + 2
	}
}

fn apply_gen_theme(mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	cfg := generate_theme_cfg(app.theme_gen_seed, app.theme_gen_strategy, gui.theme().titlebar_dark,
		app.theme_gen_tint, app.theme_gen_text, app.theme_gen_radius, app.theme_gen_border)
	w.set_theme(gui.theme_maker(&cfg))
}

fn sync_theme_gen_from_cfg(mut app ShowcaseApp, cfg gui.ThemeCfg) {
	app.theme_gen_seed = cfg.color_select
	app.theme_gen_tint = 0
	app.theme_gen_radius = cfg.radius
	app.theme_gen_radius_text = '${cfg.radius:.1}'
	app.theme_gen_border = cfg.size_border
	app.theme_gen_border_text = '${cfg.size_border:.1}'
	app.theme_gen_text = cfg.text_style.color
	app.theme_gen_pick_text = false
}

fn demo_theme_gen(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	t := gui.theme()
	cp_color := if app.theme_gen_pick_text { app.theme_gen_text } else { app.theme_gen_seed }
	return gui.column(
		spacing: t.spacing_small
		padding: gui.padding_none
		content: [
			gui.text(
				text: if app.theme_gen_name.len > 0 {
					app.theme_gen_name
				} else {
					'Pick a seed color to generate a full theme.'
				}
			),
			gui.row(
				spacing: t.spacing_medium
				v_align: .top
				content: [
					gui.column(
						spacing: t.spacing_medium
						content: [
							gui.color_picker(
								id:              'theme_gen_cp'
								color:           cp_color
								id_focus:        9170
								on_color_change: fn (c gui.Color, mut _ gui.Event, mut w gui.Window) {
									mut a := w.state[ShowcaseApp]()
									if a.theme_gen_pick_text {
										a.theme_gen_text = c
									} else {
										a.theme_gen_seed = c
									}
									apply_gen_theme(mut w)
								}
							),
							gui.text(text: 'Tint: ${int(app.theme_gen_tint)}%'),
							gui.range_slider(
								id:        'theme_gen_tint'
								value:     app.theme_gen_tint
								width:     140
								on_change: fn (value f32, mut _ gui.Event, mut w gui.Window) {
									mut a := w.state[ShowcaseApp]()
									a.theme_gen_tint = value
									apply_gen_theme(mut w)
								}
							),
							gui.row(
								spacing: t.spacing_medium
								padding: gui.padding_none
								content: [
									gui.column(
										spacing: t.spacing_small
										padding: gui.padding_none
										content: [
											gui.text(text: 'Radius'),
											gui.numeric_input(
												id:              'theme_gen_radius'
												id_focus:        9180
												text:            app.theme_gen_radius_text
												value:           ?f64(app.theme_gen_radius)
												decimals:        1
												min:             0.0
												max:             30.0
												step_cfg:        gui.NumericStepCfg{
													step: 0.5
												}
												width:           80
												sizing:          gui.fixed_fit
												on_text_changed: fn (_ &gui.Layout, text string, mut w gui.Window) {
													mut a := w.state[ShowcaseApp]()
													a.theme_gen_radius_text = text
												}
												on_value_commit: fn (_ &gui.Layout, value ?f64, text string, mut w gui.Window) {
													mut a := w.state[ShowcaseApp]()
													a.theme_gen_radius_text = text
													if v := value {
														a.theme_gen_radius = f32(v)
														apply_gen_theme(mut w)
													}
												}
											),
										]
									),
									gui.column(
										spacing: t.spacing_small
										padding: gui.padding_none
										content: [
											gui.text(text: 'Border'),
											gui.numeric_input(
												id:              'theme_gen_border'
												id_focus:        9188
												text:            app.theme_gen_border_text
												value:           ?f64(app.theme_gen_border)
												decimals:        1
												min:             0.0
												max:             10.0
												step_cfg:        gui.NumericStepCfg{
													step: 0.5
												}
												width:           80
												sizing:          gui.fixed_fit
												on_text_changed: fn (_ &gui.Layout, text string, mut w gui.Window) {
													mut a := w.state[ShowcaseApp]()
													a.theme_gen_border_text = text
												}
												on_value_commit: fn (_ &gui.Layout, value ?f64, text string, mut w gui.Window) {
													mut a := w.state[ShowcaseApp]()
													a.theme_gen_border_text = text
													if v := value {
														a.theme_gen_border = f32(v)
														apply_gen_theme(mut w)
													}
												}
											),
										]
									),
								]
							),
						]
					),
					gui.column(
						spacing: t.spacing_medium
						content: [
							gui.radio_button_group_column(
								title:     'Palette'
								id_focus:  9181
								value:     app.theme_gen_strategy
								options:   [
									gui.radio_option('Mono', 'mono'),
									gui.radio_option('Complement', 'complement'),
									gui.radio_option('Analogous', 'analogous'),
									gui.radio_option('Triadic', 'triadic'),
									gui.radio_option('Warm', 'warm'),
									gui.radio_option('Cool', 'cool'),
								]
								on_select: fn (value string, mut w gui.Window) {
									mut a := w.state[ShowcaseApp]()
									a.theme_gen_strategy = value
									apply_gen_theme(mut w)
								}
							),
							gui.checkbox(
								label:    'Edit text color'
								select:   app.theme_gen_pick_text
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									mut a := w.state[ShowcaseApp]()
									a.theme_gen_pick_text = !a.theme_gen_pick_text
								}
							),
							gui.button(
								content:  [
									gui.text(text: 'Save Theme'),
								]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									w.native_save_dialog(gui.NativeSaveDialogCfg{
										title:             'Save Theme'
										default_name:      'theme.json'
										default_extension: 'json'
										filters:           [
											gui.NativeFileFilter{
												name:       'JSON'
												extensions: [
													'json',
												]
											},
										]
										on_done:           fn (result gui.NativeDialogResult, mut w gui.Window) {
											if result.status != .ok || result.paths.len == 0 {
												return
											}
											mut a := w.state[ShowcaseApp]()
											cfg := generate_theme_cfg(a.theme_gen_seed,
												a.theme_gen_strategy, gui.theme().titlebar_dark,
												a.theme_gen_tint, a.theme_gen_text, a.theme_gen_radius,
												a.theme_gen_border)
											theme := gui.theme_maker(&cfg)
											gui.theme_save(result.paths[0].path, theme) or {}
											a.theme_gen_name = os.file_name(result.paths[0].path).all_before_last('.')
										}
									})
								}
							),
							gui.button(
								content:  [
									gui.text(text: 'Load Theme'),
								]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									w.native_open_dialog(gui.NativeOpenDialogCfg{
										title:   'Load Theme'
										filters: [
											gui.NativeFileFilter{
												name:       'JSON'
												extensions: [
													'json',
												]
											},
										]
										on_done: fn (result gui.NativeDialogResult, mut w gui.Window) {
											if result.status != .ok || result.paths.len == 0 {
												return
											}
											theme := gui.theme_load(result.paths[0].path) or {
												return
											}
											mut a := w.state[ShowcaseApp]()
											sync_theme_gen_from_cfg(mut a, theme.cfg)
											a.theme_gen_name = os.file_name(result.paths[0].path).all_before_last('.')
											w.set_theme(theme)
										}
									})
								}
							),
						]
					),
				]
			),
		]
	)
}

const markdown_doc = '# Markdown

Render markdown source into styled rich content.

## Usage

```v
w.markdown(source: "# Heading", mode: .wrap)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| source | string | Markdown text to render |
| mode | TextMode | .single_line, .wrap |
| style | MarkdownStyle | Custom rendering style |
| mermaid_width | int | Width for mermaid diagrams |

Supports headings, bold, italic, strikethrough, code blocks,
tables, task lists, blockquotes, images, links, mermaid diagrams,
and GitHub-standard shortcode names for emoji (`:smile:` syntax).
Links support right-click context menus (copy, open, inspect URL).

See also: docs/MARKDOWN.md'

fn demo_markdown(mut w gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_small
		color:   gui.theme().color_panel
		content: [
			w.markdown(
				id:      'catalog_markdown'
				source:  showcase_markdown_source
				mode:    .wrap
				padding: gui.padding_none
			),
		]
	)
}

fn demo_doc(mut w gui.Window, id string, source string) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_small
		color:   gui.theme().color_panel
		content: [
			w.markdown(
				id:      id
				source:  source
				mode:    .wrap
				padding: gui.padding_none
			),
		]
	)
}

fn demo_welcome(mut w gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_small
		color:   gui.theme().color_panel
		content: [
			w.markdown(
				id:      'catalog_welcome'
				source:  showcase_welcome_source
				mode:    .wrap
				padding: gui.padding_none
			),
		]
	)
}

const splitter_doc = '# Splitter

Two resizable panes with draggable divider, keyboard support,
and collapsible sides.

## Usage

```v
gui.splitter(
    id:     "main_split",
    ratio:  0.3,
    first:  gui.SplitterPaneCfg{content: left_panel()},
    second: gui.SplitterPaneCfg{content: right_panel()},
    on_change: fn (ratio f32, collapsed gui.SplitterCollapsed,
        mut _ gui.Event, mut w gui.Window)
    {
        mut s := w.state[MyApp]()
        s.ratio = ratio
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| first | SplitterPaneCfg | First pane config (required) |
| second | SplitterPaneCfg | Second pane config (required) |
| ratio | f32 | Split ratio 0.0 to 1.0 |
| orientation | SplitterOrientation | .horizontal, .vertical |
| collapsed | SplitterCollapsed | .none, .first, .second |
| show_collapse_buttons | bool | Show collapse arrows |
| double_click_collapse | bool | Double-click to collapse |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_change | fn (f32, SplitterCollapsed, mut Event, mut Window) | Ratio changed (required) |

See also: docs/SPLITTER.md'

fn demo_splitter(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	main_ratio := int(app.splitter_main_state.ratio * 100)
	detail_ratio := int(app.splitter_detail_state.ratio * 100)
	return gui.column(
		sizing:  gui.fill_fit
		spacing: gui.theme().spacing_small
		content: [
			gui.text(
				text:       'Drag handle. Focus splitter, then use arrow keys. Shift+arrow moves faster.'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.text(
				text:       'Main ${main_ratio}% (${app.splitter_main_state.collapsed.str()}), detail ${detail_ratio}% (${app.splitter_detail_state.collapsed.str()}).'
				text_style: gui.theme().n5
				mode:       .wrap
			),
			gui.row(
				height:       373
				sizing:       gui.fill_fixed
				color:        gui.theme().color_panel
				color_border: gui.theme().color_border
				size_border:  1
				radius:       gui.theme().radius_small
				content:      [
					showcase_splitter_main(w),
				]
			),
		]
	)
}

fn showcase_splitter_main(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.splitter(
		id:          'catalog_splitter_main'
		id_focus:    id_focus_showcase_splitter_main
		sizing:      gui.fill_fill
		orientation: .horizontal
		ratio:       app.splitter_main_state.ratio
		collapsed:   app.splitter_main_state.collapsed
		on_change:   on_showcase_splitter_main_change
		first:       gui.SplitterPaneCfg{
			min_size: 140
			max_size: 340
			content:  [
				showcase_splitter_pane('Project', '- src\n- docs\n- tests', gui.cornflower_blue),
			]
		}
		second:      gui.SplitterPaneCfg{
			min_size: 220
			content:  [
				showcase_splitter_detail(w),
			]
		}
	)
}

fn showcase_splitter_detail(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.splitter(
		id:                    'catalog_splitter_detail'
		id_focus:              id_focus_showcase_splitter_detail
		orientation:           .vertical
		sizing:                gui.fill_fill
		handle_size:           10
		show_collapse_buttons: true
		ratio:                 app.splitter_detail_state.ratio
		collapsed:             app.splitter_detail_state.collapsed
		on_change:             on_showcase_splitter_detail_change
		first:                 gui.SplitterPaneCfg{
			min_size: 110
			content:  [
				showcase_splitter_pane('Editor', 'Top pane. Home/End collapses pane.',
					gui.green),
			]
		}
		second:                gui.SplitterPaneCfg{
			min_size: 90
			content:  [
				showcase_splitter_pane('Preview', 'Bottom pane. Drag or use keyboard.',
					gui.orange),
			]
		}
	)
}

fn showcase_splitter_pane(title string, note string, accent gui.Color) gui.View {
	return gui.column(
		sizing:  gui.fill_fill
		padding: gui.padding(10, 10, 10, 10)
		spacing: 6
		color:   gui.theme().color_panel
		content: [
			gui.row(
				v_align: .middle
				content: [
					gui.row(
						width:   8
						height:  8
						sizing:  gui.fixed_fixed
						color:   accent
						padding: gui.padding_none
						radius:  4
					),
					gui.text(text: title, text_style: gui.theme().b5),
				]
			),
			gui.text(text: note, text_style: gui.theme().n5, mode: .wrap),
			gui.rectangle(
				sizing:       gui.fill_fill
				color:        gui.theme().color_background
				color_border: gui.theme().color_border
				size_border:  1
				radius:       gui.theme().radius_small
			),
		]
	)
}

fn on_showcase_splitter_main_change(ratio f32, collapsed gui.SplitterCollapsed, mut _e gui.Event, mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	app.splitter_main_state = gui.splitter_state_normalize(gui.SplitterState{
		ratio:     ratio
		collapsed: collapsed
	})
}

fn on_showcase_splitter_detail_change(ratio f32, collapsed gui.SplitterCollapsed, mut _e gui.Event, mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	app.splitter_detail_state = gui.splitter_state_normalize(gui.SplitterState{
		ratio:     ratio
		collapsed: collapsed
	})
}

const breadcrumb_doc = '# Breadcrumb

Trail navigation with optional content panels. Clicking a
crumb fires `on_select`; the app decides whether to truncate.

## Usage

```v
gui.breadcrumb(
    id:       "bc",
    selected: state.crumb,
    items: [
        gui.BreadcrumbItemCfg{id: "home", label: "Home"},
        gui.BreadcrumbItemCfg{id: "docs", label: "Docs"},
    ],
    on_select: fn (id string, mut _ gui.Event, mut w gui.Window) {
        w.state[MyApp]().crumb = id
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| items | []BreadcrumbItemCfg | Crumb definitions (required) |
| selected | string | Active crumb ID |
| separator | string | Text between crumbs (default "/") |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_select | fn (string, mut Event, mut Window) | Crumb clicked (required) |'

fn demo_breadcrumb(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				spacing: gui.theme().spacing_medium
				content: [
					gui.text(
						text:       'Click a crumb to truncate the trail.'
						text_style: gui.theme().n4
					),
					gui.button(
						id_focus: 9170
						content:  [gui.text(text: gui_locale.str_reset)]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut ww gui.Window) {
							mut a := ww.state[ShowcaseApp]()
							a.bc_path = bc_full_path
							a.bc_selected = 'page'
						}
					),
				]
			),
			gui.breadcrumb(
				id:        'catalog_breadcrumb'
				id_focus:  9171
				selected:  app.bc_selected
				items:     app.bc_path
				on_select: fn (id string, mut _e gui.Event, mut ww gui.Window) {
					mut a := ww.state[ShowcaseApp]()
					for i, item in a.bc_path {
						if item.id == id {
							a.bc_path = a.bc_path[..i + 1]
							break
						}
					}
					a.bc_selected = id
				}
			),
		]
	)
}

const tab_control_doc = '# Tab Control

Switch content panels with keyboard-friendly tabs.

## Usage

```v
gui.tab_control(
    id:       "tabs",
    selected: state.tab,
    items: [
        gui.TabItemCfg{id: "home", label: "Home",
            content: home_view()},
        gui.TabItemCfg{id: "settings", label: "Settings",
            content: settings_view()},
    ],
    on_select: fn (id string, mut _ gui.Event, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.tab = id
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| items | []TabItemCfg | Tab definitions (required) |
| selected | string | Active tab ID |
| reorderable | bool | Enable drag-to-reorder tabs |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_select | fn (string, mut Event, mut Window) | Tab changed (required) |
| on_reorder | fn (string, string, mut Window) | Tab reordered (moved_id, before_id) |'

fn demo_tab_control(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.tab_control(
		id:        'catalog_tabs'
		id_focus:  9107
		sizing:    gui.fill_fit
		selected:  app.tab_selected
		items:     [
			gui.tab_item('overview', 'Overview', [gui.text(text: 'Overview panel')]),
			gui.tab_item('metrics', 'Metrics', [gui.text(text: 'Metrics panel')]),
			gui.tab_item('settings', 'Settings', [gui.text(text: 'Settings panel')]),
		]
		on_select: fn (id string, mut _e gui.Event, mut w gui.Window) {
			w.state[ShowcaseApp]().tab_selected = id
		}
	)
}

const tooltip_doc = '# Tooltip

Hover hints with custom placement and content.

## Usage

```v
gui.button(
    content: [gui.text(text: "Hover me")],
    tooltip: &gui.TooltipCfg{
        id:      "tip1",
        content: [gui.text(text: "Helpful hint")],
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Unique identifier (required) |
| content | []View | Tooltip content views |
| delay | time.Duration | Show delay |
| anchor | FloatAttach | Anchor point on parent |
| tie_off | FloatAttach | Tooltip attachment point |
| offset_x | f32 | Horizontal offset |
| offset_y | f32 | Vertical offset |'

fn demo_tooltip() gui.View {
	return gui.row(
		content: [
			gui.button(
				sizing:  gui.fill_fit
				tooltip: &gui.TooltipCfg{
					id:      'catalog_tip_default'
					content: [gui.text(text: 'Default tooltip placement')]
				}
				content: [gui.text(text: 'Hover for tooltip')]
			),
			gui.button(
				sizing:  gui.fill_fit
				tooltip: &gui.TooltipCfg{
					id:      'catalog_tip_top'
					anchor:  .top_center
					tie_off: .bottom_center
					content: [gui.text(text: 'Tooltip with top anchor')]
				}
				content: [gui.text(text: 'Top anchored tooltip')]
			),
		]
	)
}

const rectangle_doc = '# Rectangle

Draw colored shapes with border, radius, gradient, shadow, and shader.

## Usage

```v
gui.rectangle(
    width:  100,
    height: 60,
    color:  gui.Color{100, 150, 200, 255},
    radius: 8,
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| color | Color | Fill color |
| radius | f32 | Corner radius |
| gradient | &Gradient | Gradient fill |
| shadow | &BoxShadow | Drop shadow |
| shader | &Shader | Custom fragment shader |
| blur_radius | f32 | Background blur |
| border_gradient | &Gradient | Gradient on border |'

fn demo_rectangle() gui.View {
	return gui.row(
		v_align: .middle
		content: [
			gui.rectangle(
				width:        120
				height:       70
				sizing:       gui.fixed_fixed
				color:        gui.theme().color_panel
				color_border: gui.theme().color_active
				size_border:  1
				radius:       8
			),
			gui.rectangle(
				width:        70
				height:       70
				sizing:       gui.fixed_fixed
				color:        gui.cornflower_blue
				color_border: gui.white
				size_border:  1
				radius:       35
			),
		]
	)
}

const scrollbar_doc = '# Scrollable Containers

Configure scrollbar appearance for scrollable layouts.

## Usage

```v
gui.column(
    id_scroll: 1,
    sizing:    gui.fill_fill,
    scrollbar_cfg_y: &gui.ScrollbarCfg{
        size:     8,
        gap_edge: 4,
        radius:   4,
    },
    content: long_content,
)
```

## Key Properties (ScrollbarCfg)

| Property | Type | Description |
|----------|------|-------------|
| size | f32 | Scrollbar track width |
| min_thumb_size | f32 | Minimum thumb length |
| color_thumb | Color | Thumb color |
| color_background | Color | Track background color |
| radius | f32 | Track corner radius |
| radius_thumb | f32 | Thumb corner radius |
| gap_edge | f32 | Gap from container edge |
| gap_end | f32 | Gap at scroll ends |
| overflow | ScrollbarOverflow | Visibility mode |'

fn demo_scrollbar() gui.View {
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.row(
				content: [
					gui.button(
						content:  [gui.text(text: 'Top')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.scroll_vertical_to(id_scroll_sync_demo, 0)
						}
					),
					gui.button(
						content:  [gui.text(text: 'Down')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.scroll_vertical_by(id_scroll_sync_demo, -120)
						}
					),
					gui.button(
						content:  [gui.text(text: 'Up')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.scroll_vertical_by(id_scroll_sync_demo, 120)
						}
					),
				]
			),
			gui.row(
				spacing: gui.theme().spacing_small
				content: [
					gui.column(
						id_scroll:       id_scroll_sync_demo
						width:           220
						height:          180
						sizing:          gui.fixed_fixed
						color:           gui.theme().color_panel
						color_border:    gui.theme().color_border
						size_border:     1
						padding:         gui.padding_none
						scrollbar_cfg_y: &gui.ScrollbarCfg{
							gap_edge: 3
						}
						content:         scroll_demo_rows('Left')
					),
					gui.column(
						id_scroll:       id_scroll_sync_demo
						width:           220
						height:          180
						sizing:          gui.fixed_fixed
						color:           gui.theme().color_panel
						color_border:    gui.theme().color_border
						size_border:     1
						padding:         gui.padding_none
						scrollbar_cfg_y: &gui.ScrollbarCfg{
							gap_edge: 3
						}
						content:         scroll_demo_rows('Right')
					),
				]
			),
		]
	)
}

fn scroll_demo_rows(prefix string) []gui.View {
	mut rows := []gui.View{cap: 24}
	for i in 1 .. 25 {
		rows << gui.row(
			sizing:  gui.fill_fit
			padding: gui.padding(2, 6, 2, 6)
			content: [gui.text(text: '${prefix} row ${i.str()}')]
		)
	}
	return rows
}

const numeric_input_doc = '# Numeric Input

Locale-aware number input with step controls, min/max validation,
configurable decimal precision, plus currency and percent modes.

## Usage

```v
gui.numeric_input(
    value:    state.amount,
    min:      0,
    max:      1000,
    decimals: 2,
    on_value_commit: fn (_ &gui.Layout, val ?f64, text string, mut w gui.Window) {
        mut s := w.state[MyApp]()
        s.amount = val
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| value | ?f64 | Current numeric value |
| text | string | Editable text representation |
| min | ?f64 | Minimum allowed value |
| max | ?f64 | Maximum allowed value |
| decimals | int | Decimal places (default: 2) |
| mode | NumericInputMode | `number`, `currency`, `percent` |
| currency_mode | NumericCurrencyModeCfg | Symbol and placement |
| percent_mode | NumericPercentModeCfg | Symbol and placement |
| step_cfg | NumericStepCfg | Step, multipliers, buttons |
| locale | NumericLocaleCfg | Decimal/group separators |

## Events

| Callback | Signature | Fired when |
|----------|-----------|------------|
| on_text_changed | fn (&Layout, string, mut Window) | Accepted text delta or step update |
| on_value_commit | fn (&Layout, ?f64, string, mut Window) | Canonical value commit |

## Notes

- Invalid deltas are rejected at pre-commit stage.
- Enter/blur normalize text before commit callbacks.
- In percent mode, value is ratio (12.50% => 0.125).'

const forms_doc = '# Forms

Form runtime for sync/async validation with field status and error slots.

## Usage

```v
gui.form(
    id: "signup",
    validate_on: .blur_submit,
    content: [
        gui.input(
            field_id: "username",
            text: state.username,
            form_sync_validators: [gui.FormSyncValidator(required_username)],
            form_async_validators: [gui.FormAsyncValidator(unique_username)],
        ),
    ],
    error_slot: fn (_ string, _ []gui.FormIssue) gui.View {
        return gui.text(text: "username: username required")
    },
)
```

## Key Properties

| Property | Type | Description |
|----------|------|-------------|
| id | string | Stable form runtime key (required) |
| validate_on | FormValidateOn | Default trigger (`change`, `blur_submit`, `submit`) |
| block_submit_when_invalid | bool | Prevent submit callback when invalid |
| block_submit_when_pending | bool | Prevent submit callback while async runs |
| error_slot | fn (string, []FormIssue) View | Per-field error rendering |
| summary_slot | fn (FormSummaryState) View | Aggregate error rendering |
| pending_slot | fn (FormPendingState) View | Pending field rendering |

## Field Adapter Properties

Available on `input` and `numeric_input`:

- `field_id string`
- `form_sync_validators []FormSyncValidator`
- `form_async_validators []FormAsyncValidator`
- `form_validate_on FormValidateOn` (`.inherit` uses form default)
- `form_initial_value ?string`

## Window Helpers

- `window.form_submit(form_id)`
- `window.form_reset(form_id)`
- `window.form_summary(form_id)`
- `window.form_field_state(form_id, field_id)`

See also: docs/FORMS.md'

fn demo_numeric_input(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.spacing_medium
		sizing:  gui.fill_fit
		content: [
			// en_US with step buttons
			gui.text(text: 'Default (en_US)', text_style: gui.theme().b1),
			gui.numeric_input(
				id:              'num_en'
				id_focus:        9170
				text:            app.numeric_en_text
				value:           app.numeric_en_value
				decimals:        2
				min:             0.0
				max:             10000.0
				width:           220
				sizing:          gui.fixed_fit
				on_text_changed: fn (_ &gui.Layout, text string, mut w gui.Window) {
					mut s := w.state[ShowcaseApp]()
					s.numeric_en_text = text
				}
				on_value_commit: fn (_ &gui.Layout, value ?f64, text string, mut w gui.Window) {
					mut s := w.state[ShowcaseApp]()
					s.numeric_en_value = value
					s.numeric_en_text = text
				}
			),
			gui.text(
				text: 'Committed: ${showcase_numeric_value_text(app.numeric_en_value)}'
			),
			// de_DE locale
			gui.text(text: 'German (de_DE)', text_style: gui.theme().b1),
			gui.numeric_input(
				id:              'num_de'
				id_focus:        9171
				text:            app.numeric_de_text
				value:           app.numeric_de_value
				decimals:        2
				locale:          gui.NumericLocaleCfg{
					decimal_sep: `,`
					group_sep:   `.`
				}
				min:             0.0
				max:             10000.0
				width:           220
				sizing:          gui.fixed_fit
				on_text_changed: fn (_ &gui.Layout, text string, mut w gui.Window) {
					mut s := w.state[ShowcaseApp]()
					s.numeric_de_text = text
				}
				on_value_commit: fn (_ &gui.Layout, value ?f64, text string, mut w gui.Window) {
					mut s := w.state[ShowcaseApp]()
					s.numeric_de_value = value
					s.numeric_de_text = text
				}
			),
			gui.text(
				text: 'Committed: ${showcase_numeric_value_text(app.numeric_de_value)}'
			),
			// Currency mode
			gui.text(text: 'Currency mode', text_style: gui.theme().b1),
			gui.numeric_input(
				id:              'num_currency'
				id_focus:        9173
				text:            app.numeric_currency_text
				value:           app.numeric_currency_value
				mode:            .currency
				decimals:        2
				min:             0.0
				max:             10000.0
				width:           220
				sizing:          gui.fixed_fit
				on_text_changed: fn (_ &gui.Layout, text string, mut w gui.Window) {
					mut s := w.state[ShowcaseApp]()
					s.numeric_currency_text = text
				}
				on_value_commit: fn (_ &gui.Layout, value ?f64, text string, mut w gui.Window) {
					mut s := w.state[ShowcaseApp]()
					s.numeric_currency_value = value
					s.numeric_currency_text = text
				}
			),
			gui.text(
				text: 'Committed: ${showcase_numeric_value_text(app.numeric_currency_value)}'
			),
			// Percent mode (ratio value)
			gui.text(text: 'Percent mode (ratio value)', text_style: gui.theme().b1),
			gui.numeric_input(
				id:              'num_percent'
				id_focus:        9174
				text:            app.numeric_percent_text
				value:           app.numeric_percent_value
				mode:            .percent
				decimals:        2
				min:             0.0
				max:             1.0
				width:           220
				sizing:          gui.fixed_fit
				on_text_changed: fn (_ &gui.Layout, text string, mut w gui.Window) {
					mut s := w.state[ShowcaseApp]()
					s.numeric_percent_text = text
				}
				on_value_commit: fn (_ &gui.Layout, value ?f64, text string, mut w gui.Window) {
					mut s := w.state[ShowcaseApp]()
					s.numeric_percent_value = value
					s.numeric_percent_text = text
				}
			),
			gui.text(
				text: 'Committed ratio: ${showcase_numeric_value_text(app.numeric_percent_value)}'
			),
			// No buttons, integer
			gui.text(text: 'No buttons (integer)', text_style: gui.theme().b1),
			gui.numeric_input(
				id:              'num_plain'
				id_focus:        9172
				text:            app.numeric_plain_text
				value:           app.numeric_plain_value
				decimals:        0
				step_cfg:        gui.NumericStepCfg{
					show_buttons: false
				}
				width:           220
				sizing:          gui.fixed_fit
				on_text_changed: fn (_ &gui.Layout, text string, mut w gui.Window) {
					mut s := w.state[ShowcaseApp]()
					s.numeric_plain_text = text
				}
				on_value_commit: fn (_ &gui.Layout, value ?f64, text string, mut w gui.Window) {
					mut s := w.state[ShowcaseApp]()
					s.numeric_plain_value = value
					s.numeric_plain_text = text
				}
			),
			gui.text(
				text: 'Committed: ${showcase_numeric_value_text(app.numeric_plain_value)}'
			),
		]
	)
}

fn showcase_numeric_value_text(value ?f64) string {
	if v := value {
		return '${v:.2f}'
	}
	return 'none'
}

fn demo_forms(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	form_summary := w.form_summary(showcase_form_id)
	username_state := w.form_field_state(showcase_form_id, 'username') or { gui.FormFieldState{} }
	email_state := w.form_field_state(showcase_form_id, 'email') or { gui.FormFieldState{} }
	age_state := w.form_field_state(showcase_form_id, 'age') or { gui.FormFieldState{} }
	return gui.column(
		spacing: gui.spacing_medium
		sizing:  gui.fill_fit
		content: [
			gui.form(
				id:                        showcase_form_id
				validate_on:               .blur_submit
				block_submit_when_invalid: true
				block_submit_when_pending: true
				error_slot:                showcase_forms_error_slot
				summary_slot:              showcase_forms_summary_slot
				pending_slot:              showcase_forms_pending_slot
				on_submit:                 showcase_forms_on_submit
				on_reset:                  showcase_forms_on_reset
				content:                   [
					showcase_forms_field('Username', gui.input(
						id:                    'showcase_forms_username'
						id_focus:              9180
						width:                 260
						sizing:                gui.fixed_fit
						text:                  app.form_username
						placeholder:           'username'
						field_id:              'username'
						form_sync_validators:  [
							gui.FormSyncValidator(showcase_forms_username_required),
							gui.FormSyncValidator(showcase_forms_username_len),
						]
						form_async_validators: [
							gui.FormAsyncValidator(showcase_forms_username_unique),
						]
						on_text_changed:       fn (_ &gui.Layout, s string, mut w gui.Window) {
							w.state[ShowcaseApp]().form_username = s
						}
					)),
					showcase_forms_state('Username', username_state),
					showcase_forms_field('Email', gui.input(
						id:                   'showcase_forms_email'
						id_focus:             9181
						width:                260
						sizing:               gui.fixed_fit
						text:                 app.form_email
						placeholder:          'user@example.com'
						field_id:             'email'
						form_sync_validators: [
							gui.FormSyncValidator(showcase_forms_email_required),
							gui.FormSyncValidator(showcase_forms_email_shape),
						]
						on_text_changed:      fn (_ &gui.Layout, s string, mut w gui.Window) {
							w.state[ShowcaseApp]().form_email = s
						}
					)),
					showcase_forms_state('Email', email_state),
					showcase_forms_field('Age', gui.numeric_input(
						id:                   'showcase_forms_age'
						id_focus:             9182
						width:                120
						sizing:               gui.fixed_fit
						decimals:             0
						min:                  0
						max:                  120
						text:                 app.form_age_text
						value:                app.form_age_value
						field_id:             'age'
						form_sync_validators: [
							gui.FormSyncValidator(showcase_forms_age_required),
						]
						on_text_changed:      fn (_ &gui.Layout, text string, mut w gui.Window) {
							w.state[ShowcaseApp]().form_age_text = text
						}
						on_value_commit:      fn (_ &gui.Layout, value ?f64, text string, mut w gui.Window) {
							mut state := w.state[ShowcaseApp]()
							state.form_age_value = value
							state.form_age_text = text
						}
					)),
					showcase_forms_state('Age', age_state),
				]
			),
			gui.row(
				spacing: gui.spacing_small
				content: [
					gui.button(
						content:  [
							gui.text(text: gui_locale.str_submit),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.form_submit(showcase_form_id)
						}
					),
					gui.button(
						content:  [
							gui.text(text: gui_locale.str_reset),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.form_reset(showcase_form_id)
						}
					),
				]
			),
			gui.text(
				text: 'Summary: valid=${form_summary.valid} pending=${form_summary.pending} invalid=${form_summary.invalid_count}'
			),
			gui.text(
				text: if app.form_submit_msg.len > 0 {
					app.form_submit_msg
				} else {
					'Submit form to view committed values'
				}
			),
		]
	)
}

fn showcase_forms_field(label string, field gui.View) gui.View {
	return gui.row(
		padding: gui.padding_none
		v_align: .middle
		spacing: gui.spacing_small
		content: [
			gui.text(
				text:      label
				min_width: 90
			),
			field,
		]
	)
}

fn showcase_forms_state(label string, state gui.FormFieldState) gui.View {
	return gui.text(
		text:       '${label}: touched=${state.touched}, dirty=${state.dirty}, pending=${state.pending}'
		text_style: gui.theme().n5
	)
}

fn showcase_forms_error_slot(field_id string, issues []gui.FormIssue) gui.View {
	if issues.len == 0 {
		return gui.text(text: '')
	}
	return gui.text(
		text:       '${field_id}: ${issues[0].msg}'
		text_style: gui.TextStyle{
			...gui.theme().text_style
			color: gui.rgb(219, 87, 87)
		}
	)
}

fn showcase_forms_summary_slot(summary gui.FormSummaryState) gui.View {
	if summary.invalid_count == 0 && !summary.pending {
		return gui.text(text: '')
	}
	return gui.text(
		text: 'Validation summary: invalid=${summary.invalid_count}, pending=${summary.pending_count}'
	)
}

fn showcase_forms_pending_slot(pending gui.FormPendingState) gui.View {
	if pending.pending_count == 0 {
		return gui.text(text: '')
	}
	return gui.text(text: 'Validating: ${pending.field_ids.join(', ')}')
}

fn showcase_forms_on_submit(ev gui.FormSubmitEvent, mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	app.form_submit_msg = 'Submitted username=${ev.values['username'] or { '' }}, email=${ev.values['email'] or {
		''
	}}'
}

fn showcase_forms_on_reset(_ gui.FormResetEvent, mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	app.form_username = ''
	app.form_email = ''
	app.form_age_text = ''
	app.form_age_value = none
	app.form_submit_msg = 'Form reset'
}

fn showcase_forms_username_required(field gui.FormFieldSnapshot, _ gui.FormSnapshot) []gui.FormIssue {
	if field.value.trim_space().len == 0 {
		return [gui.FormIssue{
			code: 'required'
			msg:  'username required'
		}]
	}
	return []gui.FormIssue{}
}

fn showcase_forms_username_len(field gui.FormFieldSnapshot, _ gui.FormSnapshot) []gui.FormIssue {
	value := field.value.trim_space()
	if value.len > 0 && value.len < 3 {
		return [gui.FormIssue{
			code: 'min_len'
			msg:  'username min length is 3'
		}]
	}
	return []gui.FormIssue{}
}

fn showcase_forms_username_unique(field gui.FormFieldSnapshot, _ gui.FormSnapshot, signal &gui.GridAbortSignal) ![]gui.FormIssue {
	for _ in 0 .. 4 {
		if signal.is_aborted() {
			return []gui.FormIssue{}
		}
		time.sleep(60 * time.millisecond)
	}
	name := field.value.trim_space().to_lower()
	if name in ['admin', 'root', 'system'] {
		return [gui.FormIssue{
			code: 'taken'
			msg:  'username already taken'
		}]
	}
	return []gui.FormIssue{}
}

fn showcase_forms_email_required(field gui.FormFieldSnapshot, _ gui.FormSnapshot) []gui.FormIssue {
	if field.value.trim_space().len == 0 {
		return [gui.FormIssue{
			code: 'required'
			msg:  'email required'
		}]
	}
	return []gui.FormIssue{}
}

fn showcase_forms_email_shape(field gui.FormFieldSnapshot, _ gui.FormSnapshot) []gui.FormIssue {
	email := field.value.trim_space()
	if email.len > 0 && !email.contains('@') {
		return [gui.FormIssue{
			code: 'format'
			msg:  'email must contain @'
		}]
	}
	return []gui.FormIssue{}
}

fn showcase_forms_age_required(field gui.FormFieldSnapshot, _ gui.FormSnapshot) []gui.FormIssue {
	if field.value.trim_space().len == 0 {
		return [gui.FormIssue{
			code: 'required'
			msg:  'age required'
		}]
	}
	return []gui.FormIssue{}
}
