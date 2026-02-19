import gui
import time

// ============================================================================
// Benchmark Suite
// ============================================================================
//
// Measures full-rebuild throughput (view gen + layout + render) across
// widget count tiers, text-heavy, SVG-heavy, and mixed scenarios.
//
// ============================================================================

const icon_star = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>'
const icon_heart = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>'
const icon_face = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm3.5-9c.83 0 1.5-.67 1.5-1.5S16.33 8 15.5 8 14 8.67 14 9.5s.67 1.5 1.5 1.5zm-7 0c.83 0 1.5-.67 1.5-1.5S9.33 8 8.5 8 7 8.67 7 9.5 7.67 11 8.5 11zm3.5 6.5c2.33 0 4.31-1.46 5.11-3.5H6.89c.8 2.04 2.78 3.5 5.11 3.5z"/></svg>'
const icon_bolt = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M11 21h-1l1-7H7.5c-.58 0-.57-.32-.38-.66.19-.34.05-.08.07-.12C8.48 10.94 10.42 7.54 13 3h1l-1 7h3.5c.49 0 .56.33.47.51l-.07.15C12.96 17.55 11 21 11 21z"/></svg>'

const lorem_short = 'The quick brown fox jumps over the lazy dog.'
const lorem_medium = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor.'
const lorem_long = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Curabitur pretium tincidunt lacus sed.'

const svg_icons = [icon_star, icon_heart, icon_face, icon_bolt]
const svg_sizes = [f32(16), 24, 32, 48, 64]
const palette = [
	gui.rgb(231, 76, 60),
	gui.rgb(46, 204, 113),
	gui.rgb(52, 152, 219),
	gui.rgb(241, 196, 15),
	gui.rgb(155, 89, 182),
	gui.rgb(26, 188, 156),
]

enum Scenario {
	widgets_100
	widgets_500
	widgets_1000
	widgets_2000
	widgets_5000
	text_heavy
	svg_heavy
	mixed
}

struct State {
mut:
	scenario         Scenario
	rebuild_count    u64
	fps              f32
	last_fps_time    time.Time
	last_fps_count   u64
	last_view_gen_us i64
	paused           bool
}

fn main() {
	mut window := gui.window(
		title:        'Benchmark Suite'
		state:        &State{
			last_fps_time: time.now()
		}
		width:        1200
		height:       800
		debug_layout: true
		on_init:      fn (mut w gui.Window) {
			w.update_view(main_view)
			// Continuous full-rebuild animation
			w.animation_add(mut gui.Animate{
				id:       'bench_tick'
				repeat:   true
				delay:    16 * time.millisecond
				callback: fn (mut _ gui.Animate, mut w gui.Window) {
					w.update_window()
				}
			})
		}
		on_event:     fn (e &gui.Event, mut w gui.Window) {
			if e.typ == .key_down && e.key_code == .space {
				toggle_pause(mut w)
			}
		}
	)
	window.set_theme(gui.theme_dark)
	window.run()
}

fn toggle_pause(mut w gui.Window) {
	mut s := w.state[State]()
	s.paused = !s.paused
	if s.paused {
		w.remove_animation('bench_tick')
	} else {
		s.last_fps_time = time.now()
		s.last_fps_count = s.rebuild_count
		w.animation_add(mut gui.Animate{
			id:       'bench_tick'
			repeat:   true
			delay:    16 * time.millisecond
			callback: fn (mut _ gui.Animate, mut w gui.Window) {
				w.update_window()
			}
		})
	}
}

fn main_view(window &gui.Window) gui.View {
	vg_start := time.now()
	mut state := window.state[State]()
	w, h := window.window_size()
	stats := window.get_layout_stats()

	// Update rebuild count and FPS
	state.rebuild_count++
	now := time.now()
	elapsed := time.since(state.last_fps_time)
	if elapsed >= 1 * time.second {
		delta := state.rebuild_count - state.last_fps_count
		state.fps = f32(delta) / (f32(elapsed.microseconds()) / 1_000_000.0)
		state.last_fps_count = state.rebuild_count
		state.last_fps_time = now
	}

	content := gen_scenario(state.scenario)

	state.last_view_gen_us = time.since(vg_start).microseconds()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			// FPS + pause
			gui.row(
				padding: gui.padding(0, 5, 0, 5)
				spacing: 16
				v_align: .middle
				content: [
					gui.text(
						text:       'FPS: ${state.fps:.1f}'
						text_style: gui.theme().b1
						min_width:  140
					),
					gui.button(
						content:  [
							gui.row(
								min_width: 50
								h_align:   .center
								padding:   gui.padding_none
								content:   [
									gui.text(
										text: if state.paused {
											'Resume'
										} else {
											'Pause'
										}
									),
								]
							),
						]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							toggle_pause(mut w)
						}
					),
				]
			),
			// Stats bar
			gui.row(
				padding: gui.Padding{4, 8, 4, 8}
				spacing: 16
				v_align: .middle
				color:   gui.rgb(35, 35, 35)
				content: [
					gui.text(text: 'Nodes: ${stats.node_count}', min_width: 110),
					gui.text(text: 'Layout (μs): ${stats.total_time_us}', min_width: 140),
					gui.text(text: 'ViewGen (μs): ${state.last_view_gen_us}', min_width: 140),
					gui.text(text: 'Renderers: ${window.renderers_count()}', min_width: 120),
					gui.text(
						text:      'Mem (MB): ${f32(gc_memory_use()) / 1_048_576.0:.1f}'
						min_width: 120
					),
					gui.text(text: 'Rebuilds: ${state.rebuild_count}', min_width: 130),
				]
			),
			// Scenario selector
			gui.row(
				padding: gui.Padding{4, 8, 4, 8}
				spacing: 6
				v_align: .middle
				color:   gui.rgb(40, 40, 40)
				content: scenario_buttons(state.scenario)
			),
			// Scrollable content area
			gui.column(
				sizing:      gui.fill_fill
				id_scroll:   1
				scroll_mode: .vertical_only
				content:     content
			),
		]
	)
}

fn scenario_buttons(current Scenario) []gui.View {
	labels := ['100', '500', '1K', '2K', '5K', 'Text', 'SVG', 'Mixed']
	scenarios := [
		Scenario.widgets_100,
		.widgets_500,
		.widgets_1000,
		.widgets_2000,
		.widgets_5000,
		.text_heavy,
		.svg_heavy,
		.mixed,
	]
	mut buttons := []gui.View{cap: labels.len}
	for i, label in labels {
		sc := scenarios[i]
		is_active := current == sc
		buttons << gui.button(
			color:    if is_active { gui.rgb(80, 120, 200) } else { gui.rgb(60, 60, 60) }
			on_click: fn [sc] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
				mut s := w.state[State]()
				s.scenario = sc
			}
			content:  [gui.text(text: label)]
		)
	}
	return buttons
}

fn gen_scenario(scenario Scenario) []gui.View {
	return match scenario {
		.widgets_100 { gen_widgets(100) }
		.widgets_500 { gen_widgets(500) }
		.widgets_1000 { gen_widgets(1000) }
		.widgets_2000 { gen_widgets(2000) }
		.widgets_5000 { gen_widgets(5000) }
		.text_heavy { gen_text_heavy() }
		.svg_heavy { gen_svg_heavy() }
		.mixed { gen_mixed() }
	}
}

fn gen_widgets(count int) []gui.View {
	cols := 10
	rows := (count + cols - 1) / cols
	mut row_views := []gui.View{cap: rows}
	mut n := 0
	for r := 0; r < rows; r++ {
		mut cells := []gui.View{cap: cols}
		for c := 0; c < cols && n < count; c++ {
			cells << gui.column(
				width:  40
				height: 40
				sizing: gui.fixed_fixed
				color:  palette[n % palette.len]
				radius: 4
			)
			n++
		}
		row_views << gui.row(
			spacing: 2
			content: cells
		)
	}
	return row_views
}

fn gen_text_heavy() []gui.View {
	lorems := [lorem_short, lorem_medium, lorem_long]
	mut views := []gui.View{cap: 250}
	// 200 plain text views
	for i in 0 .. 200 {
		views << gui.text(
			text: lorems[i % lorems.len]
			mode: .wrap
		)
	}
	// 50 RTF views with bold+normal runs
	bold := gui.theme().b1
	normal := gui.theme().text_style
	for _ in 0 .. 50 {
		views << gui.rtf(
			rich_text: gui.RichText{
				runs: [
					gui.rich_run('Bold heading. ', bold),
					gui.rich_run(lorem_medium, normal),
				]
			}
			mode:      .wrap
		)
	}
	return views
}

fn gen_svg_heavy() []gui.View {
	mut views := []gui.View{cap: 200}
	for i in 0 .. 200 {
		sz := svg_sizes[i % svg_sizes.len]
		views << gui.svg(
			svg_data: svg_icons[i % svg_icons.len]
			width:    sz
			height:   sz
			sizing:   gui.fixed_fixed
			color:    palette[i % palette.len]
		)
	}
	return views
}

fn gen_mixed() []gui.View {
	mut views := []gui.View{cap: 500}
	// 200 rects
	for i in 0 .. 200 {
		views << gui.column(
			width:  30
			height: 30
			sizing: gui.fixed_fixed
			color:  palette[i % palette.len]
			radius: 3
		)
	}
	// 100 texts
	lorems := [lorem_short, lorem_medium, lorem_long]
	for i in 0 .. 100 {
		views << gui.text(
			text: lorems[i % lorems.len]
			mode: .wrap
		)
	}
	// 100 SVGs
	for i in 0 .. 100 {
		sz := svg_sizes[i % svg_sizes.len]
		views << gui.svg(
			svg_data: svg_icons[i % svg_icons.len]
			width:    sz
			height:   sz
			sizing:   gui.fixed_fixed
			color:    palette[i % palette.len]
		)
	}
	// 50 buttons
	for i in 0 .. 50 {
		views << gui.button(
			content: [gui.text(text: 'Btn ${i}')]
		)
	}
	// 50 progress bars
	for i in 0 .. 50 {
		views << gui.progress_bar(
			width:   200
			height:  16
			sizing:  gui.fixed_fixed
			percent: f32(i % 50) / 50.0
		)
	}
	return views
}
