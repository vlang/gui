// vtest build: present_sqlite3?
import db.sqlite
import gui
import sync

@[table: 'members']
struct MemberRow {
	id         int @[primary; sql: serial]
	name       string
	email      string
	status     string
	active     bool
	score      int
	start_date string
	team_id    int
}

@[table: 'teams']
struct TeamRow {
	id      int @[primary; sql: serial]
	name    string
	members []MemberRow @[fkey: 'team_id']
}

@[heap]
struct DataGridOrmDemoApp {
pub mut:
	source     ?gui.DataGridDataSource
	columns    []gui.GridColumnCfg
	query      gui.GridQueryState
	selection  gui.GridSelection
	use_offset bool
	fetcher    &SqliteGridOrmFetcher = unsafe { nil }
}

@[heap]
struct SqliteGridOrmFetcher {
mut:
	db      sqlite.DB
	mutex   &sync.Mutex = sync.new_mutex()
	columns map[string]gui.GridOrmColumnSpec
}

fn main() {
	mut window := gui.window(
		title:   'Data Grid ORM Demo'
		state:   &DataGridOrmDemoApp{}
		width:   1240
		height:  760
		on_init: fn (mut w gui.Window) {
			mut app := w.state[DataGridOrmDemoApp]()
			app.columns = orm_demo_grid_columns()
			mut fetcher := orm_demo_new_fetcher() or { panic(err) }
			app.fetcher = fetcher
			app.source = &gui.GridOrmDataSource{
				columns:         orm_demo_source_columns()
				default_limit:   180
				supports_offset: true
				row_count_known: true
				fetch_fn:        fn [mut fetcher] (spec gui.GridOrmQuerySpec, signal &gui.GridAbortSignal) !gui.GridOrmPage {
					return fetcher.fetch(spec, signal)
				}
			}
			w.update_view(orm_demo_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
	mut app := window.state[DataGridOrmDemoApp]()
	if !isnil(app.fetcher) {
		app.fetcher.close()
	}
}

fn orm_demo_view(mut window gui.Window) gui.View {
	mut app := window.state[DataGridOrmDemoApp]()
	stats := window.data_grid_source_stats('orm-grid')
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
			gui.text(text: 'Data Grid ORM Demo (SQLite + V ORM)', text_style: gui.theme().b2),
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
							mut state := w.state[DataGridOrmDemoApp]()
							state.use_offset = !state.use_offset
						}
					),
				]
			),
			gui.text(
				text:       'mode=${mode} loading=${loading} req=${stats.request_count} cancel=${stats.cancelled_count} stale=${stats.stale_drop_count} rows=${stats.received_count}/${count_text}'
				text_style: gui.theme().n4
			),
			window.data_grid(
				id:                  'orm-grid'
				max_height:          620
				show_quick_filter:   true
				show_filter_row:     true
				columns:             app.columns
				data_source:         app.source
				pagination_kind:     if app.use_offset {
					gui.GridPaginationKind.offset
				} else {
					gui.GridPaginationKind.cursor
				}
				page_limit:          180
				query:               app.query
				selection:           app.selection
				on_query_change:     fn (query gui.GridQueryState, mut _ gui.Event, mut w gui.Window) {
					w.state[DataGridOrmDemoApp]().query = query
				}
				on_selection_change: fn (selection gui.GridSelection, mut _ gui.Event, mut w gui.Window) {
					w.state[DataGridOrmDemoApp]().selection = selection
				}
			),
		]
	)
}

fn orm_demo_grid_columns() []gui.GridColumnCfg {
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
			id:    'email'
			title: 'Email'
			width: 240
		},
		gui.GridColumnCfg{
			id:    'status'
			title: 'Status'
			width: 120
		},
		gui.GridColumnCfg{
			id:    'active'
			title: 'Active'
			width: 90
		},
		gui.GridColumnCfg{
			id:    'score'
			title: 'Score'
			width: 100
			align: .end
		},
		gui.GridColumnCfg{
			id:    'start'
			title: 'Start'
			width: 130
		},
	]
}

fn orm_demo_source_columns() []gui.GridOrmColumnSpec {
	return [
		gui.GridOrmColumnSpec{
			id:               'name'
			db_field:         'm.name'
			quick_filter:     true
			filterable:       true
			sortable:         true
			case_insensitive: true
		},
		gui.GridOrmColumnSpec{
			id:               'team'
			db_field:         't.name'
			quick_filter:     true
			filterable:       true
			sortable:         true
			case_insensitive: true
		},
		gui.GridOrmColumnSpec{
			id:               'email'
			db_field:         'm.email'
			quick_filter:     true
			filterable:       true
			sortable:         true
			case_insensitive: true
		},
		gui.GridOrmColumnSpec{
			id:               'status'
			db_field:         'm.status'
			quick_filter:     true
			filterable:       true
			sortable:         true
			case_insensitive: true
		},
		gui.GridOrmColumnSpec{
			id:               'active'
			db_field:         'm.active'
			quick_filter:     false
			filterable:       true
			sortable:         true
			case_insensitive: false
			allowed_ops:      ['equals']
		},
		gui.GridOrmColumnSpec{
			id:               'score'
			db_field:         'm.score'
			quick_filter:     false
			filterable:       true
			sortable:         true
			case_insensitive: false
			allowed_ops:      ['equals']
		},
		gui.GridOrmColumnSpec{
			id:               'start'
			db_field:         'm.start_date'
			quick_filter:     true
			filterable:       true
			sortable:         true
			case_insensitive: true
		},
	]
}

fn orm_demo_new_fetcher() !&SqliteGridOrmFetcher {
	mut db := sqlite.connect(':memory:')!
	orm_demo_seed(mut db, 9000)!
	return &SqliteGridOrmFetcher{
		db:      db
		columns: orm_demo_column_map(orm_demo_source_columns())
	}
}

fn orm_demo_column_map(columns []gui.GridOrmColumnSpec) map[string]gui.GridOrmColumnSpec {
	mut out := map[string]gui.GridOrmColumnSpec{}
	for col in columns {
		out[col.id] = col
	}
	return out
}

fn orm_demo_seed(mut db sqlite.DB, count int) ! {
	sql db {
		create table TeamRow
		create table MemberRow
	}!
	teams := ['Core', 'Data', 'Platform', 'R&D', 'Web', 'Security']
	statuses := ['Open', 'Paused', 'Closed']
	start_dates := ['1/12/2026', '2/5/2026', '3/18/2026', '4/22/2026', '5/9/2026']
	for team_name in teams {
		team := TeamRow{
			name: team_name
		}
		sql db {
			insert team into TeamRow
		}!
	}
	for i in 0 .. count {
		id := i + 1
		member := MemberRow{
			name:       'User ${id}'
			email:      'user${id}@grid.dev'
			status:     statuses[i % statuses.len]
			active:     i % 2 == 0
			score:      60 + ((i * 7) % 41)
			start_date: start_dates[i % start_dates.len]
			team_id:    (i % teams.len) + 1
		}
		sql db {
			insert member into MemberRow
		}!
	}
}

fn (mut fetcher SqliteGridOrmFetcher) close() {
	fetcher.mutex.lock()
	defer {
		fetcher.mutex.unlock()
	}
	fetcher.db.close() or {}
}

fn (mut fetcher SqliteGridOrmFetcher) fetch(spec gui.GridOrmQuerySpec, signal &gui.GridAbortSignal) !gui.GridOrmPage {
	if !isnil(signal) && signal.is_aborted() {
		return error('request aborted')
	}
	fetcher.mutex.lock()
	defer {
		fetcher.mutex.unlock()
	}
	mut where_parts := []string{}
	mut params := []string{}
	orm_demo_apply_quick_filter(spec, fetcher.columns, mut where_parts, mut params)
	for filter in spec.filters {
		col := fetcher.columns[filter.col_id] or { continue }
		if !col.filterable {
			continue
		}
		clause, value := orm_demo_filter_clause(col.db_field, filter.op, filter.value,
			col.case_insensitive)
		where_parts << clause
		params << value
	}
	mut order_parts := []string{}
	for sort in spec.sorts {
		col := fetcher.columns[sort.col_id] or { continue }
		if !col.sortable {
			continue
		}
		dir := if sort.dir == .desc { 'desc' } else { 'asc' }
		order_parts << '${col.db_field} ${dir}'
	}
	if order_parts.len == 0 {
		order_parts << 'm.id asc'
	}
	base_from := ' from members m join teams t on t.id = m.team_id'
	where_sql := if where_parts.len > 0 {
		' where ${where_parts.join(' and ')}'
	} else {
		''
	}
	order_sql := order_parts.join(', ')
	rows_sql := 'select m.id, m.name, t.name, m.email, m.status, m.active, m.score, m.start_date${base_from}${where_sql} order by ${order_sql} limit ? offset ?'
	mut row_params := params.clone()
	row_params << spec.limit.str()
	row_params << spec.offset.str()
	sql_rows := fetcher.db.exec_param_many(rows_sql, row_params)!
	count_sql := 'select count(*)${base_from}${where_sql}'
	count_rows := fetcher.db.exec_param_many(count_sql, params)!
	total := if count_rows.len > 0 && count_rows[0].vals.len > 0 {
		count_rows[0].vals[0].int()
	} else {
		0
	}
	mut rows := []gui.GridRow{cap: sql_rows.len}
	for row in sql_rows {
		if !isnil(signal) && signal.is_aborted() {
			return error('request aborted')
		}
		if row.vals.len < 8 {
			continue
		}
		rows << gui.GridRow{
			id:    row.vals[0]
			cells: {
				'name':   row.vals[1]
				'team':   row.vals[2]
				'email':  row.vals[3]
				'status': row.vals[4]
				'active': orm_demo_bool_text(row.vals[5])
				'score':  row.vals[6]
				'start':  row.vals[7]
			}
		}
	}
	next_offset := spec.offset + rows.len
	has_more := next_offset < total
	prev_offset := if spec.offset > spec.limit {
		spec.offset - spec.limit
	} else {
		0
	}
	return gui.GridOrmPage{
		rows:        rows
		next_cursor: if has_more { 'i:${next_offset}' } else { '' }
		prev_cursor: if spec.offset > 0 { 'i:${prev_offset}' } else { '' }
		row_count:   ?int(total)
		has_more:    has_more
	}
}

fn orm_demo_apply_quick_filter(spec gui.GridOrmQuerySpec, columns map[string]gui.GridOrmColumnSpec, mut where_parts []string, mut params []string) {
	needle := spec.quick_filter.trim_space()
	if needle.len == 0 {
		return
	}
	lower_needle := needle.to_lower()
	mut or_parts := []string{}
	for _, col in columns {
		if !col.quick_filter {
			continue
		}
		if col.case_insensitive {
			or_parts << 'lower(${col.db_field}) like ?'
			params << '%${lower_needle}%'
			continue
		}
		or_parts << '${col.db_field} like ?'
		params << '%${needle}%'
	}
	if or_parts.len > 0 {
		where_parts << '(${or_parts.join(' or ')})'
	}
}

fn orm_demo_filter_clause(field string, op string, value string, case_insensitive bool) (string, string) {
	target_field := if case_insensitive { 'lower(${field})' } else { field }
	target_value := if case_insensitive { value.to_lower() } else { value }
	return match op {
		'equals' { '${target_field} = ?', target_value }
		'starts_with' { '${target_field} like ?', '${target_value}%' }
		'ends_with' { '${target_field} like ?', '%${target_value}' }
		else { '${target_field} like ?', '%${target_value}%' }
	}
}

fn orm_demo_bool_text(input string) string {
	lower := input.trim_space().to_lower()
	if lower in ['1', 'true', 't', 'yes', 'y'] {
		return 'true'
	}
	return 'false'
}
