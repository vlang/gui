import gui

@[heap]
struct DataGridDemoApp {
pub mut:
	all_rows     []gui.GridRow
	columns      []gui.GridColumnCfg
	column_order []string
	detail_ids   map[string]bool
	query        gui.GridQueryState
	selection    gui.GridSelection
	last_action  string
}

fn main() {
	mut window := gui.window(
		title:   'Data Grid Demo'
		state:   &DataGridDemoApp{}
		width:   980
		height:  640
		on_init: fn (mut w gui.Window) {
			mut app := w.state[DataGridDemoApp]()
			app.all_rows = sample_rows()
			app.columns = sample_columns()
			app.column_order = app.columns.map(it.id)
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	mut app := window.state[DataGridDemoApp]()
	rows := apply_query(app.all_rows, app.query)
	return gui.column(
		padding: gui.padding_small
		spacing: gui.spacing_small
		content: [
			gui.text(text: 'Data Grid v1 Demo', text_style: gui.theme().b2),
			gui.text(
				text:       'Rows: ${rows.len}  Selected: ${app.selection.selected_row_ids.len}  ${app.last_action}'
				text_style: gui.theme().n4
			),
			window.data_grid(
				id:                        'demo-grid'
				max_height:                520
				columns:                   app.columns
				column_order:              app.column_order
				group_by:                  ['team']
				aggregates:                [gui.GridAggregateCfg{
					op:    .count
					label: 'count'
				}, gui.GridAggregateCfg{
					op:     .avg
					col_id: 'score'
					label:  'avg score'
				}, gui.GridAggregateCfg{
					op:     .max
					col_id: 'score'
					label:  'max score'
				}]
				rows:                      rows
				query:                     app.query
				selection:                 app.selection
				detail_expanded_row_ids:   app.detail_ids
				on_query_change:           fn (query gui.GridQueryState, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[DataGridDemoApp]()
					state.query = query
				}
				on_selection_change:       fn (selection gui.GridSelection, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[DataGridDemoApp]()
					state.selection = selection
				}
				on_column_order_change:    fn (order []string, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[DataGridDemoApp]()
					state.column_order = order.clone()
				}
				on_column_pin_change:      fn (col_id string, pin gui.GridColumnPin, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[DataGridDemoApp]()
					mut cols := state.columns.clone()
					for i, col in cols {
						if col.id == col_id {
							cols[i] = gui.GridColumnCfg{
								...col
								pin: pin
							}
							break
						}
					}
					state.columns = cols
				}
				on_detail_expanded_change: fn (detail_ids map[string]bool, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[DataGridDemoApp]()
					state.detail_ids = detail_ids.clone()
				}
				on_detail_row_view:        fn (row gui.GridRow, mut _ gui.Window) gui.View {
					team := row.cells['team'] or { '' }
					email := row.cells['email'] or { '' }
					score := row.cells['score'] or { '' }
					return gui.row(
						padding: gui.padding_two_five
						sizing:  gui.fill_fill
						color:   gui.color_transparent
						content: [
							gui.text(
								text:       'team: ${team}  email: ${email}  score: ${score}'
								mode:       .single_line
								text_style: gui.theme().n4
							),
						]
					)
				}
				on_cell_edit:              fn (edit gui.GridCellEdit, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[DataGridDemoApp]()
					mut rows := state.all_rows.clone()
					for i, row in rows {
						if row.id != edit.row_id {
							continue
						}
						mut cells := row.cells.clone()
						cells[edit.col_id] = edit.value
						rows[i] = gui.GridRow{
							...row
							cells: cells
						}
						break
					}
					state.all_rows = rows
					state.last_action = 'Edited ${edit.row_id}.${edit.col_id}'
				}
				on_row_activate:           fn (row gui.GridRow, mut _ gui.Event, mut w gui.Window) {
					mut state := w.state[DataGridDemoApp]()
					state.last_action = 'Activated row ${row.id}'
				}
			),
		]
	)
}

fn sample_columns() []gui.GridColumnCfg {
	return [
		gui.GridColumnCfg{
			id:       'name'
			title:    'Name'
			width:    180
			editable: true
			editor:   .text
		},
		gui.GridColumnCfg{
			id:             'team'
			title:          'Team'
			width:          160
			editable:       true
			editor:         .select
			editor_options: ['Core', 'Data', 'Platform', 'R&D', 'Security', 'Web']
		},
		gui.GridColumnCfg{
			id:       'email'
			title:    'Email'
			width:    260
			editable: true
			editor:   .text
		},
		gui.GridColumnCfg{
			id:             'status'
			title:          'Status'
			width:          120
			editable:       true
			editor:         .select
			editor_options: ['Open', 'Paused', 'Closed']
		},
		gui.GridColumnCfg{
			id:       'active'
			title:    'Active'
			width:    90
			editable: true
			editor:   .checkbox
		},
		gui.GridColumnCfg{
			id:       'start'
			title:    'Start'
			width:    130
			editable: true
			editor:   .date
		},
		gui.GridColumnCfg{
			id:    'score'
			title: 'Score'
			width: 120
			align: .end
		},
	]
}

fn sample_rows() []gui.GridRow {
	names := [
		'Ada Lovelace',
		'Grace Hopper',
		'Alan Turing',
		'Katherine Johnson',
		'Barbara Liskov',
		'Linus Torvalds',
		'Margaret Hamilton',
		'Edsger Dijkstra',
		'Donald Knuth',
		'Tim Berners-Lee',
	]
	teams := ['R&D', 'Platform', 'Data', 'Core', 'Web', 'Security']
	statuses := ['Open', 'Paused', 'Closed']
	start_dates := ['1/12/2026', '2/5/2026', '3/18/2026', '4/22/2026', '5/9/2026']
	mut rows := []gui.GridRow{cap: 800}
	for i in 0 .. 800 {
		row_id := i + 1
		name := names[i % names.len]
		team := teams[(i / 120) % teams.len]
		status := statuses[i % statuses.len]
		start := start_dates[i % start_dates.len]
		active := if i % 2 == 0 { 'true' } else { 'false' }
		score := 60 + ((i * 7) % 41)
		rows << gui.GridRow{
			id:    '${row_id}'
			cells: {
				'name':   '${name} ${row_id}'
				'team':   team
				'email':  'user${row_id}@lab.dev'
				'status': status
				'active': active
				'start':  start
				'score':  '${score}'
			}
		}
	}
	return rows
}

fn apply_query(rows []gui.GridRow, query gui.GridQueryState) []gui.GridRow {
	mut filtered := rows.filter(row_matches_query(it, query))
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

fn row_matches_query(row gui.GridRow, query gui.GridQueryState) bool {
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
