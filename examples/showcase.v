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
const id_focus_showcase_splitter_main = u32(9160)
const id_focus_showcase_splitter_detail = u32(9161)

@[heap]
struct ShowcaseApp {
pub mut:
	light_theme        bool
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
	numeric_en_text     string = '1,234.50'
	numeric_en_value    ?f64   = 1234.5
	numeric_de_text     string = '1.234,50'
	numeric_de_value    ?f64   = 1234.5
	numeric_plain_text  string
	numeric_plain_value ?f64
	// select
	selected_1 []string
	selected_2 []string
	// tree view
	tree_id string
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
	// radio
	select_radio bool
	// expand_pad
	open_expand_panel bool
	// Date Pickers
	date_picker_dates []time.Time
	input_date        time.Time = time.now()
	roller_date       time.Time = time.now()
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
	// Animations
	anim_tween_x         f32
	anim_spring_x        f32
	anim_keyframe_x      f32
	anim_layout_expanded bool
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
		width:        900
		height:       600
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
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
			key:   'foundations'
			label: 'Foundations'
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
			group:   'data'
			summary: 'Render local or remote image assets'
			tags:    ['photo', 'asset', 'media']
		},
		DemoEntry{
			id:      'markdown'
			label:   'Markdown'
			group:   'data'
			summary: 'Render markdown into styled rich content'
			tags:    ['docs', 'text', 'rich']
		},
		DemoEntry{
			id:      'rectangle'
			label:   'Rectangle'
			group:   'data'
			summary: 'Draw colored shapes with border and radius'
			tags:    ['shape', 'primitive', 'box']
		},
		DemoEntry{
			id:      'rtf'
			label:   'Rich Text Format'
			group:   'data'
			summary: 'Mixed styles, links, and inline rich runs'
			tags:    ['rich text', 'link', 'style']
		},
		DemoEntry{
			id:      'svg'
			label:   'SVG'
			group:   'data'
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
			id:      'text'
			label:   'Text'
			group:   'data'
			summary: 'Theme typography sizes, weights, and styles'
			tags:    ['font', 'type', 'styles']
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
			group:   'foundations'
			summary: 'Export current view to PDF and open native print dialog'
			tags:    ['print', 'pdf', 'export']
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
			id:      'tooltip'
			label:   'Tooltip'
			group:   'overlays'
			summary: 'Hover hints with custom placement and content'
			tags:    ['hover', 'hint', 'floating']
		},
		DemoEntry{
			id:      'animations'
			label:   'Animations'
			group:   'foundations'
			summary: 'Tween, spring, and layout transition samples'
			tags:    ['motion', 'tween', 'spring']
		},
		DemoEntry{
			id:      'gradient'
			label:   'Gradients'
			group:   'foundations'
			summary: 'Linear and radial gradient fills'
			tags:    ['linear', 'radial', 'fill']
		},
		DemoEntry{
			id:      'box_shadows'
			label:   'Box Shadows'
			group:   'foundations'
			summary: 'Shadow presets with spread_radius behavior notes'
			tags:    ['shadow', 'depth', 'spread_radius']
		},
		DemoEntry{
			id:      'shader'
			label:   'Custom Shaders'
			group:   'foundations'
			summary: 'Custom fragment shaders for dynamic fills'
			tags:    ['shader', 'glsl', 'metal']
		},
		DemoEntry{
			id:      'icons'
			label:   'Icons'
			group:   'foundations'
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
	if group == 'data' && has_entry(entries, 'data_grid') {
		return 'data_grid'
	}
	return entries[0].id
}

fn catalog_panel(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	entries := filtered_entries(app)
	if entries.len == 0 {
		app.selected_component = ''
	} else if !has_entry(entries, app.selected_component) {
		app.selected_component = preferred_component_for_group(app.selected_group, entries)
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
			toggle_theme(app),
		]
	)
}

fn group_picker(app &ShowcaseApp) gui.View {
	return gui.column(
		spacing: 3
		padding: gui.padding_none
		content: [
			gui.row(
				spacing: 3
				padding: gui.padding_none
				content: [
					group_picker_item('Welcome', 'welcome', app),
					group_picker_item('All', 'all', app),
					group_picker_item('Input', 'input', app),
					group_picker_item('Selection', 'selection', app),
				]
			),
			gui.row(
				spacing: 3
				padding: gui.padding_none
				content: [
					group_picker_item('Data', 'data', app),
					group_picker_item('Nav', 'navigation', app),
					group_picker_item('Feedback', 'feedback', app),
				]
			),
			gui.row(
				spacing: 3
				padding: gui.padding_none
				content: [
					group_picker_item('Overlays', 'overlays', app),
					group_picker_item('Foundations', 'foundations', app),
				]
			),
		]
	)
}

fn group_picker_item(label string, key string, app &ShowcaseApp) gui.View {
	is_selected := app.selected_group == key
	return gui.row(
		padding:  if is_selected {
			gui.padding(3, 6, 3, 6)
		} else {
			gui.padding(2, 5, 2, 5)
		}
		color:    if is_selected {
			gui.theme().color_active
		} else {
			gui.theme().color_background
		}
		radius:   3
		content:  [gui.text(text: label, text_style: gui.theme().n5)]
		on_click: fn [key] (_ voidptr, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.selected_group = key
			if key == 'data' {
				entries := filtered_entries(app)
				app.selected_component = preferred_component_for_group(key, entries)
			}
			w.scroll_vertical_to(id_scroll_catalog, 0)
			w.update_window()
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
		on_click: fn [entry] (_ voidptr, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.selected_component = entry.id
			w.scroll_vertical_to(id_scroll_gallery, 0)
			w.update_window()
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
	content << view_title(entry.label)
	content << gui.text(text: entry.summary, text_style: gui.theme().n3)
	content << component_demo(mut w, entry.id)
	content << line()
	content << gui.text(
		text:       'Related examples: ${related_examples(entry.id)}'
		text_style: gui.theme().n5
	)
	return gui.column(
		id_scroll:       id_scroll_gallery
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
		'select' { demo_select(w) }
		'listbox' { demo_list_box(mut w) }
		'range_slider' { demo_range_slider(w) }
		'progress_bar' { demo_progress_bar(w) }
		'pulsar' { demo_pulsar(mut w) }
		'menus' { demo_menu(mut w) }
		'dialog' { demo_dialog() }
		'tree' { demo_tree(mut w) }
		'printing' { demo_printing(w) }
		'text' { demo_text() }
		'rtf' { demo_rtf() }
		'table' { demo_table(mut w) }
		'data_grid' { demo_data_grid(mut w) }
		'date_picker' { demo_date_picker(mut w) }
		'input_date' { demo_input_date(mut w) }
		'numeric_input' { demo_numeric_input(w) }
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
		'markdown' { demo_markdown(mut w) }
		'tab_control' { demo_tab_control(w) }
		'tooltip' { demo_tooltip() }
		'rectangle' { demo_rectangle() }
		'scrollbar' { demo_scrollbar() }
		'splitter' { demo_splitter(w) }
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
		'select' { 'examples/select_demo.v' }
		'listbox' { 'examples/listbox.v' }
		'range_slider' { 'examples/range_sliders.v' }
		'progress_bar' { 'examples/progress_bars.v' }
		'pulsar' { 'examples/pulsars.v' }
		'menus' { 'examples/menu_demo.v, examples/context_menu_demo.v' }
		'dialog' { 'examples/dialogs.v' }
		'tree' { 'examples/tree_view.v' }
		'printing' { 'examples/printing.v' }
		'text' { 'examples/fonts.v, examples/system_font.v' }
		'rtf' { 'examples/rtf.v' }
		'table' { 'examples/table_demo.v' }
		'data_grid' { 'examples/data_grid_demo.v, docs/DATA_GRID.md' }
		'numeric_input' { 'examples/numeric_input.v' }
		'date_picker', 'input_date' { 'examples/date_picker_options.v, examples/date_time.v' }
		'date_picker_roller' { 'examples/date_picker_roller.v' }
		'svg' { 'examples/svg_demo.v, examples/tiger.v' }
		'image' { 'examples/image_demo.v, examples/remote_image.v' }
		'expand_panel' { 'examples/expand_panel.v' }
		'icons' { 'examples/icon_font_demo.v' }
		'gradient' { 'examples/gradient_demo.v, examples/gradient_border_demo.v' }
		'box_shadows' { 'examples/shadow_demo.v, examples/theme_designer.v' }
		'shader' { 'examples/custom_shader.v' }
		'animations' { 'examples/animations.v, examples/animation_stress.v' }
		'color_picker' { 'examples/color_picker.v' }
		'markdown' { 'examples/markdown.v, examples/doc_viewer.v' }
		'tab_control' { 'examples/tab_view.v' }
		'tooltip' { 'examples/tooltips.v' }
		'rectangle' { 'examples/border_demo.v, examples/gradient_border_demo.v' }
		'scrollbar' { 'examples/scroll_demo.v, examples/column_scroll.v' }
		'splitter' { 'examples/split_panel.v' }
		else { 'examples/showcase.v' }
	}
}

fn view_title(label string) gui.View {
	return gui.column(
		spacing: 0
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.text(text: label, text_style: gui.theme().b1),
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

fn toggle_theme(app &ShowcaseApp) gui.View {
	return gui.toggle(
		text_select:   gui.icon_moon
		text_unselect: gui.icon_sunny_o
		text_style:    gui.theme().icon3
		padding:       gui.padding_small
		min_width:     16
		select:        app.light_theme
		on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.light_theme = !app.light_theme
			theme := if app.light_theme {
				gui.theme_light_bordered
			} else {
				gui.theme_dark_bordered
			}
			w.set_theme(theme)
		}
	)
}

// ==============================================================
// Buttons
// ==============================================================

fn button_feature_rows(app &ShowcaseApp, base_focus u32) []gui.View {
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
const tiger_svg_path = os.join_path(os.dir(@FILE), 'tiger.svg')
const missing_svg_path = os.join_path(os.dir(@FILE), 'missing-icon.svg')

const sample_image_path = os.join_path(os.dir(@FILE), 'sample.jpeg')

fn on_select(id string, mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	app.tree_id = id
}

fn tree_view_sample(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			gui.text(text: '[ ${app.tree_id} ]'),
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
					gui.tree_node(
						text:  'Insects'
						icon:  gui.icon_bug
						nodes: [
							gui.tree_node(text: 'Butterfly'),
							gui.tree_node(text: 'House Fly'),
							gui.tree_node(text: 'Locust'),
							gui.tree_node(text: 'Moth'),
						]
					),
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
				content: button_feature_rows(app, 9100)
			),
		]
	)
}

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
								no_wrap:         true
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
								min_width:   280
								max_width:   280
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

fn demo_pulsar(mut w gui.Window) gui.View {
	return gui.row(
		content: [
			w.pulsar(),
			w.pulsar(size: 20),
			w.pulsar(size: 28, color: gui.orange),
		]
	)
}

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
				result.paths.join('\n')
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

fn demo_tree(mut w gui.Window) gui.View {
	return tree_view_sample(mut w)
}

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
							result := w.export_pdf(gui.PdfExportCfg{
								path: path
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
							w.native_print_dialog(
								title:   'Showcase Print Current View'
								content: gui.NativePrintContent{
									kind: .current_view_pdf
								}
								on_done: fn (result gui.NativePrintResult, mut w gui.Window) {
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
							)
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
							w.native_print_dialog(
								title:   'Showcase Print Existing PDF'
								content: gui.NativePrintContent{
									kind:     .prepared_pdf_path
									pdf_path: path
								}
								on_done: fn (result gui.NativePrintResult, mut w gui.Window) {
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
							)
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
		]
	)
}

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
			gui.text(text: 'File-based SVG (small)', text_style: gui.theme().b4),
			gui.row(
				v_align: .middle
				content: [
					gui.svg(
						file_name: tiger_svg_path
						width:     84
						height:    84
					),
					gui.text(text: 'Read from `tiger.svg`'),
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

fn demo_image() gui.View {
	return gui.column(
		padding: gui.padding_none
		content: [
			gui.image(src: sample_image_path),
			gui.text(text: 'Pinard Falls, Oregon', text_style: gui.theme().n4),
		]
	)
}

fn demo_expand_panel(w &gui.Window) gui.View {
	return expand_panel_sample(w)
}

fn demo_icons() gui.View {
	return gui.row(
		content: [
			gui.text(text: gui.icon_github_alt, text_style: gui.theme().icon2),
			gui.text(text: gui.icon_twitter, text_style: gui.theme().icon2),
			gui.text(text: gui.icon_bug, text_style: gui.theme().icon2),
			gui.text(text: gui.icon_heart, text_style: gui.theme().icon2),
		]
	)
}

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
	return gui.row(
		spacing: gui.theme().spacing_large
		content: [
			gui.column(
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
			gui.column(
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

fn demo_animations(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	box_color := if app.light_theme { gui.dark_blue } else { gui.cornflower_blue }
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
