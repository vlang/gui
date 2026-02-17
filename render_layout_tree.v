module gui

import gg
import log
import vglyph

// render_layout walks the layout and generates renderers. If a shape is clipped,
// then a clip rectangle is added to the context. Clip rectangles are added to the
// draw context and the later, 'removed' by setting the clip rectangle to the
// previous rectangle of if not present, infinity.
fn render_layout(mut layout Layout, bg_color Color, clip DrawClip, mut window Window) {
	render_shape(mut layout.shape, bg_color, clip, mut window)

	mut shape_clip := clip
	if layout.shape.over_draw { // allow drawing in the padded area of shape
		shape_clip = layout.shape.shape_clip
		if layout.shape.scrollbar_orientation == .vertical {
			shape_clip = DrawClip{
				...shape_clip
				y:      clip.y
				height: clip.height
			}
		}
		if layout.shape.scrollbar_orientation == .horizontal {
			shape_clip = DrawClip{
				...shape_clip
				x:     clip.x
				width: clip.width
			}
		}
		emit_renderer(shape_clip, mut window)
	} else if layout.shape.clip {
		sc := layout.shape.shape_clip
		shape_clip = DrawClip{
			x:      sc.x + layout.shape.padding_left()
			y:      sc.y + layout.shape.padding_top()
			width:  f32_max(0, sc.width - layout.shape.padding_width())
			height: f32_max(0, sc.height - layout.shape.padding_height())
		}
		emit_renderer(shape_clip, mut window)
	}

	color := if layout.shape.color != color_transparent { layout.shape.color } else { bg_color }
	for mut child in layout.children {
		render_layout(mut child, color, shape_clip, mut window)
	}

	if layout.shape.clip || layout.shape.over_draw {
		emit_renderer(clip, mut window)
	}
}

// render_shape examines the Shape.type and calls the appropriate renderer.
fn render_shape(mut shape Shape, parent_color Color, clip DrawClip, mut window Window) {
	// Degrade safely if a text-like shape is missing text config.
	if shape.shape_type in [.text, .rtf] && shape.tc == unsafe { nil } {
		return
	}

	// Apply opacity to colors
	if shape.opacity < 1.0 {
		shape.color = shape.color.with_opacity(shape.opacity)
		shape.color_border = shape.color_border.with_opacity(shape.opacity)
		if shape.tc != unsafe { nil } {
			shape.tc.text_style = TextStyle{
				...shape.tc.text_style
				color: shape.tc.text_style.color.with_opacity(shape.opacity)
			}
		}
	}

	has_visible_border := shape.size_border > 0 && shape.color_border != color_transparent
	has_visible_text := shape.shape_type == .text && shape.tc != unsafe { nil }
		&& (shape.tc.text_style.color != color_transparent || shape.tc.text_style.stroke_width > 0)
	// SVG shapes have their own internal colors, so don't skip them
	is_svg := shape.shape_type == .svg
	has_effects := shape.fx != unsafe { nil } && (shape.fx.gradient != unsafe { nil }
		|| shape.fx.shader != unsafe { nil }
		|| shape.fx.border_gradient != unsafe { nil })
	if shape.color == color_transparent && !has_effects && !has_visible_border && !has_visible_text
		&& !is_svg {
		return
	}
	match shape.shape_type {
		.rectangle {
			render_container(mut shape, parent_color, clip, mut window)
		}
		.text {
			render_text(mut shape, clip, mut window)
		}
		.image {
			render_image(mut shape, clip, mut window)
		}
		.circle {
			render_circle(mut shape, clip, mut window)
		}
		.rtf {
			render_rtf(mut shape, clip, mut window)
		}
		.svg {
			render_svg(mut shape, clip, mut window)
		}
		.none {}
	}
}

// render_container mostly draws a rectangle. Containers are more about layout than drawing.
// One complication is the title text that is drawn in the upper left corner of the rectangle.
// At some point, it should be moved to the container logic, along with some layout amend logic.
// Honestly, it was more expedient to put it here.
fn render_container(mut shape Shape, parent_color Color, clip DrawClip, mut window Window) {
	fx := shape.fx
	has_fx := fx != unsafe { nil }
	if has_fx && fx.shadow != unsafe { nil } && fx.shadow.color.a > 0 && fx.shadow.blur_radius > 0 {
		window.renderers << DrawShadow{
			x:           shape.x + fx.shadow.offset_x
			y:           shape.y + fx.shadow.offset_y
			width:       shape.width
			height:      shape.height
			radius:      shape.radius
			blur_radius: fx.shadow.blur_radius
			color:       fx.shadow.color.to_gx_color()
			offset_x:    fx.shadow.offset_x
			offset_y:    fx.shadow.offset_y
		}
	}
	// Here is where the mighty container is drawn. Yeah, it really is just a rectangle.
	if has_fx && fx.shader != unsafe { nil } {
		color := if shape.disabled { dim_alpha(shape.color) } else { shape.color }
		window.renderers << DrawCustomShader{
			x:      shape.x
			y:      shape.y
			w:      shape.width
			h:      shape.height
			radius: shape.radius
			color:  color.to_gx_color()
			shader: fx.shader
		}
		// Draw border separately if present
		if shape.size_border > 0 && shape.color_border != color_transparent {
			c_border := if shape.disabled {
				dim_alpha(shape.color_border)
			} else {
				shape.color_border
			}
			if c_border.a > 0 {
				window.renderers << DrawStrokeRect{
					x:         shape.x
					y:         shape.y
					w:         shape.width
					h:         shape.height
					color:     c_border.to_gx_color()
					radius:    shape.radius
					thickness: shape.size_border
				}
			}
		}
		return
	} else if has_fx && fx.gradient != unsafe { nil } {
		window.renderers << DrawGradient{
			x:        shape.x
			y:        shape.y
			w:        shape.width
			h:        shape.height
			radius:   shape.radius
			gradient: fx.gradient
		}
	} else if has_fx && fx.blur_radius > 0 && shape.color.a > 0 {
		window.renderers << DrawBlur{
			x:           shape.x
			y:           shape.y
			width:       shape.width
			height:      shape.height
			radius:      shape.radius
			blur_radius: fx.blur_radius
			color:       shape.color.to_gx_color()
		}
	} else {
		// Check for Border Gradient
		if has_fx && fx.border_gradient != unsafe { nil } {
			window.renderers << DrawGradientBorder{
				x:         shape.x
				y:         shape.y
				w:         shape.width
				h:         shape.height
				radius:    shape.radius
				thickness: shape.size_border
				gradient:  fx.border_gradient
			}
		} else {
			render_rectangle(mut shape, clip, mut window)
		}
	}
}

// render_circle draws a shape as a circle in the middle of the shape's
// rectangular region. Radius is half of the shortest side.
fn render_circle(mut shape Shape, clip DrawClip, mut window Window) {
	assert shape.shape_type == .circle
	draw_rect := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	color := if shape.disabled { dim_alpha(shape.color) } else { shape.color }
	gx_color := color.to_gx_color()
	if rects_overlap(draw_rect, clip) {
		radius := f32_min(shape.width, shape.height) / 2
		x := shape.x + shape.width / 2
		y := shape.y + shape.height / 2

		// Fill
		if color.a > 0 {
			window.renderers << DrawCircle{
				x:      x
				y:      y
				radius: radius
				fill:   true
				color:  gx_color
			}
		}

		// Border
		if shape.size_border > 0 {
			c_border := if shape.disabled {
				dim_alpha(shape.color_border)
			} else {
				shape.color_border
			}
			if c_border.a > 0 {
				window.renderers << DrawStrokeRect{
					x:         draw_rect.x
					y:         draw_rect.y
					w:         draw_rect.width
					h:         draw_rect.height
					color:     c_border.to_gx_color()
					radius:    radius
					thickness: shape.size_border
				}
			}
		}
	} else {
		shape.disabled = true
	}
}

// render_rectangle draws a shape as a rectangle.
fn render_rectangle(mut shape Shape, clip DrawClip, mut window Window) {
	assert shape.shape_type == .rectangle
	draw_rect := gg.Rect{
		x:      shape.x
		y:      shape.y
		width:  shape.width
		height: shape.height
	}
	color := if shape.disabled { dim_alpha(shape.color) } else { shape.color }
	gx_color := color.to_gx_color()

	if rects_overlap(draw_rect, clip) {
		// Fill
		if color.a > 0 {
			window.renderers << DrawRect{
				x:          draw_rect.x
				y:          draw_rect.y
				w:          draw_rect.width
				h:          draw_rect.height
				color:      gx_color
				style:      .fill
				is_rounded: shape.radius > 0
				radius:     shape.radius
			}
		}

		// Border
		if shape.size_border > 0 {
			c_border := if shape.disabled {
				dim_alpha(shape.color_border)
			} else {
				shape.color_border
			}

			if c_border.a > 0 {
				window.renderers << DrawStrokeRect{
					x:         draw_rect.x
					y:         draw_rect.y
					w:         draw_rect.width
					h:         draw_rect.height
					color:     c_border.to_gx_color()
					radius:    shape.radius
					thickness: shape.size_border
				}
			}
		}
	} else {
		shape.disabled = true
	}
}

fn render_image(mut shape Shape, clip DrawClip, mut window Window) {
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
	image := window.load_image(shape.resource) or {
		log.error('${@FILE_LINE} > ${err.msg()}')
		draw_error_placeholder(shape.x, shape.y, shape.width, shape.height, mut window)
		return
	}
	window.renderers << DrawImage{
		x:   shape.x
		y:   shape.y
		w:   shape.width
		h:   shape.height
		img: image
	}
}

fn render_rtf(mut shape Shape, clip DrawClip, mut window Window) {
	if shape.has_rtf_layout() {
		dr := gg.Rect{
			x:      shape.x
			y:      shape.y
			width:  shape.width
			height: shape.height
		}
		if rects_overlap(dr, clip) {
			mut has_transform := false
			mut transform := vglyph.AffineTransform{}
			mut mixed_transform := false
			mut has_inline_objects := false
			if shape.tc.rich_text != unsafe { nil } {
				if draw_transform := shape.tc.rich_text.uniform_text_transform() {
					has_transform = true
					transform = draw_transform
				}
				mixed_transform = shape.tc.rich_text.has_mixed_text_transform()
			}
			for item in shape.tc.vglyph_layout.items {
				if item.is_object {
					has_inline_objects = true
					break
				}
			}
			if mixed_transform {
				log.warn('RTF transform ignored for shape "${shape.id}": mixed run transforms')
			}
			if has_transform && has_inline_objects {
				log.warn('RTF transform ignored for shape "${shape.id}": inline objects not supported')
				has_transform = false
			}
			if has_transform {
				emit_renderer(DrawLayoutTransformed{
					layout:    clone_layout_for_draw(shape.tc.vglyph_layout)
					x:         shape.x
					y:         shape.y
					transform: transform
				}, mut window)
			} else {
				emit_renderer(DrawLayout{
					layout: shape.tc.vglyph_layout
					x:      shape.x
					y:      shape.y
				}, mut window)
			}
			// Draw inline math images at InlineObject positions
			for item in shape.tc.vglyph_layout.items {
				if item.is_object && item.object_id != '' {
					ihash := math_cache_hash(item.object_id)
					if entry := window.view_state.diagram_cache.get(ihash) {
						if entry.state == .ready && entry.png_path.len > 0 {
							img := window.load_image(entry.png_path) or { continue }
							window.renderers << DrawImage{
								x:   shape.x + f32(item.x)
								y:   shape.y + f32(item.y) - f32(item.ascent)
								w:   f32(item.width)
								h:   f32(item.ascent + item.descent)
								img: img
							}
						}
					}
				}
			}
		} else {
			shape.disabled = true
		}
	}
}
