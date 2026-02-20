module gui

import hash.fnv1a
import log
import time

// SvgView is the internal view implementation for rendering SVG graphics.
@[minify]
struct SvgView implements View {
	SvgCfg
mut:
	content []View // not used
}

// SvgCfg configures an SVG view component.
@[minify]
pub struct SvgCfg {
pub:
	id        string // Unique identifier
	file_name string // SVG file path
	svg_data  string // OR inline SVG string
	width     f32    // Display width
	height    f32    // Display height
	color     Color = color_transparent // Override fill color (for monochrome icons)
	animated  bool  = true              // Enable SMIL animation (if SVG contains animations)
	sizing    Sizing
	padding   Padding
	on_click  fn (&Layout, mut Event, mut Window) = unsafe { nil }
}

// generate_layout creates a Layout for the SVG view, loading dimensions from the SVG if needed.
fn (mut sv SvgView) generate_layout(mut window Window) Layout {
	window.stats.increment_layouts()

	svg_src := if sv.file_name.len > 0 { sv.file_name } else { sv.svg_data }

	// Determine display dimensions
	mut width := sv.width
	mut height := sv.height

	if width <= 0 || height <= 0 {
		// Need natural dimensions — lightweight header parse
		nat_w, nat_h := window.get_svg_dimensions(svg_src) or {
			log.error('${@FILE_LINE} > ${err.msg()}')
			mut error_text := text(
				text:       '[missing: ${svg_src}]'
				text_style: TextStyle{
					...gui_theme.text_style
					color: magenta
				}
			)
			return error_text.generate_layout(mut window)
		}
		if width <= 0 {
			width = nat_w
		}
		if height <= 0 {
			height = nat_h
		}
	}

	// Load at display dimensions for tessellation
	cached := window.load_svg(svg_src, width, height) or {
		log.error('${@FILE_LINE} > ${err.msg()}')
		mut error_text := text(
			text:       '[missing: ${svg_src}]'
			text_style: TextStyle{
				...gui_theme.text_style
				color: magenta
			}
		)
		return error_text.generate_layout(mut window)
	}

	// Register animation loop for animated SVGs
	if cached.has_animations && sv.animated {
		anim_hash := fnv1a.sum64_string(svg_src).hex()
		now_ns := time.now().unix_nano()
		window.view_state.svg_anim_seen.set(anim_hash, now_ns)
		if !window.view_state.svg_anim_start.contains(anim_hash) {
			window.view_state.svg_anim_start.set(anim_hash, now_ns)
		}
		anim_id := 'svg_anim:${anim_hash}'
		if !window.has_animation(anim_id) {
			window.animation_add(mut &Animate{
				id:       anim_id
				delay:    animation_cycle
				repeat:   true
				callback: fn [anim_hash] (mut an Animate, mut w Window) {
					// Check staleness: if SVG left the layout tree, stop
					if seen := w.view_state.svg_anim_seen.get(anim_hash) {
						elapsed := time.now().unix_nano() - seen
						if elapsed > 200_000_000 {
							// >200ms since last seen → SVG removed
							an.stopped = true
							return
						}
					} else {
						an.stopped = true
						return
					}
					w.update_window()
				}
			})
		}
	}

	mut events := unsafe { &EventHandlers(nil) }
	on_click := sv.left_click()
	if on_click != unsafe { nil } {
		events = &EventHandlers{
			on_click: on_click
		}
	}
	mut layout := Layout{
		shape: &Shape{
			shape_type: .svg
			id:         sv.id
			a11y_role:  .image
			a11y:       make_a11y_info(sv.id, '')
			resource:   svg_src
			width:      width
			height:     height
			color:      sv.color
			sizing:     sv.sizing
			padding:    sv.padding
			events:     events
		}
	}
	apply_fixed_sizing_constraints(mut layout.shape)
	return layout
}

// svg creates an SVG view component from an SVG file or inline data.
pub fn svg(cfg SvgCfg) View {
	return SvgView{
		id:        cfg.id
		file_name: cfg.file_name
		svg_data:  cfg.svg_data
		width:     cfg.width
		height:    cfg.height
		color:     cfg.color
		animated:  cfg.animated
		sizing:    cfg.sizing
		padding:   cfg.padding
		on_click:  cfg.on_click
	}
}

// left_click wraps the on_click handler to only trigger on left mouse button clicks.
fn (cfg &SvgCfg) left_click() fn (&Layout, mut Event, mut Window) {
	if cfg.on_click == unsafe { nil } {
		return cfg.on_click
	}
	on_click := cfg.on_click
	return fn [on_click] (layout &Layout, mut e Event, mut w Window) {
		if e.mouse_button == .left {
			on_click(layout, mut e, mut w)
		}
	}
}
