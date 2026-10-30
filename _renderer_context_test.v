module gui

import gg
import gg.render
import sokol.gfx

fn test_gui_triangles_and_quads_share_the_gg_recording_context() {
	r := render.new_context(max_vertices: 64, max_commands: 16)
	defer { r.destroy() }
	mut window := Window{
		ui: &gg.Context{
			r:        r
			pipeline: &gg.PipelineContainer{
				alpha: render.Pipeline{ id: 42 }
			}
		}
	}
	window.ui.draw_triangle_filled(0, 0, 2, 0, 0, 2, gg.white)
	draw_triangles([f32(2), 2, 4, 2, 2, 4], gg.white, 0, 0, 1, mut window)
	draw_quad(r, 4, 4, 2, 2, 0)
	assert r.num_vertices() == 12
	assert r.num_commands() > 0
	assert r.error() == .no_error
}

fn test_gui_pipeline_and_textured_quad_use_the_supplied_context() {
	r := render.new_context(max_vertices: 32, max_commands: 8)
	other := render.new_context(max_vertices: 32, max_commands: 8)
	defer { r.destroy() }
	defer { other.destroy() }
	pipeline := make_gui_builtin_render_pipeline(r, c'gui-test', gfx.Shader{})
	assert pipeline.id != 0
	r.load_pipeline(pipeline)
	draw_quad_uv(r, 0, 0, 8, 8, 0, 0, 0, 1, 1)
	draw_filter_quad(r, 8, 8, 8, 8)
	assert r.num_vertices() == 12
	assert r.current_pipeline() == pipeline
	assert other.num_vertices() == 0
	assert r.error() == .no_error
}
