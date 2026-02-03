import gui
import time
import rand

// ============================================================================
// Animation Stress Test
// ============================================================================
//
// This example demonstrates:
// 1. Managing many concurrent animations
// 2. Dynamic creation of animated elements
// 3. Mixing shapes and SVGs
// 4. Infinite animation loops via recursion
//
// ============================================================================

const icon_star = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>'
const icon_heart = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>'
const icon_face = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm3.5-9c.83 0 1.5-.67 1.5-1.5S16.33 8 15.5 8 14 8.67 14 9.5s.67 1.5 1.5 1.5zm-7 0c.83 0 1.5-.67 1.5-1.5S9.33 8 8.5 8 7 8.67 7 9.5 7.67 11 8.5 11zm3.5 6.5c2.33 0 4.31-1.46 5.11-3.5H6.89c.8 2.04 2.78 3.5 5.11 3.5z"/></svg>'
const icon_bolt = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M11 21h-1l1-7H7.5c-.58 0-.57-.32-.38-.66.19-.34.05-.08.07-.12C8.48 10.94 10.42 7.54 13 3h1l-1 7h3.5c.49 0 .56.33.47.51l-.07.15C12.96 17.55 11 21 11 21z"/></svg>'

enum ItemKind {
	circle
	rect
	svg
}

struct AnimatedItem {
	id    string
	kind  ItemKind
	icon  string // For SVGs
	color gui.Color
	size  f32
mut:
	x f32
	y f32
}

struct State {
mut:
	items   []AnimatedItem
	next_id int
	count   int
}

fn main() {
	mut window := gui.window(
		title:   'Animation Stress Test'
		state:   &State{}
		width:   1000
		height:  800
		on_init: fn (mut w gui.Window) {
			add_items(mut w, 10) // Start with 10 animations
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(mut window gui.Window) gui.View {
	state := window.state[State]()
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		content: [
			// Top bar with controls
			gui.row(
				spacing: 20
				v_align: .middle
				content: [
					gui.text(
						text:       'Active Animations: ${state.count}'
						text_style: gui.theme().b1
					),
					gui.button(
						content:  [gui.text(text: 'Add 10 Items')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							add_items(mut w, 10)
						}
					),
				]
			),
			// Animation area
			gui.canvas(
				id:      'canvas'
				sizing:  gui.fill_fill
				content: state.items.map(render_item(it))
			),
		]
	)
}

fn render_item(item AnimatedItem) gui.View {
	match item.kind {
		.svg {
			// Wrap SVG in a column to allow positioning
			return gui.column(
				id:      item.id
				x:       item.x
				y:       item.y
				width:   item.size
				height:  item.size
				sizing:  gui.fixed_fixed
				content: [
					gui.svg(
						width:    item.size
						height:   item.size
						sizing:   gui.fixed_fixed
						svg_data: item.icon
						color:    item.color
					),
				]
			)
		}
		.circle {
			return gui.column(
				id:     item.id
				x:      item.x
				y:      item.y
				width:  item.size
				height: item.size
				sizing: gui.fixed_fixed
				color:  item.color
				radius: item.size / 2
			)
		}
		.rect {
			return gui.column(
				id:     item.id
				x:      item.x
				y:      item.y
				width:  item.size
				height: item.size
				sizing: gui.fixed_fixed
				color:  item.color
				radius: item.size / 4
			)
		}
	}
}

fn add_items(mut w gui.Window, count int) {
	mut state := w.state[State]()
	width, height := w.window_size()

	// Avoid 0 sizes on init
	safe_w := if width <= 0 { f32(800) } else { width }
	safe_h := if height <= 0 { f32(600) } else { height }

	for _ in 0 .. count {
		state.next_id++
		id := 'item_${state.next_id}'

		// Random properties
		size := rand.f32_in_range(20, 60) or { 40.0 }
		x := rand.f32_in_range(0, safe_w - size) or { 0.0 }
		y := rand.f32_in_range(0, safe_h - 100 - size) or { 0.0 }

		val := rand.int_in_range(0, 3) or { 0 }
		kind := match val {
			0 { ItemKind.circle }
			1 { ItemKind.rect }
			else { ItemKind.svg }
		}

		icon := match rand.int_in_range(0, 4) or { 0 } {
			0 { icon_star }
			1 { icon_heart }
			2 { icon_face }
			else { icon_bolt }
		}

		// Bright, fun colors
		r := u8(rand.int_in_range(100, 255) or { 200 })
		g := u8(rand.int_in_range(100, 255) or { 200 })
		b := u8(rand.int_in_range(100, 255) or { 200 })
		color := gui.rgb(r, g, b)

		item := AnimatedItem{
			id:    id
			kind:  kind
			icon:  icon
			color: color
			size:  size
			x:     x
			y:     y
		}

		state.items << item
		state.count++

		// Start wandering animation
		start_wander(mut w, id)
	}
}

// start_wander initiates a continuous wandering animation for an item
fn start_wander(mut w gui.Window, id string) {
	// Need to check if item still exists (might handle removal later, though not in spec)
	if !w.state[State]().items.any(it.id == id) {
		return
	}

	state := w.state[State]()

	// Find current position from state
	// Note: In a real app we might want a map for faster lookup,
	// but array is fine for < 1000 items in this demo
	// We need the index to get the current values
	mut idx := -1
	for i, item in state.items {
		if item.id == id {
			idx = i
			break
		}
	}
	if idx == -1 {
		return
	}

	current_x := state.items[idx].x
	current_y := state.items[idx].y
	size := state.items[idx].size

	width, height := w.window_size()
	safe_w := if width <= 0 { f32(800) } else { width }
	safe_h := if height <= 0 { f32(600) } else { height }

	// Pick a random destination
	dest_x := rand.f32_in_range(0, safe_w - size) or { 0.0 }
	dest_y := rand.f32_in_range(0, safe_h - 100 - size) or { 0.0 }

	// Random duration for breezy feel (1-3 seconds)
	duration_ms := rand.int_in_range(1000, 3000) or { 2000 }

	// Random easing for variety
	easing := match rand.int_in_range(0, 5) or { 0 } {
		0 { gui.ease_in_out_quad }
		1 { gui.ease_out_cubic }
		2 { gui.ease_out_bounce } // occasional bounce is fun
		3 { gui.ease_out_elastic }
		else { gui.ease_linear }
	}

	// Animate X
	w.animation_add(mut gui.TweenAnimation{
		id:       '${id}_x'
		from:     current_x
		to:       dest_x
		duration: time.Duration(duration_ms) * time.millisecond
		easing:   easing
		on_value: fn [id] (v f32, mut w gui.Window) {
			mut s := w.state[State]()
			for mut item in s.items {
				if item.id == id {
					item.x = v
					break
				}
			}
		}
	})

	// Animate Y with same duration/easing to stay synced,
	// OR different for chaotic floating. Let's sync them for "movement".
	w.animation_add(mut gui.TweenAnimation{
		id:       '${id}_y'
		from:     current_y
		to:       dest_y
		duration: time.Duration(duration_ms) * time.millisecond
		easing:   easing
		on_value: fn [id] (v f32, mut w gui.Window) {
			mut s := w.state[State]()
			for mut item in s.items {
				if item.id == id {
					item.y = v
					break
				}
			}
		}
		// Chain the next movement
		on_done: fn [id] (mut w gui.Window) {
			start_wander(mut w, id)
		}
	})
}
