// Snake Game
//
// Classic snake arcade game. Control a snake that continuously moves in one direction.
// Eat red food pellets to grow longer and increase your score. The game ends when the
// snake collides with a wall or its own body.
//
// Rules:
// - Snake moves automatically in current direction
// - Eating food adds one segment and awards 10 points
// - Game speeds up slightly with each food eaten (200ms → 80ms minimum)
// - Cannot reverse direction (e.g., can't go left while moving right)
// - Collision with walls or self ends the game
//
// Controls: Arrow keys or WASD to change direction, SPACE to start/restart
//
// Algorithm:
// - Game state stored in SnakeGame struct (snake body as Point array, direction, food, score)
// - TweenAnimation drives game loop, calling tick() at regular intervals
// - Each tick: advance eat animation, apply buffered direction, compute new head position,
//   check collisions, prepend head to snake array, remove tail (unless food eaten)
// - Food spawns randomly on empty cells
// - Rendering uses gui.canvas with absolute positioning for grid-based display
import gui
import time
import rand

struct Point {
	x int
	y int
}

enum Direction {
	up
	down
	left
	right
}

@[heap]
struct SnakeGame {
pub mut:
	snake       []Point
	direction   Direction = .right
	next_dir    Direction = .right
	food        Point
	game_over   bool
	playing     bool
	score       int
	grid_w      int = 20
	grid_h      int = 15
	cell_size   int = 25
	tick_ms     int = 200
	eat_segment int = -1
}

fn main() {
	game := SnakeGame{}
	// derive window size from grid dimensions
	win_w := game.grid_w * game.cell_size + 70 // 25 left + 25 right + 20 padding
	win_h := game.grid_h * game.cell_size + 120 // 60 top + 35 bottom + 25 padding
	mut window := gui.window(
		state:    &SnakeGame{}
		title:    'Snake'
		width:    win_w
		height:   win_h
		on_event: on_event
		on_init:  fn (mut w gui.Window) {
			w.update_view(intro_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

// game tuning constants
const eat_anim_frames = 3
const brightness_step = 8
const min_tick_ms = 80
const tick_speedup = 5

// colors
const color_eat_flash = gui.Color{100, 149, 237, 255} // cornflower blue

// block patterns for SNAKE letters (5x7 grid each)
const letter_s = [
	[1, 1, 1, 1, 1],
	[1, 0, 0, 0, 0],
	[1, 0, 0, 0, 0],
	[1, 1, 1, 1, 1],
	[0, 0, 0, 0, 1],
	[0, 0, 0, 0, 1],
	[1, 1, 1, 1, 1],
]
const letter_n = [
	[1, 0, 0, 0, 1],
	[1, 1, 0, 0, 1],
	[1, 0, 1, 0, 1],
	[1, 0, 0, 1, 1],
	[1, 0, 0, 0, 1],
	[1, 0, 0, 0, 1],
	[1, 0, 0, 0, 1],
]
const letter_a = [
	[0, 1, 1, 1, 0],
	[1, 0, 0, 0, 1],
	[1, 0, 0, 0, 1],
	[1, 1, 1, 1, 1],
	[1, 0, 0, 0, 1],
	[1, 0, 0, 0, 1],
	[1, 0, 0, 0, 1],
]
const letter_k = [
	[1, 0, 0, 0, 1],
	[1, 0, 0, 1, 0],
	[1, 0, 1, 0, 0],
	[1, 1, 0, 0, 0],
	[1, 0, 1, 0, 0],
	[1, 0, 0, 1, 0],
	[1, 0, 0, 0, 1],
]
const letter_e = [
	[1, 1, 1, 1, 1],
	[1, 0, 0, 0, 0],
	[1, 0, 0, 0, 0],
	[1, 1, 1, 1, 0],
	[1, 0, 0, 0, 0],
	[1, 0, 0, 0, 0],
	[1, 1, 1, 1, 1],
]

fn intro_view(mut w gui.Window) gui.View {
	width, height := w.window_size()
	mut content := []gui.View{}

	// render SNAKE in blocks
	letters := [letter_s, letter_n, letter_a, letter_k, letter_e]
	block_size := 12
	letter_w := 5 * block_size
	spacing := 8
	total_w := 5 * letter_w + 4 * spacing
	start_x := (width - total_w) / 2

	// calculate vertical centering
	title_h := 7 * block_size
	rules_gap := 40
	rules_h := 100
	prompt_gap := 30
	prompt_h := 20 // approximate height for fit-sized prompt
	total_h := title_h + rules_gap + rules_h + prompt_gap + prompt_h
	start_y := (height - total_h) / 2

	for li, letter in letters {
		lx := start_x + li * (letter_w + spacing)
		for row, cols in letter {
			for col, val in cols {
				if val == 1 {
					bx := lx + col * block_size
					by := start_y + row * block_size
					// gradient along the word
					idx := li * 5 + col
					brightness := 255 - idx * 6
					green := u8(if brightness > 150 { brightness } else { 150 })
					content << gui.column(
						x:      bx
						y:      by
						width:  block_size - 2
						height: block_size - 2
						sizing: gui.fixed_fixed
						color:  gui.Color{50, green, 50, 255}
						radius: 3
					)
				}
			}
		}
	}

	// glow effect behind title
	content << gui.column(
		x:      start_x
		y:      start_y
		width:  total_w
		height: 7 * block_size
		sizing: gui.fixed_fixed
		shadow: &gui.BoxShadow{
			blur_radius: 30
			color:       gui.Color{0, 255, 0, 40}
		}
	)

	// rules
	rules_y := start_y + title_h + rules_gap
	content << gui.column(
		x:       0
		y:       rules_y
		width:   width
		sizing:  gui.Sizing{
			width:  .fixed
			height: .fit
		}
		h_align: .center
		spacing: 15
		content: [
			gui.text(
				text:       'HOW TO PLAY'
				text_style: gui.TextStyle{
					size:  18
					color: gui.Color{100, 255, 100, 255}
				}
			),
			gui.text(
				text:       'Use ARROW KEYS or WASD to move'
				text_style: gui.TextStyle{
					size:  14
					color: gui.Color{180, 180, 180, 255}
				}
			),
			gui.text(
				text:       'Eat the red food to grow'
				text_style: gui.TextStyle{
					size:  14
					color: gui.Color{180, 180, 180, 255}
				}
			),
			gui.text(
				text:       'Avoid walls and yourself'
				text_style: gui.TextStyle{
					size:  14
					color: gui.Color{180, 180, 180, 255}
				}
			),
		]
	)

	// press space prompt
	prompt_y := rules_y + rules_h + prompt_gap
	content << gui.column(
		x:       0
		y:       prompt_y
		width:   width
		sizing:  gui.Sizing{
			width:  .fixed
			height: .fit
		}
		h_align: .center
		content: [
			gui.text(
				text:       'PRESS SPACE TO START'
				text_style: gui.TextStyle{
					size:  16
					color: gui.Color{255, 255, 100, 255}
				}
			),
		]
	)

	return gui.canvas(
		width:   width
		height:  height
		sizing:  gui.fixed_fixed
		color:   gui.Color{20, 20, 30, 255}
		content: content
	)
}

fn start_game_loop(mut w gui.Window) {
	state := w.state[SnakeGame]()
	w.animation_add(mut gui.TweenAnimation{
		id:       'game_tick'
		from:     0
		to:       1
		duration: state.tick_ms * time.millisecond
		on_value: fn (_ f32, mut _ gui.Window) {}
		on_done:  fn (mut w gui.Window) {
			mut s := w.state[SnakeGame]()
			if s.game_over {
				return
			}
			s.tick()
			start_game_loop(mut w)
		}
	})
}

fn (mut g SnakeGame) init_game() {
	g.snake = [Point{5, 7}, Point{4, 7}, Point{3, 7}]
	g.direction = .right
	g.next_dir = .right
	g.game_over = false
	g.score = 0
	g.tick_ms = 200
	g.spawn_food()
}

fn (mut g SnakeGame) spawn_food() {
	// safety: avoid infinite loop if snake fills grid
	max_attempts := g.grid_w * g.grid_h
	for _ in 0 .. max_attempts {
		g.food = Point{rand.intn(g.grid_w) or { 0 }, rand.intn(g.grid_h) or { 0 }}
		if g.food !in g.snake {
			return
		}
	}
	// snake fills grid - player wins (no valid food position)
	g.game_over = true
}

fn (mut g SnakeGame) tick() {
	// progress eat animation through segments
	if g.eat_segment >= 0 {
		g.eat_segment += 1
		if g.eat_segment >= eat_anim_frames {
			g.eat_segment = -1
		}
	}

	g.direction = g.next_dir
	head := g.snake[0]
	mut new_head := head

	match g.direction {
		.up { new_head = Point{head.x, head.y - 1} }
		.down { new_head = Point{head.x, head.y + 1} }
		.left { new_head = Point{head.x - 1, head.y} }
		.right { new_head = Point{head.x + 1, head.y} }
	}

	// wall collision
	if new_head.x < 0 || new_head.x >= g.grid_w || new_head.y < 0 || new_head.y >= g.grid_h {
		g.game_over = true
		return
	}

	// self collision
	if new_head in g.snake {
		g.game_over = true
		return
	}

	g.snake.prepend(new_head)

	if new_head == g.food {
		g.score += 10
		g.eat_segment = 0
		if g.tick_ms > min_tick_ms {
			g.tick_ms -= tick_speedup
		}
		g.spawn_food()
	} else {
		g.snake.pop()
	}
}

fn on_event(e &gui.Event, mut w gui.Window) {
	if e.typ != .key_down {
		return
	}
	mut state := w.state[SnakeGame]()

	// start game from intro
	if !state.playing {
		if e.key_code == .space {
			state.playing = true
			state.init_game()
			start_game_loop(mut w)
			w.update_view(main_view)
		}
		return
	}

	if state.game_over {
		if e.key_code == .space {
			state.init_game()
		}
		return
	}

	dir := state.direction
	match e.key_code {
		.up, .w {
			if dir != .down {
				state.next_dir = .up
			}
		}
		.down, .s {
			if dir != .up {
				state.next_dir = .down
			}
		}
		.left, .a {
			if dir != .right {
				state.next_dir = .left
			}
		}
		.right, .d {
			if dir != .left {
				state.next_dir = .right
			}
		}
		else {}
	}
}

fn main_view(mut w gui.Window) gui.View {
	state := w.state[SnakeGame]()
	width, height := w.window_size()

	board_w := state.grid_w * state.cell_size
	board_h := state.grid_h * state.cell_size
	offset_x := 25
	offset_y := 60

	mut content := []gui.View{}

	// board background
	border_color := if state.game_over {
		gui.Color{255, 50, 50, 255}
	} else {
		gui.Color{80, 180, 80, 255}
	}
	content << gui.column(
		x:            offset_x
		y:            offset_y
		width:        board_w
		height:       board_h
		sizing:       gui.fixed_fixed
		color:        gui.Color{20, 30, 20, 255}
		color_border: border_color
		size_border:  4
	)

	// food with glow
	fx := offset_x + state.food.x * state.cell_size + 2
	fy := offset_y + state.food.y * state.cell_size + 2
	content << gui.column(
		x:      fx
		y:      fy
		width:  state.cell_size - 4
		height: state.cell_size - 4
		sizing: gui.fixed_fixed
		color:  gui.Color{255, 60, 60, 255}
		radius: (state.cell_size - 4) / 2
		shadow: &gui.BoxShadow{
			blur_radius: 15
			color:       gui.Color{255, 0, 0, 150}
		}
	)

	// snake segments
	for i, seg in state.snake {
		sx := offset_x + seg.x * state.cell_size + 2
		sy := offset_y + seg.y * state.cell_size + 2

		// check if this segment is animating
		is_eating := state.eat_segment == i
		expand := if is_eating { 4 } else { 0 }

		if i == 0 {
			// head with glow
			glow_size := if is_eating { 25 } else { 12 }
			glow_alpha := u8(if is_eating { 200 } else { 120 })
			head_color := if is_eating { color_eat_flash } else { gui.Color{80, 255, 80, 255} }
			glow_color := if is_eating {
				gui.Color{color_eat_flash.r, color_eat_flash.g, color_eat_flash.b, glow_alpha}
			} else {
				gui.Color{0, 255, 0, glow_alpha}
			}
			content << gui.column(
				x:      sx - expand
				y:      sy - expand
				width:  state.cell_size - 4 + expand * 2
				height: state.cell_size - 4 + expand * 2
				sizing: gui.fixed_fixed
				color:  head_color
				radius: 6
				shadow: &gui.BoxShadow{
					blur_radius: glow_size
					color:       glow_color
				}
			)
		} else if is_eating {
			content << gui.column(
				x:      sx - expand
				y:      sy - expand
				width:  state.cell_size - 4 + expand * 2
				height: state.cell_size - 4 + expand * 2
				sizing: gui.fixed_fixed
				color:  color_eat_flash
				radius: 5
				shadow: &gui.BoxShadow{
					blur_radius: 15
					color:       gui.Color{color_eat_flash.r, color_eat_flash.g, color_eat_flash.b, 150}
				}
			)
		} else {
			// gradient: head bright, tail darker
			brightness := 255 - i * brightness_step
			green := u8(if brightness > 100 { brightness } else { 100 })
			content << gui.column(
				x:      sx
				y:      sy
				width:  state.cell_size - 4
				height: state.cell_size - 4
				sizing: gui.fixed_fixed
				color:  gui.Color{50, green, 50, 255}
				radius: 5
			)
		}
	}

	// score
	content << gui.column(
		x:       offset_x
		y:       10
		sizing:  gui.fit_fit
		content: [
			gui.text(
				text:       'Score: ${state.score}'
				text_style: gui.TextStyle{
					size:  16
					color: gui.white
				}
			),
		]
	)

	// game over overlay
	if state.game_over {
		content << gui.column(
			x:       offset_x
			y:       offset_y
			width:   board_w
			height:  board_h
			sizing:  gui.fixed_fixed
			color:   gui.Color{0, 0, 0, 180}
			radius:  8
			h_align: .center
			v_align: .middle
			content: [
				gui.text(
					text:       'GAME OVER'
					text_style: gui.TextStyle{
						size:  32
						color: gui.red
					}
				),
				gui.text(
					text:       'Score: ${state.score}'
					text_style: gui.TextStyle{
						size:  20
						color: gui.white
					}
				),
				gui.text(
					text:       'Press SPACE to restart'
					text_style: gui.TextStyle{
						size:  16
						color: gui.Color{200, 200, 200, 255}
					}
				),
			]
		)
	}

	return gui.canvas(
		width:   width
		height:  height
		sizing:  gui.fixed_fixed
		color:   gui.Color{30, 30, 40, 255}
		content: content
	)
}
