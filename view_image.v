module gui

import log

@[minify]
struct ImageView implements View {
	ImageCfg
mut:
	content []View // not used
}

@[minify]
pub struct ImageCfg {
pub:
	id         string
	file_name  string
	on_click   fn (&Layout, mut Event, mut Window)    = unsafe { nil }
	on_hover   fn (mut Layout, mut Event, mut Window) = unsafe { nil }
	width      f32
	height     f32
	min_width  f32
	min_height f32
	max_width  f32
	max_height f32
	invisible  bool
}

fn (mut iv ImageView) generate_layout(mut window Window) Layout {
	window.stats.increment_layouts()
	window.stats.increment_image_views()
	image := window.load_image(iv.file_name) or {
		log.error('${@FILE_LINE} > ${err.msg()}')
		mut error_text := text(text: '[missing: ${iv.file_name}]')
		return error_text.generate_layout(mut window)
	}

	width := if iv.width > 0 { iv.width } else { image.width }
	height := if iv.height > 0 { iv.height } else { image.height }

	mut layout := Layout{
		shape: &Shape{
			name:       'image'
			shape_type: .image
			id:         iv.id
			image_name: iv.file_name
			width:      width
			min_width:  iv.min_width
			max_width:  iv.max_width
			height:     height
			min_height: iv.min_height
			max_height: iv.max_height
			on_click:   iv.on_click
			on_hover:   iv.on_hover
		}
	}
	apply_fixed_sizing_constraints(mut layout.shape)

	return layout
}

// image creates a new image view from the provided configuration.
// It displays the specified image file.
// If cfg.invisible is true, it returns an invisible ContainerView instead.
pub fn image(cfg ImageCfg) View {
	if cfg.invisible {
		return invisible_container_view()
	}
	return ImageView{
		id:         cfg.id
		file_name:  cfg.file_name
		width:      cfg.width
		min_width:  cfg.min_width
		max_width:  cfg.max_width
		height:     cfg.height
		min_height: cfg.min_height
		max_height: cfg.max_height
		invisible:  cfg.invisible
		on_click:   cfg.left_click()
		on_hover:   cfg.on_hover
	}
}

fn (cfg &ImageCfg) left_click() fn (&Layout, mut Event, mut Window) {
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
