import gui
import time

@[heap]
struct App {
mut:
	start_time time.Time
}

fn main() {
	mut app := &App{
		start_time: time.now()
	}
	mut window := gui.window(
		state:   app
		width:   600
		height:  400
		title:   'Custom Shader Demo'
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
			// Long-running tween drives ~60fps redraws
			mut anim := gui.TweenAnimation{
				id:       'shader_tick'
				duration: 999 * time.second
				from:     0
				to:       1
				on_value: fn (_ f32, mut w gui.Window) {}
			}
			w.animation_add(mut anim)
		}
	)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	app := window.state[App]()
	w, h := window.window_size()
	elapsed := f32(time.since(app.start_time).milliseconds()) / 1000.0

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		h_align: .center
		v_align: .middle
		spacing: 20
		content: [
			gui.text(text: 'Custom Fragment Shader Demo'),
			gui.row(
				spacing: 20
				content: [
					// Animated rainbow
					gui.column(
						width:   200
						height:  200
						sizing:  gui.fixed_fixed
						radius:  16
						shader:  &gui.Shader{
							metal:  '
								float t = in.p0.x;
								float2 st = in.uv * 0.5 + 0.5;
								float3 c = 0.5 + 0.5 * cos(t + st.xyx + float3(0,2,4));
								float4 frag_color = float4(c, 1.0);
							'
							glsl:   '
								float t = p0.x;
								vec2 st = uv * 0.5 + 0.5;
								vec3 c = 0.5 + 0.5 * cos(t + st.xyx + vec3(0,2,4));
								vec4 frag_color = vec4(c, 1.0);
							'
							params: [elapsed]
						}
						content: [gui.text(text: 'Rainbow')]
					),
					// Plasma effect
					gui.column(
						width:   200
						height:  200
						sizing:  gui.fixed_fixed
						radius:  16
						shader:  &gui.Shader{
							metal:  '
								float t = in.p0.x;
								float2 st = in.uv * 3.0;
								float v = sin(st.x + t) + sin(st.y + t)
									+ sin(st.x + st.y + t)
									+ sin(length(st) + 1.5 * t);
								v = v * 0.25 + 0.5;
								float3 c = float3(
									sin(v * 3.14159),
									sin(v * 3.14159 + 2.094),
									sin(v * 3.14159 + 4.188));
								c = c * 0.5 + 0.5;
								float4 frag_color = float4(c, 1.0);
							'
							glsl:   '
								float t = p0.x;
								vec2 st = uv * 3.0;
								float v = sin(st.x + t) + sin(st.y + t)
									+ sin(st.x + st.y + t)
									+ sin(length(st) + 1.5 * t);
								v = v * 0.25 + 0.5;
								vec3 c = vec3(
									sin(v * 3.14159),
									sin(v * 3.14159 + 2.094),
									sin(v * 3.14159 + 4.188));
								c = c * 0.5 + 0.5;
								vec4 frag_color = vec4(c, 1.0);
							'
							params: [elapsed]
						}
						content: [gui.text(text: 'Plasma')]
					),
				]
			),
		]
	)
}
