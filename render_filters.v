module gui

import sokol.gfx
import sokol.sgl
import math

struct FilterBracketCollectResult {
	content   []Renderer
	found_end bool
	next_idx  int
}

fn collect_filter_bracket_content(renderers []Renderer, start_idx int) FilterBracketCollectResult {
	if start_idx >= renderers.len {
		return FilterBracketCollectResult{
			content:   []Renderer{}
			found_end: false
			next_idx:  start_idx
		}
	}
	mut idx := start_idx
	mut content := []Renderer{cap: renderers.len - start_idx}
	for idx < renderers.len {
		current := renderers[idx]
		if current is DrawFilterEnd {
			return FilterBracketCollectResult{
				content:   content
				found_end: true
				next_idx:  idx + 1
			}
		}
		content << current
		idx++
	}
	return FilterBracketCollectResult{
		content:   content
		found_end: false
		next_idx:  idx
	}
}

// process_svg_filters scans renderers for DrawFilterBegin..End brackets,
// renders the content to offscreen textures, applies Gaussian blur,
// and replaces the bracket with DrawFilterComposite + original content.
fn process_svg_filters(mut window Window) {
	mut i := 0
	mut new_renderers := []Renderer{cap: window.renderers.len}
	renderers := window.renderers

	for i < renderers.len {
		r := renderers[i]
		if r is DrawFilterBegin {
			begin := r
			cached := begin.cached
			if cached == unsafe { nil } || begin.group_idx >= cached.filtered_groups.len {
				i++
				continue
			}
			fg := cached.filtered_groups[begin.group_idx]
			filter := fg.filter

			// Collect content renderers between Begin and End
			collected := collect_filter_bracket_content(renderers, i + 1)
			i = collected.next_idx
			if !collected.found_end {
				$if !prod {
					assert false, 'DrawFilterBegin without DrawFilterEnd'
				}
				new_renderers << collected.content
				continue
			}
			content := collected.content

			// Compute screen-space bbox with blur padding
			scale := begin.scale
			ui_scale := window.ui.scale
			padding := filter.std_dev * 3.0 * scale
			bbox_x := (begin.x + fg.bbox[0] * scale - padding) * ui_scale
			bbox_y := (begin.y + fg.bbox[1] * scale - padding) * ui_scale
			bbox_w := (fg.bbox[2] * scale + padding * 2) * ui_scale
			bbox_h := (fg.bbox[3] * scale + padding * 2) * ui_scale

			tex_w := int(math.ceil(bbox_w))
			tex_h := int(math.ceil(bbox_h))

			if tex_w <= 0 || tex_h <= 0 {
				new_renderers << content
				continue
			}

			ensure_filter_state(mut window)
			ensure_filter_textures(mut window, tex_w, tex_h)

			// Render content to tex_a via raw gfx offscreen pass
			render_filter_content(content, bbox_x, bbox_y, bbox_w, bbox_h, ui_scale, mut
				window)

			// Blur: H (tex_a → tex_b), V (tex_b → tex_a)
			blur_filter_pass(filter.std_dev, mut window)

			// Emit composite: draw blurred texture on swapchain
			new_renderers << Renderer(DrawFilterComposite{
				texture: window.filter_state.tex_a
				sampler: window.filter_state.sampler
				x:       bbox_x / ui_scale
				y:       bbox_y / ui_scale
				width:   bbox_w / ui_scale
				height:  bbox_h / ui_scale
				layers:  filter.blur_layers
			})

			if filter.keep_source {
				new_renderers << content
			}
		} else {
			new_renderers << r
			i++
		}
	}

	window.renderers = new_renderers
}

// render_filter_content renders SVG content to offscreen tex_a
// using raw gfx calls (no SGL, avoids vertex buffer conflicts).
fn render_filter_content(content []Renderer, bbox_x f32, bbox_y f32, bbox_w f32, bbox_h f32, ui_scale f32, mut window Window) {
	// Count triangle vertices needed
	mut n_verts := 0
	for r in content {
		if r is DrawSvg {
			n_verts += r.triangles.len / 2 // x,y pairs → vertices
		}
	}

	if n_verts == 0 {
		// Nothing to render; just clear tex_a
		mut pa := gfx.PassAction{}
		pa.colors[0] = gfx.ColorAttachmentAction{
			load_action: .clear
			clear_value: gfx.Color{0.0, 0.0, 0.0, 0.0}
		}
		gfx.begin_pass(gfx.Pass{
			action:      pa
			attachments: window.filter_state.att_a
		})
		gfx.end_pass()
		return
	}

	// Build vertex buffer from SVG content
	mut verts := []FilterVertex{cap: n_verts}
	for r in content {
		if r is DrawSvg {
			c := r.color
			has_vcols := r.vertex_colors.len > 0
			mut vi := 0
			mut i := 0
			for i < r.triangles.len - 1 {
				x0 := (r.x + r.triangles[i] * r.scale) * ui_scale
				y0 := (r.y + r.triangles[i + 1] * r.scale) * ui_scale
				if has_vcols && vi < r.vertex_colors.len {
					vc := r.vertex_colors[vi]
					verts << FilterVertex{x0, y0, 0, 0, 0, vc.r, vc.g, vc.b, vc.a}
				} else {
					verts << FilterVertex{x0, y0, 0, 0, 0, c.r, c.g, c.b, c.a}
				}
				vi++
				i += 2
			}
		}
	}

	// Create or resize dynamic vertex buffer
	buf_size := int(sizeof(FilterVertex)) * verts.len
	if window.filter_state.content_vbuf_sz < buf_size {
		if window.filter_state.content_vbuf_sz > 0 {
			gfx.destroy_buffer(window.filter_state.content_vbuf)
		}
		window.filter_state.content_vbuf = gfx.make_buffer(gfx.BufferDesc{
			size:  usize(buf_size)
			usage: .dynamic
			label: c'filter_content_vbuf'
		})
		window.filter_state.content_vbuf_sz = buf_size
	}
	gfx.update_buffer(window.filter_state.content_vbuf, gfx.Range{
		ptr:  unsafe { verts.data }
		size: usize(buf_size)
	})

	// Ortho projection mapping bbox to clip space
	mvp := ortho_column_major(bbox_x, bbox_x + bbox_w, bbox_y + bbox_h, bbox_y, -1.0,
		1.0)
	mut tm := [16]f32{}
	tm[5] = 1.0
	tm[10] = 1.0
	tm[15] = 1.0

	// Pack uniforms: mvp + tm = 128 bytes
	mut uniforms := [32]f32{}
	for j in 0 .. 16 {
		uniforms[j] = mvp[j]
	}
	for j in 0 .. 16 {
		uniforms[16 + j] = tm[j]
	}

	mut pass_action := gfx.PassAction{}
	pass_action.colors[0] = gfx.ColorAttachmentAction{
		load_action: .clear
		clear_value: gfx.Color{0.0, 0.0, 0.0, 0.0}
	}

	gfx.begin_pass(gfx.Pass{
		action:      pass_action
		attachments: window.filter_state.att_a
	})
	gfx.apply_pipeline(window.filter_state.content_pip)
	mut bindings := gfx.Bindings{}
	bindings.vertex_buffers[0] = window.filter_state.content_vbuf
	gfx.apply_bindings(&bindings)
	gfx.apply_uniforms(.vs, 0, &gfx.Range{
		ptr:  unsafe { &uniforms[0] }
		size: 128
	})
	gfx.draw(0, verts.len, 1)
	gfx.end_pass()
}

// blur_filter_pass applies separable Gaussian blur using raw gfx:
// horizontal (tex_a → tex_b) then vertical (tex_b → tex_a).
fn blur_filter_pass(std_dev f32, mut window Window) {
	fs := &window.filter_state

	// Unit-quad ortho: maps (0,0)-(1,1) to full render target
	mvp := ortho_column_major(0, 1, 1, 0, -1, 1)
	mut tm := [16]f32{}
	tm[0] = std_dev
	tm[5] = 1.0
	tm[10] = 1.0
	tm[15] = 1.0

	mut uniforms := [32]f32{}
	for j in 0 .. 16 {
		uniforms[j] = mvp[j]
	}
	for j in 0 .. 16 {
		uniforms[16 + j] = tm[j]
	}

	mut pass_action := gfx.PassAction{}
	pass_action.colors[0] = gfx.ColorAttachmentAction{
		load_action: .clear
		clear_value: gfx.Color{0.0, 0.0, 0.0, 0.0}
	}

	// Horizontal blur: tex_a → tex_b
	gfx.begin_pass(gfx.Pass{
		action:      pass_action
		attachments: fs.att_b
	})
	gfx.apply_pipeline(fs.blur_h_pip)
	mut bindings := gfx.Bindings{}
	bindings.vertex_buffers[0] = fs.quad_vbuf
	bindings.fs.images[0] = fs.tex_a
	bindings.fs.samplers[0] = fs.sampler
	gfx.apply_bindings(&bindings)
	gfx.apply_uniforms(.vs, 0, &gfx.Range{
		ptr:  unsafe { &uniforms[0] }
		size: 128
	})
	gfx.draw(0, 6, 1)
	gfx.end_pass()

	// Vertical blur: tex_b → tex_a
	gfx.begin_pass(gfx.Pass{
		action:      pass_action
		attachments: fs.att_a
	})
	gfx.apply_pipeline(fs.blur_v_pip)
	bindings.fs.images[0] = fs.tex_b
	gfx.apply_bindings(&bindings)
	gfx.apply_uniforms(.vs, 0, &gfx.Range{
		ptr:  unsafe { &uniforms[0] }
		size: 128
	})
	gfx.draw(0, 6, 1)
	gfx.end_pass()
}

// draw_filter_composite draws a blurred texture quad to the screen.
fn draw_filter_composite(c DrawFilterComposite, mut window Window) {
	ensure_filter_state(mut window)

	scale := window.ui.scale
	sx := c.x * scale
	sy := c.y * scale
	sw := c.width * scale
	sh := c.height * scale

	sgl.load_pipeline(window.filter_state.texture_quad_pip)
	sgl.enable_texture()
	sgl.texture(c.texture, c.sampler)

	// Draw multiple times for glow intensity
	for _ in 0 .. c.layers {
		sgl.c4b(255, 255, 255, 255)
		draw_filter_quad(sx, sy, sw, sh)
	}

	sgl.disable_texture()
	sgl.load_default_pipeline()
}

// render_layout walks the layout and generates renderers. If a shape is clipped,
// then a clip rectangle is added to the context. Clip rectangles are added to the
// draw context and the later, 'removed' by setting the clip rectangle to the
// previous rectangle of if not present, infinity.
