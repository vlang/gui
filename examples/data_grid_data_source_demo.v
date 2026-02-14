import gui

@[heap]
struct DataGridSourceDemoApp {
pub mut:
	all_rows         []gui.GridRow
	source           ?gui.DataGridDataSource
	columns          []gui.GridColumnCfg
	query            gui.GridQueryState
	selection        gui.GridSelection
	use_offset       bool
	simulate_latency bool = true
	last_action      string
}

fn main() {
	mut window := gui.window(
		title:   'Data Grid Data Source Demo'
		state:   &DataGridSourceDemoApp{}
		width:   1240
		height:  760
		on_init: fn (mut w gui.Window) {
			mut app := w.state[DataGridSourceDemoApp]()
			app.all_rows = data_source_demo_rows(50000)
			app.columns = data_source_demo_columns()
			data_source_demo_rebuild_source(mut app)
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	mut app := window.state[DataGridSourceDemoApp]()
	stats := window.data_grid_source_stats('source-grid')
	mode := if app.use_offset { 'offset' } else { 'cursor' }
	loading := if stats.loading { 'yes' } else { 'no' }
	count_text := if count := stats.row_count {
		count.str()
	} else {
		'?'
	}
	return gui.column(
		padding: gui.padding_small
		spacing: gui.spacing_small
		content: [
			gui.text(text: 'Data Source Demo (50k rows)', text_style: gui.theme().b2),
			gui.row(
				v_align: .middle
				sizing:  gui.fill_fit
				spacing: gui.spacing_small
				content: [
					gui.switch(
						id_focus: 301
						label:    'Use offset pagination'
						select:   app.use_offset
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[DataGridSourceDemoApp]()
							state.use_offset = !state.use_offset
							data_source_demo_rebuild_source(mut state)
						}
					),
					gui.switch(
						id_focus: 302
						label:    'Simulate latency'
						select:   app.simulate_latency
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							mut state := w.state[DataGridSourceDemoApp]()
							state.simulate_latency = !state.simulate_latency
							data_source_demo_rebuild_source(mut state)
						}
					),
				]
			),
			gui.text(
				text:       'mode=${mode} loading=${loading} req=${stats.request_count} cancel=${stats.cancelled_count} stale=${stats.stale_drop_count} rows=${stats.received_count}/${count_text} ${app.last_action}'
				text_style: gui.theme().n4
			),
			window.data_grid(
				id:                  'source-grid'
				max_height:          620
				show_crud_toolbar:   true
				show_quick_filter:   true
				columns:             app.columns
				data_source:         app.source
				pagination_kind:     if app.use_offset {
					gui.GridPaginationKind.offset
				} else {
					gui.GridPaginationKind.cursor
				}
				page_limit:          220
				query:               app.query
				selection:           app.selection
				on_query_change:     fn (query gui.GridQueryState, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[DataGridSourceDemoApp]()
					state.query = query
				}
				on_selection_change: fn (selection gui.GridSelection, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[DataGridSourceDemoApp]()
					state.selection = selection
				}
				on_cell_edit:        fn (edit gui.GridCellEdit, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[DataGridSourceDemoApp]()
					state.last_action = 'Edited ${edit.row_id}.${edit.col_id}'
				}
				on_crud_error:       fn (msg string, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[DataGridSourceDemoApp]()
					state.last_action = 'CRUD error: ${msg}'
				}
			),
		]
	)
}

fn data_source_demo_rebuild_source(mut app DataGridSourceDemoApp) {
	latency := if app.simulate_latency { 140 } else { 0 }
	app.source = &gui.InMemoryDataSource{
		rows:            app.all_rows
		default_limit:   220
		latency_ms:      latency
		supports_cursor: !app.use_offset
	}
}

fn data_source_demo_columns() []gui.GridColumnCfg {
	return [
		gui.GridColumnCfg{
			id:            'name'
			title:         'Name'
			width:         180
			editable:      true
			default_value: 'New User'
		},
		gui.GridColumnCfg{
			id:             'team'
			title:          'Team'
			width:          140
			editable:       true
			editor:         .select
			editor_options: ['Core', 'Data', 'Platform', 'R&D', 'Web', 'Security']
			default_value:  'Core'
		},
		gui.GridColumnCfg{
			id:            'email'
			title:         'Email'
			width:         250
			editable:      true
			default_value: 'new@grid.dev'
		},
		gui.GridColumnCfg{
			id:             'status'
			title:          'Status'
			width:          120
			editable:       true
			editor:         .select
			editor_options: ['Open', 'Paused', 'Closed']
			default_value:  'Open'
		},
		gui.GridColumnCfg{
			id:            'active'
			title:         'Active'
			width:         90
			editable:      true
			editor:        .checkbox
			default_value: 'true'
		},
		gui.GridColumnCfg{
			id:            'score'
			title:         'Score'
			width:         110
			align:         .end
			editable:      true
			default_value: '70'
		},
		gui.GridColumnCfg{
			id:            'start'
			title:         'Start'
			width:         130
			editable:      true
			editor:        .date
			default_value: '1/1/2026'
		},
	]
}

fn data_source_demo_rows(count int) []gui.GridRow {
	names := ['Ada', 'Grace', 'Alan', 'Katherine', 'Barbara', 'Linus', 'Margaret', 'Edsger']
	teams := ['Core', 'Data', 'Platform', 'R&D', 'Web', 'Security']
	statuses := ['Open', 'Paused', 'Closed']
	start_dates := ['1/12/2026', '2/5/2026', '3/18/2026', '4/22/2026', '5/9/2026']
	mut rows := []gui.GridRow{cap: count}
	for i in 0 .. count {
		id := i + 1
		rows << gui.GridRow{
			id:    '${id}'
			cells: {
				'name':   '${names[i % names.len]} ${id}'
				'team':   teams[(i / 300) % teams.len]
				'email':  'user${id}@grid.dev'
				'status': statuses[i % statuses.len]
				'active': if i % 2 == 0 { 'true' } else { 'false' }
				'score':  '${60 + ((i * 7) % 41)}'
				'start':  start_dates[i % start_dates.len]
			}
		}
	}
	return rows
}
