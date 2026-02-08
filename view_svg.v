module gui

import log

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
	sizing    Sizing
	padding   Padding
	on_click  fn (&Layout, mut Event, mut Window) = unsafe { nil }
}

// generate_layout creates a Layout for the SVG view, loading dimensions from the SVG if needed.
fn (mut sv SvgView) generate_layout(mut window Window) Layout {
	window.stats.increment_layouts()

	svg_src := if sv.file_name.len > 0 { sv.file_name } else { sv.svg_data }

	// Determine display dimensions - use specified or SVG's natural size
	// First load at 1:1 scale to get natural dimensions
	initial := window.load_svg(svg_src, 0, 0) or {
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

	width := if sv.width > 0 { sv.width } else { initial.width }
	height := if sv.height > 0 { sv.height } else { initial.height }

	// Now load at the actual display dimensions for proper tessellation
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
	_ = cached // cache entry now exists at correct scale

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
