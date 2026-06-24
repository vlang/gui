module gui

// DrawCanvasView is the internal view for user-drawn canvas content.
@[minify]
struct DrawCanvasView implements View {
	DrawCanvasCfg
mut:
	content []View
}

// DrawCanvasCfg configures a draw canvas view.
@[minify]
pub struct DrawCanvasCfg {
pub:
	id              string
	version         u64 // bump to invalidate cached tessellation
	sizing          Sizing = fixed_fixed
	width           f32
	height          f32
	min_width       f32
	min_height      f32
	max_width       f32
	max_height      f32
	padding         Padding
	clip            bool  = true
	color           Color = color_transparent
	radius          f32
	on_draw         fn (mut DrawContext)                   = unsafe { nil }
	on_click        fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_hover        fn (mut Layout, mut Event, mut Window) = unsafe { nil }
	on_mouse_scroll fn (&Layout, mut Event, mut Window)    = unsafe { nil }
}

fn (mut cv DrawCanvasView) generate_layout(mut window Window) Layout {
	window.stats.increment_layouts()
	on_draw := cv.on_draw
	if on_draw != unsafe { nil } {
		mut sm := state_map[string, DrawCanvasCache](mut window, ns_draw_canvas, cap_moderate)
		needs_draw := if cached := sm.get(cv.id) {
			cached.version != cv.version
		} else {
			true
		}
		if needs_draw {
			mut dc := DrawContext{
				width:  cv.width - cv.padding.left - cv.padding.right
				height: cv.height - cv.padding.top - cv.padding.bottom
			}
			on_draw(mut dc)
			sm.set(cv.id, DrawCanvasCache{
				version: cv.version
				batches: dc.batches
			})
		}
	}
	mut events := unsafe { &EventHandlers(nil) }
	on_click := cv.on_click
	on_hover := cv.on_hover
	on_mouse_scroll := cv.on_mouse_scroll
	if on_click != unsafe { nil } || on_hover != unsafe { nil } || on_mouse_scroll != unsafe { nil } {
		events = &EventHandlers{
			on_click:        on_click
			on_hover:        on_hover
			on_mouse_scroll: on_mouse_scroll
		}
	}
	mut layout := Layout{
		shape: &Shape{
			shape_type: .draw_canvas
			id:         cv.id
			width:      cv.width
			height:     cv.height
			min_width:  cv.min_width
			max_width:  cv.max_width
			min_height: cv.min_height
			max_height: cv.max_height
			sizing:     cv.sizing
			padding:    cv.padding
			clip:       cv.clip
			color:      cv.color
			radius:     cv.radius
			events:     events
		}
	}
	apply_fixed_sizing_constraints(mut layout.shape)
	return layout
}

// draw_canvas creates a canvas with user-drawn geometry.
// The on_draw callback receives a DrawContext with polyline,
// polygon, arc, rect, and circle primitives. Tessellated
// triangles are cached by id + version.
pub fn draw_canvas(cfg DrawCanvasCfg) View {
	return DrawCanvasView{
		id:              cfg.id
		version:         cfg.version
		sizing:          cfg.sizing
		width:           cfg.width
		height:          cfg.height
		min_width:       cfg.min_width
		max_width:       cfg.max_width
		min_height:      cfg.min_height
		max_height:      cfg.max_height
		padding:         cfg.padding
		clip:            cfg.clip
		color:           cfg.color
		radius:          cfg.radius
		on_draw:         cfg.on_draw
		on_click:        cfg.on_click
		on_hover:        cfg.on_hover
		on_mouse_scroll: cfg.on_mouse_scroll
	}
}
