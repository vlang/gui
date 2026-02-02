module gui

import gg

fn test_render_container_shadow_opacity() {
	mut w := Window{
		renderers: []Renderer{}
	}
	// Setup a shape with shadow alpha 128 (approx 0.5)
	shadow_alpha := u8(128)
	container_color := rgb(100, 100, 100)

	mut s := Shape{
		shape_type: .rectangle
		x:          0
		y:          0
		width:      100
		height:     100
		color:      container_color
		radius:     5
		shadow:     &BoxShadow{
			blur_radius: 10
			color:       rgba(0, 0, 0, shadow_alpha)
		}
	}
	clip := gg.Rect{0, 0, 200, 200}

	render_container(mut s, color_transparent, clip, mut w)

	assert w.renderers.len == 2
	shadow_r := w.renderers[0]
	container_r := w.renderers[1]

	if shadow_r is DrawShadow {
		assert shadow_r.color.a == shadow_alpha
	} else {
		assert false, 'Expected DrawShadow first'
	}

	if container_r is DrawRect {
		// Crucial verification: Container color should be opaque (255)
		assert container_r.color.a == 255
		assert container_r.color.r == 100
	} else {
		assert false, 'Expected DrawRect second'
	}
}
