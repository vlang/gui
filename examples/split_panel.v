import gui

@[heap]
struct SplitPanelApp {
pub mut:
	main_state   gui.SplitterState = gui.SplitterState{
		ratio: 0.30
	}
	detail_state gui.SplitterState = gui.SplitterState{
		ratio: 0.55
	}
}

const id_focus_main_split = u32(51)
const id_focus_detail_split = u32(52)

fn main() {
	mut window := gui.window(
		state:   &SplitPanelApp{}
		width:   880
		height:  560
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[SplitPanelApp]()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		padding: gui.padding_none
		spacing: 0
		content: [
			gui.splitter(
				id:          'main_split'
				id_focus:    id_focus_main_split
				sizing:      gui.fill_fill
				orientation: .horizontal
				ratio:       app.main_state.ratio
				collapsed:   app.main_state.collapsed
				on_change:   on_main_split_change
				first:       gui.SplitterPaneCfg{
					min_size: 150
					max_size: 420
					content:  [
						left_panel(),
					]
				}
				second:      gui.SplitterPaneCfg{
					min_size: 250
					content:  [
						detail_split(window),
					]
				}
			),
		]
	)
}

fn detail_split(window &gui.Window) gui.View {
	app := window.state[SplitPanelApp]()
	return gui.splitter(
		id:                    'detail_split'
		id_focus:              id_focus_detail_split
		orientation:           .vertical
		sizing:                gui.fill_fill
		handle_size:           10
		show_collapse_buttons: true
		ratio:                 app.detail_state.ratio
		collapsed:             app.detail_state.collapsed
		on_change:             on_detail_split_change
		first:                 gui.SplitterPaneCfg{
			min_size: 140
			content:  [
				content_panel('Editor', 'Top pane. Drag divider or use keyboard arrows.'),
			]
		}
		second:                gui.SplitterPaneCfg{
			min_size: 120
			content:  [
				content_panel('Preview', 'Bottom pane. Home/End collapses panes.'),
			]
		}
	)
}

fn left_panel() gui.View {
	return gui.column(
		sizing:  gui.fill_fill
		padding: gui.padding(12, 12, 12, 12)
		spacing: 8
		color:   gui.theme().color_panel
		content: [
			gui.text(text: 'Project'),
			gui.text(text: '- src'),
			gui.text(text: '- docs'),
			gui.text(text: '- tests'),
			gui.text(
				text: 'Click a splitter then use arrow keys. Shift+arrow uses larger steps.'
				mode: .wrap
			),
		]
	)
}

fn content_panel(title string, note string) gui.View {
	return gui.column(
		sizing:  gui.fill_fill
		padding: gui.padding(12, 12, 12, 12)
		spacing: 8
		color:   gui.theme().color_panel
		content: [
			gui.text(text: title, text_style: gui.theme().b2),
			gui.text(text: note, mode: .wrap),
			gui.rectangle(
				sizing:       gui.fill_fill
				color:        gui.theme().color_background
				color_border: gui.theme().color_border
				size_border:  gui.theme().size_border
				radius:       gui.theme().radius_small
			),
		]
	)
}

fn on_main_split_change(ratio f32, collapsed gui.SplitterCollapsed, mut _e gui.Event, mut w gui.Window) {
	mut app := w.state[SplitPanelApp]()
	app.main_state = gui.splitter_state_normalize(gui.SplitterState{
		ratio:     ratio
		collapsed: collapsed
	})
}

fn on_detail_split_change(ratio f32, collapsed gui.SplitterCollapsed, mut _e gui.Event, mut w gui.Window) {
	mut app := w.state[SplitPanelApp]()
	app.detail_state = gui.splitter_state_normalize(gui.SplitterState{
		ratio:     ratio
		collapsed: collapsed
	})
}
