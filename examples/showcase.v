import gui
import encoding.csv
import math
import os
import time

// Showcase
// =============================
// Oh majeuere, dim the lights...

const id_scroll_gallery = 1
const id_scroll_list_box = 2
const id_scroll_catalog = 3
const id_scroll_sync_demo = 4

enum TabItem {
	tab_stock = 1000
	tab_icons
	tab_svg
	tab_image
	tab_menus
	tab_dialogs
	tab_tree_view
	tab_text_view
	tab_table_view
	tab_date_pickers
	tab_animations
}

@[heap]
struct ShowcaseApp {
pub mut:
	light_theme        bool
	selected_tab       TabItem = .tab_stock
	nav_query          string
	selected_group     string = 'all'
	selected_component string = 'button'
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
	// range sliders
	range_value f32 = 50
	// select
	selected_1 []string
	selected_2 []string
	// tree view
	tree_id string
	// list Box
	list_box_multiple_select bool
	list_box_selected_values []string
	// radio
	select_radio bool
	// expand_pad
	open_expand_panel bool
	// Tables
	csv_table TableData
	// Date Pickers
	date_picker_dates []time.Time
	input_date        time.Time = time.now()
	roller_date       time.Time = time.now()
	// tab control
	tab_selected string = 'overview'
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
	anim_layout_expanded bool
}

struct DemoEntry {
	id      string
	label   string
	group   string
	summary string
	tags    []string
}

@[heap]
struct TableData {
pub mut:
	sort_by  int // 1's based sort column index. -sort_by = descending order, 0 == unsorted
	sorted   [][]string
	unsorted [][]string
}

fn main() {
	mut window := gui.window(
		title:        'Gui Showcase'
		state:        &ShowcaseApp{}
		width:        900
		height:       600
		cursor_blink: true
		on_init:      fn (mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.csv_table = get_table_data() or { panic(err.msg()) }
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

fn catalog_panel(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	entries := filtered_entries(app)
	if entries.len == 0 {
		app.selected_component = ''
	} else if !has_entry(entries, app.selected_component) {
		app.selected_component = entries[0].id
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
				id_scroll: id_scroll_catalog
				sizing:    gui.fill_fill
				spacing:   2
				padding:   gui.padding_none
				content:   catalog_rows(entries, app)
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
					group_picker_item('All', 'all', app),
					group_picker_item('Input', 'input', app),
					group_picker_item('Selection', 'selection', app),
					group_picker_item('Data', 'data', app),
				]
			),
			gui.row(
				spacing: 3
				padding: gui.padding_none
				content: [
					group_picker_item('Nav', 'navigation', app),
					group_picker_item('Feedback', 'feedback', app),
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
		mut group_rows := []gui.View{}
		for entry in entries {
			if entry.group == group.key {
				group_rows << catalog_row(entry, app)
			}
		}
		if group_rows.len == 0 {
			continue
		}
		if rows.len > 0 {
			rows << gui.row(
				height:  6
				sizing:  gui.fill_fixed
				padding: gui.padding_none
			)
		}
		rows << gui.text(text: group.label, text_style: gui.theme().b5)
		for row in group_rows {
			rows << row
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
			padding:         gui.theme().padding_large
			content:         [
				gui.text(text: 'No component matches filter', text_style: gui.theme().b2),
			]
		)
	}
	if !has_entry(entries, app.selected_component) {
		app.selected_component = entries[0].id
	}
	entry := selected_entry(entries, app.selected_component)
	mut content := []gui.View{}
	content << view_title(entry.label)
	content << gui.text(text: entry.summary, text_style: gui.theme().n3)
	content << gui.text(text: 'Group: ${entry.group}', text_style: gui.theme().n5)
	content << basic_demo(mut w, entry.id)
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
		padding:         gui.theme().padding_large
		spacing:         gui.spacing_large
		content:         content
	)
}

fn basic_demo(mut w gui.Window, id string) gui.View {
	return match id {
		'button' { basic_button_demo(mut w) }
		'input' { basic_input_demo(w) }
		'toggle' { basic_toggle_demo(w) }
		'switch' { basic_switch_demo(w) }
		'radio' { basic_radio_demo(w) }
		'radio_group' { basic_radio_group_demo(w) }
		'select' { basic_select_demo(w) }
		'listbox' { basic_list_box_demo(w) }
		'range_slider' { basic_range_slider_demo(w) }
		'progress_bar' { basic_progress_bar_demo(w) }
		'pulsar' { basic_pulsar_demo(mut w) }
		'menus' { basic_menu_demo(mut w) }
		'dialog' { basic_dialog_demo() }
		'tree' { basic_tree_demo(mut w) }
		'text' { basic_text_demo() }
		'rtf' { basic_rtf_demo() }
		'table' { basic_table_demo(mut w) }
		'date_picker' { basic_date_picker_demo(mut w) }
		'input_date' { basic_input_date_demo(mut w) }
		'date_picker_roller' { basic_date_picker_roller_demo(mut w) }
		'svg' { basic_svg_demo() }
		'image' { basic_image_demo() }
		'expand_panel' { basic_expand_panel_demo(w) }
		'icons' { basic_icons_demo() }
		'animations' { basic_animations_demo(mut w) }
		'color_picker' { basic_color_picker_demo(w) }
		'markdown' { basic_markdown_demo(mut w) }
		'tab_control' { basic_tab_control_demo(w) }
		'tooltip' { basic_tooltip_demo() }
		'rectangle' { basic_rectangle_demo() }
		'scrollbar' { basic_scrollbar_demo() }
		else { gui.text(text: 'No demo configured') }
	}
}

fn related_examples(id string) string {
	return match id {
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
		'text' { 'examples/fonts.v, examples/system_font.v' }
		'rtf' { 'examples/rtf.v' }
		'table' { 'examples/table_demo.v' }
		'date_picker', 'input_date' { 'examples/date_picker_options.v, examples/date_time.v' }
		'date_picker_roller' { 'examples/date_picker_roller.v' }
		'svg' { 'examples/svg_demo.v, examples/tiger.v' }
		'image' { 'examples/image_demo.v, examples/remote_image.v' }
		'expand_panel' { 'examples/expand_panel.v' }
		'icons' { 'examples/icon_font_demo.v' }
		'animations' { 'examples/animations.v, examples/animation_stress.v' }
		'color_picker' { 'examples/color_picker.v' }
		'markdown' { 'examples/markdown.v, examples/doc_viewer.v' }
		'tab_control' { 'examples/tab_view.v' }
		'tooltip' { 'examples/tooltips.v' }
		'rectangle' { 'examples/border_demo.v, examples/gradient_border_demo.v' }
		'scrollbar' { 'examples/scroll_demo.v, examples/column_scroll.v' }
		else { 'examples/showcase.v' }
	}
}

fn side_bar(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	return gui.column(
		color:   gui.theme().color_panel
		sizing:  gui.fit_fill
		content: [
			tab_select('Stock', .tab_stock, app),
			tab_select('Icons', .tab_icons, app),
			tab_select('SVG', .tab_svg, app),
			tab_select('Image', .tab_image, app),
			tab_select('Menus', .tab_menus, app),
			tab_select('Dialogs', .tab_dialogs, app),
			tab_select('Tree View', .tab_tree_view, app),
			tab_select('Text', .tab_text_view, app),
			tab_select('Tables', .tab_table_view, app),
			tab_select('Date Pickers', .tab_date_pickers, app),
			tab_select('Animations', .tab_animations, app),
			gui.column(sizing: gui.fit_fill),
			toggle_theme(app),
		]
	)
}

fn gallery(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	return gui.column(
		id_scroll:       id_scroll_gallery
		scrollbar_cfg_y: &gui.ScrollbarCfg{
			gap_edge: 4
		}
		sizing:          gui.fill_fill
		spacing:         gui.spacing_large * 2
		content:         match app.selected_tab {
			.tab_stock {
				[buttons(w), inputs(w), toggles(w), select_drop_down(w),
					list_box(w), expand_panel(w), progress_bars(w),
					range_sliders(w), pulsars(mut w)]
			}
			.tab_icons {
				[icons(mut w)]
			}
			.tab_svg {
				[svg_icons(mut w)]
			}
			.tab_image {
				[image_sample(w)]
			}
			.tab_menus {
				[menus(mut w)]
			}
			.tab_dialogs {
				[dialogs(w)]
			}
			.tab_tree_view {
				[tree_view(mut w)]
			}
			.tab_text_view {
				[text_sizes_weights(w), rich_text_format(w)]
			}
			.tab_table_view {
				[tables(mut w)]
			}
			.tab_date_pickers {
				[date_pickers(mut w)]
			}
			.tab_animations {
				[animations(mut w)]
			}
		}
	)
}

fn tab_select(label string, tab_item TabItem, app &ShowcaseApp) gui.View {
	color := if app.selected_tab == tab_item {
		gui.theme().color_active
	} else {
		gui.color_transparent
	}
	return gui.row(
		color:    color
		padding:  gui.theme().padding_small
		content:  [gui.text(text: label, text_style: gui.theme().n2)]
		on_click: fn [tab_item] (_ voidptr, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.selected_tab = tab_item
			w.update_view(main_view)
		}
		on_hover: fn (mut layout gui.Layout, mut _ gui.Event, mut w gui.Window) {
			layout.shape.color = gui.theme().color_hover
			w.set_mouse_cursor_pointing_hand()
		}
	)
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

fn buttons(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	color := if app.light_theme { gui.light_gray } else { gui.dark_blue }
	color_left := if app.light_theme { gui.dark_gray } else { gui.dark_green }
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Buttons'),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .bottom
				content: [
					gui.button(
						id_focus:    100
						size_border: 0
						content:     [gui.text(text: 'No Border')]
					),
					gui.button(
						id_focus:    101
						size_border: 1
						content:     [gui.text(text: 'Thin Border')]
					),
					gui.button(
						id_focus:    102
						size_border: 2
						content:     [gui.text(text: 'Thicker Border')]
					),
					gui.button(
						id_focus:    103
						size_border: 2
						disabled:    true
						content:     [gui.text(text: 'Disabled')]
					),
					gui.button(
						id_focus:    104
						size_border: 2

						on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.button_clicks += 1
						}
						content:  [
							gui.column(
								spacing: gui.spacing_small
								padding: gui.padding_none
								h_align: .center
								content: [
									gui.text(
										text:       'Custom Content'
										text_style: gui.theme().n6
									),
									gui.progress_bar(
										color:      color
										color_bar:  color_left
										percent:    (app.button_clicks % 25) / f32(25)
										sizing:     gui.fill_fit
										text_style: gui.theme().m4
										height:     gui.theme().n3.size
									),
								]
							),
						]
					),
				]
			),
		]
	)
}

// ==============================================================
// Inputs
// ==============================================================

fn inputs(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Inputs'),
			gui.row(
				sizing:  gui.fill_fit
				content: [
					gui.input(
						id_focus:    200
						width:       150
						sizing:      gui.fixed_fit
						text:        app.input_text
						size_border: 0

						placeholder:     'Plain...'
						mode:            .single_line
						on_text_changed: text_changed
					),
					gui.input(
						id_focus:    201
						width:       150
						sizing:      gui.fixed_fit
						text:        app.input_text
						size_border: 1

						placeholder:     'Thin Border...'
						mode:            .single_line
						on_text_changed: text_changed
					),
					gui.input(
						id_focus:    202
						width:       150
						sizing:      gui.fixed_fit
						text:        app.input_text
						size_border: 2

						placeholder:     'Thicker Border...'
						mode:            .single_line
						on_text_changed: text_changed
					),
					gui.input(
						id_focus:    203
						width:       150
						sizing:      gui.fixed_fit
						text:        app.input_text
						size_border: 1

						placeholder:     'Password...'
						is_password:     true
						mode:            .single_line
						on_text_changed: text_changed
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				v_align: .middle
				content: [
					gui.text(text: 'Multiline Text Input:'),
					gui.input(
						id_focus:    204
						width:       300
						sizing:      gui.fixed_fit
						text:        app.input_multiline
						size_border: 1

						placeholder:     'Multiline...'
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

fn text_changed(_ &gui.Layout, s string, mut w gui.Window) {
	mut app := w.state[ShowcaseApp]()
	app.input_text = s
}

// ==============================================================
// Toggles
// ==============================================================

fn toggles(w &gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	options := [
		gui.radio_option('New York', 'ny'),
		gui.radio_option('Chicago', 'chi'),
		gui.radio_option('Denver', 'den'),
		gui.radio_option('Los Angeles', 'la'),
	]

	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Toggle, Switch, and Radio Button Group'),
			gui.row(
				v_align: .middle
				content: [
					gui.toggle(
						label:    'toggle (a.k.a. checkbox)'
						select:   app.select_checkbox
						on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.select_checkbox = !app.select_checkbox
						}
					),
					gui.toggle(
						label:       'toggle with icon'
						select:      app.select_toggle
						text_select: gui.icon_github_alt
						text_style:  gui.theme().icon1
						on_click:    fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.select_toggle = !app.select_toggle
						}
					),
					gui.switch(
						label:    'switch'
						select:   app.select_switch
						on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.select_switch = !app.select_switch
						}
					),
				]
			),
			gui.row(
				content: [
					gui.radio_button_group_column(
						title:     'Time Zone'
						id_focus:  3000
						value:     app.select_city
						options:   options
						on_select: fn (value string, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.select_city = value
						}
					),
					// Intentionally using the same data/focus id to show vertical
					// and horizontal differences side-by-side
					gui.radio_button_group_row(
						title:     'Time Zone'
						id_focus:  3000
						value:     app.select_city
						options:   options
						on_select: fn (value string, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.select_city = value
						}
					),
				]
			),
		]
	)
}

// ==============================================================
// Dialogs
// ==============================================================

fn dialogs(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Dialogs'),
			gui.row(
				sizing:  gui.fill_fit
				content: [
					gui.row(
						padding: gui.padding_none
						content: [
							gui.column(
								padding: gui.padding_none
								content: [
									message_type(),
									confirm_type(),
								]
							),
							gui.column(
								padding: gui.padding_none
								content: [
									prompt_type(),
									custom_type(),
								]
							),
						]
					),
				]
			),
		]
	)
}

fn message_type() gui.View {
	return gui.button(
		id_focus: 1
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .message')]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				align_buttons: .end
				dialog_type:   .message
				title:         'Title Displays Here'
				body:          '
body text displays here...

Multi-line text supported.
See DialogCfg for other parameters

Buttons can be left/center/right aligned'.trim_indent()
			)
		}
	)
}

fn confirm_type() gui.View {
	return gui.button(
		id_focus: 2
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .confirm')]
		on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			w.dialog(
				dialog_type:  .confirm
				title:        'Destroy All Data?'
				body:         'Are you sure?'
				on_ok_yes:    fn (mut w gui.Window) {
					w.dialog(title: 'Clicked Yes')
				}
				on_cancel_no: fn (mut w gui.Window) {
					w.dialog(title: 'Clicked No')
				}
			)
		}
	)
}

fn prompt_type() gui.View {
	return gui.button(
		id_focus: 3
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .prompt')]
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
	)
}

fn custom_type() gui.View {
	return gui.button(
		id_focus: 4
		sizing:   gui.fill_fit
		content:  [gui.text(text: '.dialog_type == .custom')]
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
								content:  [gui.text(text: 'Close Me')]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									w.dialog_dismiss()
								}
							),
						]
					),
				]
			)
		}
	)
}

// ==============================================================
// Menu
// ==============================================================

fn menus(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Menus'),
			gui.column(
				sizing:  gui.fill_fit
				content: [
					menu(mut w),
					gui.text(
						text: if app.selected_menu_id !in ['', 'file', 'edit', 'view', 'go', 'window'] {
							'Selected: "${app.selected_menu_id}"'
						} else {
							''
						}
					),
				]
			),
		]
	)
}

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
// Progress Bars
// ==============================================================

fn progress_bars(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Progress Bars'),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				content: [progress_bar_samples(w)]
			),
		]
	)
}

fn progress_bar_samples(w &gui.Window) gui.View {
	tbg1 := if gui.theme().name.starts_with('light') { gui.orange } else { gui.dark_green }
	tbg2 := if gui.theme().name.starts_with('light') { gui.cornflower_blue } else { gui.white }

	app := w.state[ShowcaseApp]()
	percent := app.range_value / f32(100)

	return gui.column(
		spacing: gui.theme().spacing_large
		content: [
			gui.row(
				spacing: gui.theme().spacing_large
				content: [
					gui.column(
						width:   200
						spacing: 20
						sizing:  gui.fit_fill
						content: [
							gui.progress_bar(
								height:          2
								sizing:          gui.fill_fixed
								percent:         percent
								text_background: tbg1
							),
							gui.progress_bar(
								sizing:  gui.fill_fixed
								percent: percent
							),
							gui.progress_bar(
								height:  20
								sizing:  gui.fill_fixed
								percent: percent
							),
							gui.progress_bar(
								height:    20
								sizing:    gui.fill_fixed
								percent:   percent
								text_show: false
							),
						]
					),
					gui.row(
						width:   150
						height:  100
						spacing: 40
						sizing:  gui.fit_fill
						content: [
							gui.progress_bar(
								vertical:        true
								sizing:          gui.fixed_fill
								width:           2
								percent:         percent
								text_background: tbg2
							),
							gui.progress_bar(
								vertical: true
								sizing:   gui.fixed_fill
								percent:  percent
							),
							gui.progress_bar(
								vertical: true
								sizing:   gui.fixed_fill
								width:    20
								percent:  percent
							),
						]
					),
				]
			),
			gui.row(
				spacing: gui.theme().spacing_large
				content: [
					gui.column(
						width:   200
						spacing: 20
						sizing:  gui.fit_fill
						content: [
							gui.progress_bar(
								id:              'sc_pbar_indef_h1'
								height:          2
								sizing:          gui.fill_fixed
								indefinite:      true
								text_background: tbg1
							),
							gui.progress_bar(
								id:         'sc_pbar_indef_h2'
								sizing:     gui.fill_fixed
								indefinite: true
							),
							gui.progress_bar(
								id:         'sc_pbar_indef_h3'
								height:     20
								sizing:     gui.fill_fixed
								indefinite: true
							),
							gui.progress_bar(
								id:         'sc_pbar_indef_h4'
								height:     20
								sizing:     gui.fill_fixed
								indefinite: true
								text_show:  false
							),
						]
					),
					gui.row(
						width:   150
						height:  100
						spacing: 40
						sizing:  gui.fit_fill
						content: [
							gui.progress_bar(
								id:              'sc_pbar_indef_v1'
								vertical:        true
								sizing:          gui.fixed_fill
								width:           2
								indefinite:      true
								text_background: tbg2
							),
							gui.progress_bar(
								id:         'sc_pbar_indef_v2'
								vertical:   true
								sizing:     gui.fixed_fill
								indefinite: true
							),
							gui.progress_bar(
								id:         'sc_pbar_indef_v3'
								vertical:   true
								sizing:     gui.fixed_fill
								width:      20
								indefinite: true
							),
						]
					),
				]
			),
		]
	)
}

// ==============================================================
// List Box
// ==============================================================

fn list_box(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('List Box'),
			gui.row(
				sizing:  gui.fill_fit
				content: [list_box_sample(w)]
			),
		]
	)
}

fn list_box_sample(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.row(
		height:  250
		sizing:  gui.fit_fixed
		content: [
			gui.list_box(
				id_scroll: id_scroll_list_box
				multiple:  app.list_box_multiple_select
				selected:  app.list_box_selected_values
				sizing:    gui.fit_fill
				data:      [
					gui.list_box_option('---States', ''),
					gui.list_box_option('Alabama', 'AL'),
					gui.list_box_option('Alaska', 'AK'),
					gui.list_box_option('Arizona', 'AZ'),
					gui.list_box_option('Arkansas', 'AR'),
					gui.list_box_option('California', 'CA'),
					gui.list_box_option('Colorado', 'CO'),
					gui.list_box_option('Connecticut', 'CT'),
					gui.list_box_option('Delaware', 'DE'),
					gui.list_box_option('District of Columbia', 'DC'),
					gui.list_box_option('Florida', 'FL'),
					gui.list_box_option('Georgia', 'GA'),
					gui.list_box_option('Hawaii', 'HI'),
					gui.list_box_option('Idaho', 'ID'),
					gui.list_box_option('Illinois', 'IL'),
					gui.list_box_option('Indiana', 'IN'),
					gui.list_box_option('Iowa', 'IA'),
					gui.list_box_option('Kansas', 'KS'),
					gui.list_box_option('Kentucky', 'KY'),
					gui.list_box_option('Louisiana', 'LA'),
					gui.list_box_option('Maine', 'ME'),
					gui.list_box_option('Maryland', 'MD'),
					gui.list_box_option('Massachusetts', 'MA'),
					gui.list_box_option('Michigan', 'MI'),
					gui.list_box_option('Minnesota', 'MN'),
					gui.list_box_option('Mississippi', 'MS'),
					gui.list_box_option('Missouri', 'MO'),
					gui.list_box_option('Montana', 'MT'),
					gui.list_box_option('Nebraska', 'NE'),
					gui.list_box_option('Nevada', 'NV'),
					gui.list_box_option('New Hampshire', 'NH'),
					gui.list_box_option('New Jersey', 'NJ'),
					gui.list_box_option('New Mexico', 'NM'),
					gui.list_box_option('New York', 'NY'),
					gui.list_box_option('North Carolina', 'NC'),
					gui.list_box_option('North Dakota', 'ND'),
					gui.list_box_option('Ohio', 'OH'),
					gui.list_box_option('Oklahoma', 'OK'),
					gui.list_box_option('Oregon', 'OR'),
					gui.list_box_option('Pennsylvania', 'PA'),
					gui.list_box_option('Rhode Island', 'RI'),
					gui.list_box_option('South Carolina', 'SC'),
					gui.list_box_option('South Dakota', 'SD'),
					gui.list_box_option('Tennessee', 'TN'),
					gui.list_box_option('Texas', 'TX'),
					gui.list_box_option('Utah', 'UT'),
					gui.list_box_option('Vermont', 'VT'),
					gui.list_box_option('Virginia', 'VA'),
					gui.list_box_option('Washington', 'WA'),
					gui.list_box_option('West Virginia', 'WV'),
					gui.list_box_option('Wisconsin', 'WI'),
					gui.list_box_option('Wyoming', 'WY'),
					gui.list_box_option('---Territories', ''),
					gui.list_box_option('American Samoa', 'AS'),
					gui.list_box_option('Guam', 'GU'),
					gui.list_box_option('Northern Mariana Islands', 'MP'),
					gui.list_box_option('Puerto Rico', 'PR'),
					gui.list_box_option('U.S. Virgin Islands', 'VI'),
				]
				on_select: fn (values []string, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.list_box_selected_values = values
					e.is_handled = true
				}
			),
			gui.toggle(
				label:    'Multi-Select'
				select:   app.list_box_multiple_select
				on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.list_box_multiple_select = !app.list_box_multiple_select
					app.list_box_selected_values.clear()
				}
			),
		]
	)
}

// ==============================================================
// Range Sliders
// ==============================================================

fn range_sliders(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Range Sliders'),
			gui.row(
				sizing:  gui.fill_fit
				content: [range_slider_samples(w)]
			),
		]
	)
}

fn range_slider_samples(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.row(
		sizing:  gui.fill_fill
		content: [
			gui.column(
				width:   200
				content: [
					gui.range_slider(
						id:          'rs1'
						value:       app.range_value
						round_value: true
						sizing:      gui.fill_fit
						on_change:   fn (value f32, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.range_value = value
						}
					),
					gui.text(text: app.range_value.str()),
				]
			),
			gui.column(
				height:  50
				content: [
					gui.range_slider(
						id:          'rs2'
						value:       app.range_value
						round_value: true
						vertical:    true
						sizing:      gui.fit_fill
						on_change:   fn (value f32, mut e gui.Event, mut w gui.Window) {
							mut app := w.state[ShowcaseApp]()
							app.range_value = value
						}
					),
				]
			),
		]
	)
}

// ==============================================================
// Select
// ==============================================================

fn select_drop_down(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Select (Drop Down)'),
			gui.row(
				sizing:  gui.fill_fit
				content: [select_samples(w)]
			),
		]
	)
}

fn select_samples(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.row(
		content: [
			w.select(
				id:              'sel1'
				min_width:       200
				max_width:       200
				select:          app.selected_1
				placeholder:     'Pick one or more'
				select_multiple: true
				options:         [
					'Alabama',
					'Alaska',
					'Arizona',
					'Arkansas',
					'California',
					'Colorado',
					'Connecticut',
					'Delaware',
					'Florida',
					'Georgia',
					'Hawaii',
					'Idaho',
					'Illinois',
					'Indiana',
					'Iowa',
					'Kansas',
					'Kentucky',
					'Louisiana',
					'Maine',
					'Maryland',
					'Massachusetts',
					'Michigan',
					'Minnesota',
					'Mississippi',
					'Missouri',
					'Montana',
					'Nebraska',
					'Nevada',
					'New Hampshire',
					'New Jersey',
					'New Mexico',
					'New York',
					'North Carolina',
					'North Dakota',
					'Ohio',
					'Oklahoma',
					'Oregon',
					'Pennsylvania',
					'Rhode Island',
					'South Carolina',
					'South Dakota',
					'Tennessee',
					'Texas',
					'Utah',
					'Vermont',
					'Virginia',
					'Washington',
					'West Virginia',
					'Wisconsin',
					'Wyoming',
				]
				on_select:       fn (s []string, mut e gui.Event, mut w gui.Window) {
					mut app_ := w.state[ShowcaseApp]()
					app_.selected_1 = s
					e.is_handled = true
				}
			),
			w.select(
				id:          'sel2'
				min_width:   300
				max_width:   300
				select:      app.selected_2
				placeholder: 'Pick a country'
				options:     [
					'---Africa',
					'Algeria',
					'Angola',
					'Benin',
					'Botswana',
					'Burkina Faso',
					'Burundi',
					'Cabo Verde',
					'Cameroon',
					'Central African Republic',
					'Chad',
					'Comoros',
					'Congo',
					'Democratic Republic of the Congo',
					'Djibouti',
					'Egypt',
					'Equatorial Guinea',
					'Eritrea',
					'Eswatini',
					'Ethiopia',
					'Gabon',
					'Gambia',
					'Ghana',
					'Guinea',
					'Guinea-Bissau',
					'Ivory Coast',
					'Kenya',
					'Lesotho',
					'Liberia',
					'Libya',
					'Madagascar',
					'Malawi',
					'Mali',
					'Mauritania',
					'Mauritius',
					'Morocco',
					'Mozambique',
					'Namibia',
					'Niger',
					'Nigeria',
					'Rwanda',
					'Sao Tome and Principe',
					'Senegal',
					'Seychelles',
					'Sierra Leone',
					'Somalia',
					'South Africa',
					'South Sudan',
					'Sudan',
					'Tanzania',
					'Togo',
					'Tunisia',
					'Uganda',
					'Zambia',
					'Zimbabwe',
					'---Asia',
					'Afghanistan',
					'Armenia',
					'Azerbaijan',
					'Bahrain',
					'Bangladesh',
					'Bhutan',
					'Brunei',
					'Cambodia',
					'China',
					'Cyprus',
					'East Timor',
					'Georgia',
					'India',
					'Indonesia',
					'Iran',
					'Iraq',
					'Israel',
					'Japan',
					'Jordan',
					'Kazakhstan',
					'Kuwait',
					'Kyrgyzstan',
					'Laos',
					'Lebanon',
					'Malaysia',
					'Maldives',
					'Mongolia',
					'Myanmar',
					'Nepal',
					'North Korea',
					'Oman',
					'Pakistan',
					'Palestine',
					'Philippines',
					'Qatar',
					'Russia',
					'Saudi Arabia',
					'Singapore',
					'South Korea',
					'Sri Lanka',
					'Syria',
					'Taiwan',
					'Tajikistan',
					'Thailand',
					'Turkey',
					'Turkmenistan',
					'United Arab Emirates',
					'Uzbekistan',
					'Vietnam',
					'Yemen',
					'---Europe',
					'Albania',
					'Andorra',
					'Austria',
					'Belarus',
					'Belgium',
					'Bosnia and Herzegovina',
					'Bulgaria',
					'Croatia',
					'Czechia',
					'Denmark',
					'Estonia',
					'Finland',
					'France',
					'Germany',
					'Greece',
					'Hungary',
					'Iceland',
					'Ireland',
					'Italy',
					'Kosovo',
					'Latvia',
					'Liechtenstein',
					'Lithuania',
					'Luxembourg',
					'Malta',
					'Moldova',
					'Monaco',
					'Montenegro',
					'Netherlands',
					'North Macedonia',
					'Norway',
					'Poland',
					'Portugal',
					'Romania',
					'San Marino',
					'Serbia',
					'Slovakia',
					'Slovenia',
					'Spain',
					'Sweden',
					'Switzerland',
					'Ukraine',
					'United Kingdom',
					'Vatican City',
					'---North America',
					'Antigua and Barbuda',
					'Bahamas',
					'Barbados',
					'Belize',
					'Canada',
					'Costa Rica',
					'Cuba',
					'Dominica',
					'Dominican Republic',
					'El Salvador',
					'Grenada',
					'Guatemala',
					'Haiti',
					'Honduras',
					'Jamaica',
					'Mexico',
					'Nicaragua',
					'Panama',
					'Saint Kitts and Nevis',
					'Saint Lucia',
					'Saint Vincent and the Grenadines',
					'Trinidad and Tobago',
					'United States',
					'---Oceania',
					'Australia',
					'Fiji',
					'Kiribati',
					'Marshall Islands',
					'Micronesia',
					'Nauru',
					'New Zealand',
					'Palau',
					'Papua New Guinea',
					'Samoa',
					'Solomon Islands',
					'Tonga',
					'Tuvalu',
					'Vanuatu',
					'---South America',
					'Argentina',
					'Bolivia',
					'Brazil',
					'Chile',
					'Colombia',
					'Ecuador',
					'Guyana',
					'Paraguay',
					'Peru',
					'Suriname',
					'Uruguay',
					'Venezuela',
				]
				on_select:   fn (s []string, mut e gui.Event, mut w gui.Window) {
					mut app_ := w.state[ShowcaseApp]()
					app_.selected_2 = s
					e.is_handled = true
				}
			),
		]
	)
}

// ==============================================================
// Icons
// ==============================================================

fn icons(mut w gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		content: [
			view_title('Icons (Font)'),
			gui.row(
				sizing:  gui.fill_fit
				spacing: 0
				padding: gui.padding_none
				content: [icon_catalog(mut w)]
			),
		]
	)
}

fn icon_catalog(mut w gui.Window) gui.View {
	// find the longest text
	mut longest := f32(0)
	for s in gui.icons_map.keys() {
		longest = f32_max(gui.text_width(s, gui.theme().n4, mut w), longest)
	}

	// Break the icons_maps into rows
	chunks := chunk_map(gui.icons_map, 4)
	mut all_icons := []gui.View{cap: chunks.len}

	cfg := gui.TextStyle{
		...gui.theme().icon1
		size: 24
	}

	// create rows of icons/text
	for chunk in chunks {
		mut icons := []gui.View{cap: chunk.len}
		for key, val in chunk {
			icons << gui.column(
				min_width: longest
				h_align:   .center
				padding:   gui.padding_none
				content:   [
					gui.text(text: val, text_style: cfg),
					gui.text(text: key, text_style: gui.theme().n4),
				]
			)
		}
		all_icons << gui.row(
			spacing: 0
			padding: gui.padding_none
			content: icons
		)
	}

	return gui.column(
		spacing: gui.spacing_large
		sizing:  gui.fill_fill
		padding: gui.padding_none
		content: all_icons
	)
}

// maybe this should be a standard library function?
fn chunk_map[K, V](input map[K]V, chunk_size int) []map[K]V {
	mut chunks := []map[K]V{cap: input.keys().len / chunk_size + 1}
	mut current_chunk := map[K]V{}
	mut count := 0

	for key, value in input {
		current_chunk[key] = value
		count += 1
		if count == chunk_size {
			chunks << current_chunk
			current_chunk = map[K]V{}
			count = 0
		}
	}
	// Add any remaining items as the last chunk
	if current_chunk.len > 0 {
		chunks << current_chunk
	}
	return chunks
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

fn svg_icons(mut w gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		content: [
			view_title('SVG Icons'),
			gui.column(
				spacing: gui.spacing_large
				content: [
					gui.text(text: 'Default Size (24x24)', text_style: gui.theme().b2),
					gui.row(
						spacing: 10
						content: [
							gui.svg(
								svg_data: svg_home
								width:    24
								height:   24
								color:    gui.theme().text_style.color
							),
							gui.svg(
								svg_data: svg_settings
								width:    24
								height:   24
								color:    gui.theme().text_style.color
							),
							gui.svg(
								svg_data: svg_star
								width:    24
								height:   24
								color:    gui.theme().text_style.color
							),
							gui.svg(
								svg_data: svg_heart
								width:    24
								height:   24
								color:    gui.theme().text_style.color
							),
							gui.svg(
								svg_data: svg_check
								width:    24
								height:   24
								color:    gui.theme().text_style.color
							),
						]
					),
					gui.text(text: 'With Colors', text_style: gui.theme().b2),
					gui.row(
						spacing: 10
						content: [
							gui.svg(svg_data: svg_home, width: 32, height: 32, color: gui.blue),
							gui.svg(svg_data: svg_settings, width: 32, height: 32, color: gui.gray),
							gui.svg(svg_data: svg_star, width: 32, height: 32, color: gui.yellow),
							gui.svg(svg_data: svg_heart, width: 32, height: 32, color: gui.red),
							gui.svg(svg_data: svg_check, width: 32, height: 32, color: gui.green),
						]
					),
					gui.text(text: 'Scaled (48x48, 64x64)', text_style: gui.theme().b2),
					gui.row(
						spacing: 20
						v_align: .middle
						content: [
							gui.svg(svg_data: svg_home, width: 48, height: 48, color: gui.cyan),
							gui.svg(svg_data: svg_star, width: 64, height: 64, color: gui.orange),
							gui.svg(svg_data: svg_heart, width: 48, height: 48, color: gui.pink),
						]
					),
					gui.text(text: 'Clickable', text_style: gui.theme().b2),
					gui.svg(
						svg_data: svg_settings
						width:    40
						height:   40
						color:    gui.theme().text_style.color
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.dialog(
								dialog_type: .message
								title:       'SVG Clicked'
								body:        'Settings icon was clicked!'
							)
						}
					),
				]
			),
		]
	)
}

// ==============================================================
// Image
// ==============================================================

const sample_image_path = os.join_path(os.dir(@FILE), 'sample.jpeg')

fn image_sample(w &gui.Window) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Image'),
			gui.column(
				content: [
					gui.image(src: sample_image_path),
					gui.text(text: 'Pinard Falls, Oregon', text_style: gui.theme().b2),
				]
			),
		]
	)
}

// ==============================================================
// Tree View
// ==============================================================

fn tree_view(mut w gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			view_title('TreeView'),
			gui.row(
				sizing:  gui.fill_fit
				spacing: 0
				padding: gui.padding_none
				content: [tree_view_sample(mut w)]
			),
		]
	)
}

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

fn expand_panel(w &gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			view_title('Expand Panel'),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				spacing: 0
				content: [expand_panel_sample(w)]
			),
		]
	)
}

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

fn pulsars(mut w gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			view_title('Pulsars'),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				spacing: 0
				content: [pulsar_samples(mut w)]
			),
		]
	)
}

fn pulsar_samples(mut w gui.Window) gui.View {
	return gui.row(
		content: [
			w.pulsar(),
			w.pulsar(size: 20),
			w.pulsar(size: 30, color: gui.orange),
			w.pulsar(size: 30, icon1: gui.icon_heart, icon2: gui.icon_heart_o, color: gui.red),
			w.pulsar(size: 30, icon1: gui.icon_expand, icon2: gui.icon_compress, color: gui.green),
		]
	)
}

// ==============================================================
// Text Sizes & Weights
// ==============================================================

fn text_sizes_weights(w &gui.Window) gui.View {
	text_style_file := gui.TextStyle{
		...gui.theme().text_style
		color: gui.theme().color_border
	}
	variants := gui.font_variants(gui.theme().text_style)
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		content: [
			view_title('Text Sizes & Weights'),
			gui.column(
				spacing: 0
				padding: gui.padding_none
				content: [
					gui.text(text: variants.normal, text_style: text_style_file),
					gui.row(
						padding: gui.padding_none
						sizing:  gui.fill_fit
						v_align: .bottom
						content: [
							gui.text(text: 'Theme().n1', text_style: gui.theme().n1),
							gui.text(text: 'Theme().n2', text_style: gui.theme().n2),
							gui.text(text: 'Theme().n3', text_style: gui.theme().n3),
							gui.text(text: 'Theme().n4', text_style: gui.theme().n4),
							gui.text(text: 'Theme().n5', text_style: gui.theme().n5),
							gui.text(text: 'Theme().n6', text_style: gui.theme().n6),
						]
					),
				]
			),
			gui.column(
				spacing: 0
				padding: gui.padding_none
				content: [
					gui.text(text: variants.bold, text_style: text_style_file),
					gui.row(
						padding: gui.padding_none
						sizing:  gui.fill_fit
						v_align: .bottom
						content: [
							gui.text(text: 'Theme().b1', text_style: gui.theme().b1),
							gui.text(text: 'Theme().b2', text_style: gui.theme().b2),
							gui.text(text: 'Theme().b3', text_style: gui.theme().b3),
							gui.text(text: 'Theme().b4', text_style: gui.theme().b4),
							gui.text(text: 'Theme().b5', text_style: gui.theme().b5),
							gui.text(text: 'Theme().b6', text_style: gui.theme().b6),
						]
					),
				]
			),
			gui.column(
				spacing: 0
				padding: gui.padding_none
				content: [
					gui.text(text: variants.italic, text_style: text_style_file),
					gui.row(
						padding: gui.padding_none
						sizing:  gui.fill_fit
						v_align: .bottom
						content: [
							gui.text(text: 'Theme().i1', text_style: gui.theme().i1),
							gui.text(text: 'Theme().i2', text_style: gui.theme().i2),
							gui.text(text: 'Theme().i3', text_style: gui.theme().i3),
							gui.text(text: 'Theme().i4', text_style: gui.theme().i4),
							gui.text(text: 'Theme().i5', text_style: gui.theme().i5),
							gui.text(text: 'Theme().i6', text_style: gui.theme().i6),
						]
					),
				]
			),
			gui.column(
				spacing: 0
				padding: gui.padding_none
				content: [
					gui.text(text: variants.mono, text_style: text_style_file),
					gui.row(
						padding: gui.padding_none
						sizing:  gui.fill_fit
						v_align: .bottom
						content: [
							gui.text(text: 'Theme().m1', text_style: gui.theme().m1),
							gui.text(text: 'Theme().m2', text_style: gui.theme().m2),
							gui.text(text: 'Theme().m3', text_style: gui.theme().m3),
							gui.text(text: 'Theme().m4', text_style: gui.theme().m4),
							gui.text(text: 'Theme().m5', text_style: gui.theme().m5),
							gui.text(text: 'Theme().m6', text_style: gui.theme().m6),
						]
					),
				]
			),
		]
	)
}

// ==============================================================
// Rich Text Format
// ==============================================================
fn rich_text_format(w &gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			view_title('Rich Text Format (RTF)'),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				spacing: 0
				content: [rtf_sample(w)]
			),
		]
	)
}

fn rtf_sample(w &gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			gui.rtf(
				mode:      .wrap
				rich_text: gui.RichText{
					runs: [
						gui.rich_run('Hello', gui.theme().n3),
						gui.rich_run(' RTF ', gui.theme().b3),
						gui.rich_run('World', gui.theme().n3),
						gui.rich_br(),
						gui.rich_br(),
						gui.RichTextRun{
							text:  'Now is the'
							style: gui.TextStyle{
								...gui.theme().n3
								strikethrough: true
							}
						},
						gui.rich_run(' ', gui.theme().n3),
						gui.rich_run('time', gui.theme().i3),
						gui.rich_run(' for all', gui.theme().n3),
						gui.RichTextRun{
							text:  ' good men '
							style: gui.TextStyle{
								...gui.theme().n3
								color: gui.green
							}
						},
						gui.rich_run('to come to the aid of their ', gui.theme().n3),
						gui.RichTextRun{
							text:  'country'
							style: gui.TextStyle{
								...gui.theme().b3
								underline: true
							}
						},
						gui.rich_br(),
						gui.rich_br(),
						gui.rich_run('This is a ', gui.theme().n3),
						gui.rich_link('hyperlink', 'https://www.example.com', gui.theme().n3),
					]
				}
			),
		]
	)
}

// ==============================================================
// Tables
// ==============================================================
fn tables(mut w gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fill
		content: [
			view_title('Tables'),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				spacing: 0
				content: [table_samples(mut w)]
			),
		]
	)
}

fn table_samples(mut w gui.Window) gui.View {
	mut app := w.state[ShowcaseApp]()
	return gui.column(
		content: [
			gui.text(text: 'Declarative Layout', text_style: gui.theme().b2),
			w.table(
				size_border:     1.0
				color_border:    gui.gray
				text_style_head: gui.theme().b3
				data:            [
					gui.tr([gui.th('First'), gui.th('Last'), gui.th('Email')]),
					gui.tr([gui.td('Matt'), gui.td('Williams'),
						gui.td('non.egestas.a@protonmail.org')]),
					gui.tr([gui.td('Clara'), gui.td('Nelson'),
						gui.td('mauris.sagittis@icloud.net')]),
					gui.tr([gui.td('Frank'), gui.td('Johnson'),
						gui.td('ac.libero.nec@aol.com')]),
					gui.tr([gui.td('Elmer'), gui.td('Fudd'), gui.td('mus@aol.couk')]),
					gui.tr([gui.td('Roy'), gui.td('Rogers'), gui.td('amet.ultricies@yahoo.com')]),
				]
			),
			gui.text(text: ''),
			gui.text(text: 'CSV Data', text_style: gui.theme().b2),
			table_with_sortable_columns(mut app.csv_table, mut w),
			gui.text(text: ''),
		]
	)
}

fn table_with_sortable_columns(mut table_data TableData, mut window gui.Window) gui.View {
	mut table_cfg := gui.table_cfg_from_data(table_data.sorted)
	table_cfg = gui.TableCfg{
		...table_cfg
		color_border: gui.gray
		size_border:  1.0
	}

	// Replace with first row with clickable column headers
	mut tds := []gui.TableCellCfg{}
	for idx, cell in table_cfg.data[0].cells {
		tds << gui.TableCellCfg{
			...cell
			value:    match true {
				idx + 1 == table_data.sort_by { cell.value + '  ↓' }
				-(idx + 1) == table_data.sort_by { cell.value + ' ↑' }
				else { cell.value }
			}
			on_click: fn [idx, mut table_data] (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
				table_data.sort_by = match true {
					table_data.sort_by == (idx + 1) { -(idx + 1) }
					table_data.sort_by == -(idx + 1) { 0 }
					else { idx + 1 }
				}
				table_sort(mut table_data)
				e.is_handled = true
			}
		}
	}

	table_cfg.data.delete(0)
	table_cfg.data.insert(0, gui.tr(tds))
	return window.table(table_cfg)
}

fn table_sort(mut table_data TableData) {
	if table_data.sort_by == 0 {
		table_data.sorted = table_data.unsorted
		return
	}
	direction := table_data.sort_by > 0
	idx := math.abs(table_data.sort_by) - 1
	head_row := table_data.sorted[0]
	table_data.sorted.delete(0) // duplicates the array so no clone needed above
	table_data.sorted.sort_with_compare(fn [direction, idx] (mut a []string, mut b []string) int {
		return match true {
			a[idx] < b[idx] && direction { -1 }
			a[idx] > b[idx] && !direction { -1 }
			a[idx] > b[idx] && direction { 1 }
			a[idx] < b[idx] && !direction { 1 }
			else { 0 }
		}
	})
	table_data.sorted.insert(0, head_row)
}

fn get_table_data() !TableData {
	mut table_data := TableData{}
	mut parser := csv.csv_reader_from_string(csv_table_data_source)!
	for y in 0 .. int(parser.rows_count()!) {
		table_data.unsorted << parser.get_row(y)!
	}
	table_data.sorted = table_data.unsorted
	return table_data
}

const csv_table_data_source = 'Name,Phone,Email,Address,Postal Zip,Region
Keelie Snow,1-164-548-3178,erat.vivamus@icloud.net,Ap #414-702 Libero Avenue,698863,Chernivtsi oblast
Anthony Keith,1-918-510-5824,pulvinar.arcu@google.ca,Ap #358-7921 Placerat. Street,S4V 2M4,Leinster
Carissa Larson,1-646-772-7793,enim.gravida@aol.couk,"667-994 Mi, St.",1231,Sardegna
Joseph Herrera,1-746-758-0438,posuere@hotmail.couk,Ap #638-5604 Adipiscing Ave,51262,Pará
Nerea Romero,1-425-458-5525,pretium.neque@google.edu,990-4951 Mauris St.,46317,Junín
Macey Reed,1-175-242-2264,massa.quisque@hotmail.couk,1239 Arcu. Av.,WI1 8TR,Lai Châu
Craig Roach,1-541-688-6830,lorem.sit@hotmail.ca,385-9173 Libero. Rd.,07132,Newfoundland and Labrador
Yardley Barlow,1-648-862-5647,sodales@hotmail.couk,893-8994 Aliquet. St.,97-286,Lambayeque
Shad Whitfield,1-525-513-5416,augue.id.ante@protonmail.org,Ap #560-3609 Lorem Ave,70666,North Jeolla
Eugenia Bell,1-578-560-1252,laoreet.ipsum@icloud.edu,"P.O. Box 922, 5077 Sed Ave",28133,Kon Tum
Nash Hernandez,1-897-393-7624,convallis.convallis.dolor@google.couk,5853 Diam. Rd.,734884,Tasmania
Rinah Woods,1-698-796-5903,dui.nec.urna@icloud.ca,252-4094 Neque. Avenue,17571,Northern Territory
Jescie Beasley,1-264-555-2460,sapien.cursus@google.org,"873-7406 At, Rd.",44324,Gyeonggi
Jordan Harrison,1-627-442-6681,scelerisque.scelerisque@hotmail.net,696-2283 Turpis Rd.,3709,Umbria
Abdul Rowe,1-384-151-2787,ornare.fusce.mollis@hotmail.edu,"Ap #856-6933 Ut, St.",25878,Mississippi
Simone Bullock,1-623-422-9718,sed.facilisis@outlook.couk,2620 Mattis St.,49275,Luxemburg
Lillian Montgomery,1-317-854-9787,ut@outlook.couk,Ap #132-4005 Enim Ave,571928,Leinster
Tanisha Rodriquez,1-217-655-3165,id@aol.couk,"P.O. Box 490, 1311 Et, Road",45133,Chiapas
Alexandra Dyer,1-442-662-6576,amet.consectetuer.adipiscing@protonmail.edu,Ap #474-4869 Malesuada St.,613696,Rajasthan
Gretchen Carr,1-465-576-3555,eu.nibh@yahoo.org,Ap #617-6465 Nascetur Rd.,872532,São Paulo
Patience Cobb,1-833-211-2532,sed@hotmail.couk,1431 Pellentesque Street,644218,Paraná
Jaquelyn Carlson,1-774-851-3274,amet.dapibus@aol.ca,"Ap #529-8389 Lectus, Av.",5680-5371,Central Region
Britanney Silva,1-281-414-9085,nascetur.ridiculus.mus@google.ca,429-6408 Nec Rd.,6132,Vorarlberg
Brennan Hooper,1-534-697-7689,nunc.pulvinar.arcu@aol.edu,Ap #425-8524 Pellentesque. Ave,8834,Morayshire
Eliana Fry,1-822-880-5214,orci.luctus.et@protonmail.edu,351-931 Non St.,731577,Viken
'

// ==============================================================
// Date Pickers
// ==============================================================

fn date_pickers(mut w gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fit
		content: [
			view_title('Date Pickers'),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				content: [date_picker_samples(mut w)]
			),
		]
	)
}

fn date_picker_samples(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.spacing_large * 2
		content: [
			gui.row(
				spacing: gui.spacing_large * 2
				v_align: .top
				content: [
					gui.column(
						padding: gui.padding_none
						content: [
							gui.text(text: 'Calendar Date Picker', text_style: gui.theme().b2),
							gui.text(
								text:       selected_dates_text(app.date_picker_dates)
								text_style: gui.theme().n4
							),
							w.date_picker(
								id:        'dp1'
								dates:     app.date_picker_dates
								on_select: fn (dates []time.Time, mut e gui.Event, mut w gui.Window) {
									mut app := w.state[ShowcaseApp]()
									app.date_picker_dates = dates
									e.is_handled = true
								}
							),
						]
					),
					gui.column(
						padding: gui.padding_none
						content: [
							gui.text(text: 'Input Date (with dropdown)', text_style: gui.theme().b2),
							gui.text(
								text:       'Selected: ${app.input_date.format()}'
								text_style: gui.theme().n4
							),
							w.input_date(
								id:        'id1'
								id_focus:  4000
								date:      app.input_date
								on_select: fn (dates []time.Time, mut e gui.Event, mut w gui.Window) {
									mut app := w.state[ShowcaseApp]()
									if dates.len > 0 {
										app.input_date = dates[0]
									}
									e.is_handled = true
								}
							),
						]
					),
				]
			),
			gui.column(
				padding: gui.padding_none
				content: [
					gui.text(text: 'Date Picker Roller', text_style: gui.theme().b2),
					gui.text(
						text:       'Selected: ${app.roller_date.format()}'
						text_style: gui.theme().n4
					),
					gui.row(
						v_align: .top
						content: [
							gui.column(
								padding: gui.padding_none
								h_align: .center
								content: [
									gui.text(text: '.month_day_year', text_style: gui.theme().n4),
									gui.date_picker_roller(
										id:            'dpr1'
										id_focus:      4001
										selected_date: app.roller_date
										display_mode:  .month_day_year
										long_months:   true
										on_change:     fn (d time.Time, mut w gui.Window) {
											mut app := w.state[ShowcaseApp]()
											app.roller_date = d
										}
									),
								]
							),
							gui.column(
								padding: gui.padding_none
								h_align: .center
								content: [
									gui.text(text: '.month_year', text_style: gui.theme().n4),
									gui.date_picker_roller(
										id:            'dpr2'
										id_focus:      4002
										selected_date: app.roller_date
										display_mode:  .month_year
										long_months:   false
										on_change:     fn (d time.Time, mut w gui.Window) {
											mut app := w.state[ShowcaseApp]()
											app.roller_date = d
										}
									),
								]
							),
							gui.column(
								padding: gui.padding_none
								h_align: .center
								content: [
									gui.text(text: '.year_only', text_style: gui.theme().n4),
									gui.date_picker_roller(
										id:            'dpr3'
										id_focus:      4003
										selected_date: app.roller_date
										display_mode:  .year_only
										on_change:     fn (d time.Time, mut w gui.Window) {
											mut app := w.state[ShowcaseApp]()
											app.roller_date = d
										}
									),
								]
							),
						]
					),
				]
			),
		]
	)
}

fn selected_dates_text(dates []time.Time) string {
	if dates.len == 0 {
		return 'No dates selected'
	}
	mut parts := []string{cap: dates.len}
	for d in dates {
		parts << d.format()
	}
	return 'Selected: ${parts.join(', ')}'
}

// ==============================================================
// Animations
// ==============================================================

fn animations(mut w gui.Window) gui.View {
	return gui.column(
		padding: gui.padding_none
		sizing:  gui.fill_fit
		content: [
			view_title('Animations'),
			gui.row(
				padding: gui.padding_none
				sizing:  gui.fill_fit
				content: [animation_samples(mut w)]
			),
		]
	)
}

fn animation_samples(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	box_color := if app.light_theme { gui.dark_blue } else { gui.cornflower_blue }
	return gui.column(
		spacing: gui.spacing_large * 2
		content: [
			// Tween Animation
			gui.column(
				padding: gui.padding_none
				content: [
					gui.text(text: 'Tween Animation', text_style: gui.theme().b2),
					gui.text(
						text:       'Interpolates values over time with easing functions'
						text_style: gui.theme().n4
					),
					gui.row(
						content: [
							gui.button(
								content:  [gui.text(text: 'ease_out_cubic')]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									start_tween(mut w, gui.ease_out_cubic)
								}
							),
							gui.button(
								content:  [gui.text(text: 'ease_out_bounce')]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									start_tween(mut w, gui.ease_out_bounce)
								}
							),
							gui.button(
								content:  [gui.text(text: 'ease_out_elastic')]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									start_tween(mut w, gui.ease_out_elastic)
								}
							),
							gui.button(
								content:  [gui.text(text: 'ease_out_back')]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									start_tween(mut w, gui.ease_out_back)
								}
							),
						]
					),
					gui.row(
						height:  40
						sizing:  gui.fill_fixed
						padding: gui.padding_none
						content: [
							gui.row(
								width:   int(app.anim_tween_x)
								sizing:  gui.fixed_fit
								padding: gui.padding_none
							),
							gui.row(
								width:   30
								height:  30
								sizing:  gui.fixed_fixed
								padding: gui.padding_none
								color:   box_color
								radius:  4
							),
						]
					),
				]
			),
			// Spring Animation
			gui.column(
				padding: gui.padding_none
				content: [
					gui.text(text: 'Spring Animation', text_style: gui.theme().b2),
					gui.text(
						text:       'Physics-based motion with natural feel'
						text_style: gui.theme().n4
					),
					gui.row(
						content: [
							gui.button(
								content:  [gui.text(text: 'spring_default')]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									start_spring(mut w, gui.spring_default)
								}
							),
							gui.button(
								content:  [gui.text(text: 'spring_gentle')]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									start_spring(mut w, gui.spring_gentle)
								}
							),
							gui.button(
								content:  [gui.text(text: 'spring_bouncy')]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									start_spring(mut w, gui.spring_bouncy)
								}
							),
							gui.button(
								content:  [gui.text(text: 'spring_stiff')]
								on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									start_spring(mut w, gui.spring_stiff)
								}
							),
						]
					),
					gui.row(
						height:  40
						sizing:  gui.fill_fixed
						padding: gui.padding_none
						content: [
							gui.row(
								width:   int(app.anim_spring_x)
								sizing:  gui.fixed_fit
								padding: gui.padding_none
							),
							gui.row(
								width:   30
								height:  30
								sizing:  gui.fixed_fixed
								padding: gui.padding_none
								color:   box_color
								radius:  15
							),
						]
					),
				]
			),
			// Layout Transition
			gui.column(
				padding: gui.padding_none
				content: [
					gui.text(text: 'Layout Transition', text_style: gui.theme().b2),
					gui.text(
						text:       'Automatically animates position changes'
						text_style: gui.theme().n4
					),
					gui.button(
						content:  [
							gui.text(text: 'Toggle Layout'),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							w.animate_layout(duration: 400 * time.millisecond)
							mut app := w.state[ShowcaseApp]()
							app.anim_layout_expanded = !app.anim_layout_expanded
						}
					),
					gui.row(
						height:  60
						sizing:  gui.fill_fixed
						padding: gui.padding_none
						content: layout_boxes(app.anim_layout_expanded, box_color)
					),
				]
			),
		]
	)
}

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

fn basic_button_demo(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.row(
		v_align: .middle
		content: [
			gui.button(
				id_focus: 9100
				content:  [gui.text(text: 'Click Me')]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.button_clicks += 1
				}
			),
			gui.text(text: 'Clicks: ${app.button_clicks}'),
		]
	)
}

fn basic_input_demo(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
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

fn basic_toggle_demo(w &gui.Window) gui.View {
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

fn basic_switch_demo(w &gui.Window) gui.View {
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

fn basic_radio_demo(w &gui.Window) gui.View {
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

fn basic_radio_group_demo(w &gui.Window) gui.View {
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

fn basic_select_demo(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return w.select(
		id:              'catalog_select'
		min_width:       250
		max_width:       250
		select:          app.selected_1
		placeholder:     'Pick one or more'
		select_multiple: true
		options:         ['Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California']
		on_select:       fn (s []string, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[ShowcaseApp]()
			app.selected_1 = s
			e.is_handled = true
		}
	)
}

fn basic_list_box_demo(w &gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	return gui.column(
		spacing: gui.theme().spacing_small
		content: [
			gui.list_box(
				id_scroll: id_scroll_list_box
				height:    180
				sizing:    gui.fill_fixed
				multiple:  app.list_box_multiple_select
				selected:  app.list_box_selected_values
				data:      [
					gui.list_box_option('---States', ''),
					gui.list_box_option('California', 'CA'),
					gui.list_box_option('Colorado', 'CO'),
					gui.list_box_option('Florida', 'FL'),
					gui.list_box_option('New York', 'NY'),
					gui.list_box_option('Washington', 'WA'),
				]
				on_select: fn (values []string, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.list_box_selected_values = values
					e.is_handled = true
				}
			),
			gui.toggle(
				label:    'Multi-select'
				select:   app.list_box_multiple_select
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					mut app := w.state[ShowcaseApp]()
					app.list_box_multiple_select = !app.list_box_multiple_select
					app.list_box_selected_values.clear()
				}
			),
		]
	)
}

fn basic_range_slider_demo(w &gui.Window) gui.View {
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

fn basic_progress_bar_demo(w &gui.Window) gui.View {
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

fn basic_pulsar_demo(mut w gui.Window) gui.View {
	return gui.row(
		content: [
			w.pulsar(),
			w.pulsar(size: 20),
			w.pulsar(size: 28, color: gui.orange),
		]
	)
}

fn basic_menu_demo(mut w gui.Window) gui.View {
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

fn basic_dialog_demo() gui.View {
	return gui.row(
		content: [
			gui.button(
				content:  [gui.text(text: 'Message Dialog')]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					w.dialog(
						dialog_type: .message
						title:       'Message'
						body:        'Dialog control example'
					)
				}
			),
			gui.button(
				content:  [gui.text(text: 'Confirm Dialog')]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					w.dialog(
						dialog_type: .confirm
						title:       'Confirm'
						body:        'Continue?'
					)
				}
			),
		]
	)
}

fn basic_tree_demo(mut w gui.Window) gui.View {
	return tree_view_sample(mut w)
}

fn basic_text_demo() gui.View {
	return gui.column(
		spacing: 0
		content: [
			gui.text(text: 'Theme n3 text', text_style: gui.theme().n3),
			gui.text(text: 'Theme b3 text', text_style: gui.theme().b3),
			gui.text(text: 'Theme i3 text', text_style: gui.theme().i3),
			gui.text(text: 'Theme m3 text', text_style: gui.theme().m3),
		]
	)
}

fn basic_rtf_demo() gui.View {
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

fn basic_table_demo(mut w gui.Window) gui.View {
	return w.table(
		size_border:  1
		color_border: gui.gray
		data:         [
			gui.tr([gui.th('Name'), gui.th('Role')]),
			gui.tr([gui.td('Alex'), gui.td('Designer')]),
			gui.tr([gui.td('Riley'), gui.td('Engineer')]),
			gui.tr([gui.td('Jordan'), gui.td('PM')]),
		]
	)
}

fn basic_date_picker_demo(mut w gui.Window) gui.View {
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

fn basic_input_date_demo(mut w gui.Window) gui.View {
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

fn basic_date_picker_roller_demo(mut w gui.Window) gui.View {
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

fn basic_svg_demo() gui.View {
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

fn basic_image_demo() gui.View {
	return gui.column(
		padding: gui.padding_none
		content: [
			gui.image(src: sample_image_path),
			gui.text(text: 'Pinard Falls, Oregon', text_style: gui.theme().n4),
		]
	)
}

fn basic_expand_panel_demo(w &gui.Window) gui.View {
	return expand_panel_sample(w)
}

fn basic_icons_demo() gui.View {
	return gui.row(
		content: [
			gui.text(text: gui.icon_github_alt, text_style: gui.theme().icon2),
			gui.text(text: gui.icon_twitter, text_style: gui.theme().icon2),
			gui.text(text: gui.icon_bug, text_style: gui.theme().icon2),
			gui.text(text: gui.icon_heart, text_style: gui.theme().icon2),
		]
	)
}

fn basic_animations_demo(mut w gui.Window) gui.View {
	app := w.state[ShowcaseApp]()
	box_color := if app.light_theme { gui.dark_blue } else { gui.cornflower_blue }
	return gui.column(
		spacing: gui.theme().spacing_small
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
				]
			),
			gui.row(
				height:  34
				sizing:  gui.fill_fixed
				padding: gui.padding_none
				content: [
					gui.row(
						width:   int(app.anim_tween_x)
						sizing:  gui.fixed_fit
						padding: gui.padding_none
					),
					gui.row(
						width:  24
						height: 24
						sizing: gui.fixed_fixed
						color:  box_color
						radius: 4
					),
				]
			),
		]
	)
}

fn basic_color_picker_demo(w &gui.Window) gui.View {
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

fn basic_markdown_demo(mut w gui.Window) gui.View {
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

fn basic_tab_control_demo(w &gui.Window) gui.View {
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

fn basic_tooltip_demo() gui.View {
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

fn basic_rectangle_demo() gui.View {
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

fn basic_scrollbar_demo() gui.View {
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
