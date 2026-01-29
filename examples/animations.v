import gui
import time

// ============================================================================
// Animation System Demo
// ============================================================================
//
// This example demonstrates the four animation types available in v-gui:
//
// 1. TWEEN ANIMATIONS (TweenAnimation)
//    - Interpolate between values over a fixed duration
//    - Use easing functions to control the motion curve
//    - Best for: predictable, time-based animations
//
// 2. SPRING ANIMATIONS (SpringAnimation)
//    - Physics-based motion using spring dynamics
//    - Natural feel with configurable bounciness
//    - Best for: responsive, organic-feeling UI
//
// 3. LAYOUT TRANSITIONS (animate_layout)
//    - Automatically animate position/size changes between frames
//    - Captures before/after state and interpolates
//    - Best for: resizing panels, reordering lists
//
// 4. HERO TRANSITIONS (transition_to_view)
//    - Morph elements between different views
//    - Elements with matching IDs and hero:true animate together
//    - Best for: detail views, modal expansions
//
// Key concepts:
//   - All animations are added via window.animation_add()
//   - Each animation needs a unique 'id' to avoid conflicts
//   - on_value callback receives interpolated values each frame
//   - on_done callback fires when animation completes
//
// ============================================================================

// State holds the animated values. When animations update these values,
// the view function re-renders with the new positions/sizes.
struct State {
mut:
	sidebar_width f32 = 200 // Width of the collapsible sidebar (spring demo)
	box_x         f32 = 50  // X position of the blue box (tween/elastic demo)
	spring_value  f32 = 100 // X position of the green circle (bounce demo)
	show_detail   bool // Whether showing detail view (hero demo)
}

fn main() {
	// Create the window with our State struct.
	// State is passed as a pointer and accessible via window.state[State]()
	mut window := gui.window(
		title:   'Animations'
		state:   &State{}
		width:   800
		height:  600
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

// main_view builds the primary UI with animated elements.
// This function is called every frame - state changes trigger re-render.
fn main_view(mut window gui.Window) gui.View {
	state := window.state[State]()
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		spacing: 20
		padding: gui.padding(20, 20, 20, 20)
		content: [
			// Control buttons - each triggers a different animation type
			gui.row(
				spacing: 10
				content: [
					anim_button('Tween', tween_box),
					anim_button('Spring', spring_sidebar),
					anim_button('Bounce', bounce_anim),
					anim_button('Elastic', elastic_anim),
					anim_button('Keyframe', keyframe_anim),
					anim_button('Layout', layout_anim),
					anim_button('Hero', hero_anim),
				]
			),
			// Demo area showing animated elements
			gui.row(
				sizing:  gui.fill_fill
				content: [
					// ANIMATED SIDEBAR (Spring + Layout demo)
					// Width comes from state - animations modify state.sidebar_width
					gui.column(
						id:      'sidebar'
						width:   state.sidebar_width // <-- animated value
						sizing:  gui.Sizing{
							width:  .fixed
							height: .fill
						}
						color:   gui.purple
						radius:  8
						padding: gui.padding(10, 10, 10, 10)
						content: [
							gui.text(text: 'Sidebar'),
						]
					),
					// Canvas allows absolute positioning of children
					gui.canvas(
						sizing:  gui.fill_fill
						content: [
							// HERO ELEMENT - morphs between views
							// Elements with matching 'id' and 'hero: true' in both
							// views will animate position/size during transition
							gui.column(
								id:      'hero-card' // <-- must match in detail_view
								hero:    true        // <-- enables hero transition
								x:       50
								y:       220
								width:   120
								height:  80
								sizing:  gui.fixed_fixed
								color:   gui.orange
								radius:  12
								padding: gui.padding(10, 10, 10, 10)
								v_align: .middle
								h_align: .center
								content: [
									gui.text(
										text:       'Click Hero'
										text_style: gui.TextStyle{
											...gui.theme().text_style
											color: gui.black
										}
									),
								]
							),
							// TWEEN/ELASTIC BOX - position animated via state.box_x
							gui.column(
								id:     'box'
								x:      state.box_x // <-- animated value
								y:      50
								width:  80
								height: 80
								sizing: gui.fixed_fixed
								color:  gui.blue
								radius: 8
							),
							// SPRING/BOUNCE CIRCLE - position animated via state.spring_value
							gui.column(
								id:     'spring'
								x:      state.spring_value // <-- animated value
								y:      150
								width:  40
								height: 40
								sizing: gui.fixed_fixed
								color:  gui.green
								radius: 20
							),
						]
					),
				]
			),
		]
	)
}

// detail_view is the target view for hero transitions.
// The 'hero-card' element here has the same id as in main_view,
// so transition_to_view will smoothly morph between them.
fn detail_view(mut window gui.Window) gui.View {
	w, h := window.window_size()

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		spacing: 20
		padding: gui.padding(20, 20, 20, 20)
		content: [
			gui.row(
				content: [
					anim_button('Back', hero_back),
				]
			),
			// HERO CARD - expanded version
			// Same id as main_view's hero-card, so they morph together
			gui.column(
				id:      'hero-card'   // <-- matches main_view
				hero:    true          // <-- enables hero transition
				sizing:  gui.fill_fill // <-- now fills screen (was 120x80)
				color:   gui.orange
				radius:  16
				padding: gui.padding(20, 20, 20, 20)
				content: [
					gui.text(
						id:         'detail-title'
						hero:       true
						text:       'Detail View'
						text_style: gui.TextStyle{
							...gui.theme().b1
							color: gui.black
						}
					),
					gui.text(
						id:         'detail-text1'
						hero:       true
						text:       'The card morphed from small to large.'
						text_style: gui.TextStyle{
							...gui.theme().text_style
							color: gui.black
						}
					),
					gui.text(
						id:         'detail-text2'
						hero:       true
						text:       'Click Back to morph it back.'
						text_style: gui.TextStyle{
							...gui.theme().text_style
							color: gui.black
						}
					),
				]
			),
		]
	)
}

// Helper to create animation trigger buttons
fn anim_button(label string, on_click fn (mut gui.Window)) gui.View {
	return gui.button(
		content:  [gui.text(text: label)]
		on_click: fn [on_click] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			on_click(mut w)
		}
	)
}

// ============================================================================
// TWEEN ANIMATION
// ============================================================================
// TweenAnimation interpolates from one value to another over a fixed duration.
// Use easing functions to control the motion curve (ease_out feels natural).
//
// Common easing functions:
//   - gui.ease_linear       : constant speed
//   - gui.ease_in_quad      : starts slow, accelerates
//   - gui.ease_out_quad     : starts fast, decelerates
//   - gui.ease_in_out_quad  : slow start and end
//   - gui.ease_out_cubic    : smoother deceleration
//   - gui.ease_out_elastic  : overshoots and wobbles
//   - gui.ease_out_bounce   : bounces at the end
//
fn tween_box(mut w gui.Window) {
	state := w.state[State]()
	target := if state.box_x < 300 { f32(400) } else { f32(50) }

	w.animation_add(mut gui.TweenAnimation{
		id:       'box_move'             // unique id prevents duplicates
		from:     state.box_x            // starting value
		to:       target                 // ending value
		duration: 500 * time.millisecond // animation length
		easing:   gui.ease_out_cubic     // motion curve
		on_value: fn (v f32, mut w gui.Window) {
			// Called each frame with interpolated value
			mut s := w.state[State]()
			s.box_x = v
		}
	})
}

// ============================================================================
// SPRING ANIMATION
// ============================================================================
// SpringAnimation uses physics simulation for natural-feeling motion.
// Unlike tweens, springs have no fixed duration - they settle naturally.
//
// Spring presets:
//   - gui.spring_default : balanced, general purpose
//   - gui.spring_bouncy  : more overshoot and oscillation
//   - gui.spring_stiff   : quick, minimal bounce
//   - gui.spring_gentle  : slow, smooth settling
//
// Custom springs: gui.SpringCfg{ stiffness: 100, damping: 10 }
//
fn spring_sidebar(mut w gui.Window) {
	state := w.state[State]()
	target := if state.sidebar_width > 100 { f32(60) } else { f32(200) }

	mut spring := gui.SpringAnimation{
		id:       'sidebar'
		config:   gui.spring_bouncy // physics parameters
		on_value: fn (v f32, mut w gui.Window) {
			mut s := w.state[State]()
			s.sidebar_width = v
		}
	}
	spring.spring_to(state.sidebar_width, target) // set start/end values
	w.animation_add(mut spring)
}

// ============================================================================
// CHAINED ANIMATIONS (using on_done)
// ============================================================================
// Use on_done callback to chain animations sequentially.
// Here: bounce to target, then return to start position.
//
fn bounce_anim(mut w gui.Window) {
	state := w.state[State]()
	w.animation_add(mut gui.TweenAnimation{
		id:       'bounce'
		from:     state.spring_value
		to:       300
		duration: 800 * time.millisecond
		easing:   gui.ease_out_bounce // bounces at destination
		on_value: fn (v f32, mut w gui.Window) {
			mut s := w.state[State]()
			s.spring_value = v
		}
		// Chain a second animation when this one completes
		on_done: fn (mut w gui.Window) {
			w.animation_add(mut gui.TweenAnimation{
				id:       'bounce_return'
				from:     300
				to:       100
				duration: 300 * time.millisecond
				easing:   gui.ease_out_quad
				on_value: fn (v f32, mut w gui.Window) {
					mut s := w.state[State]()
					s.spring_value = v
				}
			})
		}
	})
}

// ============================================================================
// ELASTIC EASING
// ============================================================================
// Elastic easing overshoots the target and oscillates like a spring,
// but in a fixed duration (unlike SpringAnimation which is open-ended).
//
fn elastic_anim(mut w gui.Window) {
	state := w.state[State]()
	target := if state.box_x < 300 { f32(500) } else { f32(50) }

	w.animation_add(mut gui.TweenAnimation{
		id:       'elastic'
		from:     state.box_x
		to:       target
		duration: 1000 * time.millisecond
		easing:   gui.ease_out_elastic // springy overshoot
		on_value: fn (v f32, mut w gui.Window) {
			mut s := w.state[State]()
			s.box_x = v
		}
	})
}

// ============================================================================
// LAYOUT TRANSITIONS
// ============================================================================
// animate_layout() captures current element positions, then animates
// to new positions after state changes. No manual from/to values needed.
//
// How it works:
//   1. Call animate_layout() - captures current positions
//   2. Modify state - triggers re-render with new layout
//   3. Framework detects differences and animates between them
//
// Great for: resizable panels, reorderable lists, responsive layouts
//
fn layout_anim(mut w gui.Window) {
	// Step 1: Tell framework to capture current layout
	w.animate_layout(duration: 300 * time.millisecond)

	// Step 2: Modify state - this triggers new layout calculation
	mut s := w.state[State]()
	s.sidebar_width = if s.sidebar_width > 100 { 60 } else { 200 }
	// Framework automatically animates sidebar from old to new width
}

// ============================================================================
// HERO TRANSITIONS
// ============================================================================
// transition_to_view() morphs elements between completely different views.
// Elements with matching 'id' AND 'hero: true' animate together.
//
// Requirements:
//   - Source element: id: 'my-id', hero: true
//   - Target element: id: 'my-id', hero: true (same id!)
//   - Both in different view functions
//
// The framework interpolates: position, size, radius, opacity
//
// Perfect for: detail views, modal expansions, photo galleries
//
fn hero_anim(mut w gui.Window) {
	// Transition from main_view to detail_view
	// 'hero-card' element morphs from 120x80 to fill-screen
	w.transition_to_view(detail_view, duration: 600 * time.millisecond)
}

fn hero_back(mut w gui.Window) {
	// Transition back - card morphs from full-screen to small
	w.transition_to_view(main_view, duration: 600 * time.millisecond)
}

// ============================================================================
// KEYFRAME ANIMATION
// ============================================================================
// KeyframeAnimation interpolates through multiple waypoints with per-segment
// easing. Each keyframe specifies a position (0.0-1.0), value, and easing
// function to reach it.
//
// Use for: shake effects, staged progress, animations with pauses
//
fn keyframe_anim(mut w gui.Window) {
	state := w.state[State]()
	center := state.box_x

	w.animation_add(mut gui.KeyframeAnimation{
		id:        'shake'
		duration:  500 * time.millisecond
		keyframes: [
			gui.Keyframe{
				at:    0.0
				value: center
			},
			gui.Keyframe{
				at:     0.2
				value:  center - 30
				easing: gui.ease_out_quad
			},
			gui.Keyframe{
				at:     0.4
				value:  center + 25
				easing: gui.ease_out_quad
			},
			gui.Keyframe{
				at:     0.6
				value:  center - 15
				easing: gui.ease_out_quad
			},
			gui.Keyframe{
				at:     0.8
				value:  center + 8
				easing: gui.ease_out_quad
			},
			gui.Keyframe{
				at:     1.0
				value:  center
				easing: gui.ease_out_quad
			},
		]
		on_value:  fn (v f32, mut w gui.Window) {
			mut s := w.state[State]()
			s.box_x = v
		}
	})
}
