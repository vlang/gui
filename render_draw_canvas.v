module gui

import gg

// render_draw_canvas renders cached draw-canvas triangle batches.
// Background/border/effects are handled by render_container;
// geometry batches are emitted as DrawSvg renderers.
fn render_draw_canvas(mut shape Shape, clip DrawClip, mut window Window) {
	dr := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	if !rects_overlap(dr, clip) {
		shape.disabled = true
		return
	}
	// Background, border, effects.
	render_container(mut shape, color_transparent, clip, mut window)

	sm := state_map_read[string, DrawCanvasCache](window, ns_draw_canvas) or { return }
	cached := sm.get(shape.id) or { return }

	// Content origin accounts for padding.
	ox := shape.x + shape.padding_left()
	oy := shape.y + shape.padding_top()

	// Clip to content area.
	if shape.clip {
		emit_renderer(DrawClip{
			x:      ox
			y:      oy
			width:  shape.width - shape.padding_width()
			height: shape.height - shape.padding_height()
		}, mut window)
	}

	for batch in cached.batches {
		emit_renderer(DrawSvg{
			triangles: batch.triangles
			color:     batch.color.to_gx_color()
			x:         ox
			y:         oy
			scale:     1.0
		}, mut window)
	}

	// Restore parent clip.
	if shape.clip {
		emit_renderer(clip, mut window)
	}
}
