module gui

struct ImageView implements View {
pub:
	id         string
	file_name  string
	width      f32
	height     f32
	min_width  f32
	min_height f32
	max_width  f32
	max_height f32
	invisible  bool
	cfg        &ImageCfg
	on_click   fn (&ImageCfg, mut Event, mut Window)  = unsafe { nil }
	on_hover   fn (mut Layout, mut Event, mut Window) = unsafe { nil }
mut:
	content []View // not used
}

@[heap]
pub struct ImageCfg {
pub:
	id         string
	file_name  string
	width      f32
	height     f32
	min_width  f32
	min_height f32
	max_width  f32
	max_height f32
	invisible  bool
	on_click   fn (&ImageCfg, mut Event, mut Window)  = unsafe { nil }
	on_hover   fn (mut Layout, mut Event, mut Window) = unsafe { nil }
}

fn (iv &ImageView) generate(mut window Window) Layout {
	if iv.invisible {
		return Layout{}
	}
	image := window.load_image_from_file(iv.file_name) or {
		eprintln(err.msg())
		return Layout{}
	}

	width := if iv.width > 0 { iv.width } else { image.width }
	height := if iv.height > 0 { iv.height } else { image.height }

	layout := Layout{
		shape: Shape{
			name:       'image'
			type:       .image
			id:         iv.id
			image_name: iv.file_name
			width:      width
			min_width:  iv.min_width
			height:     height
			min_height: iv.min_height
			cfg:        iv.cfg
			on_click:   iv.on_click
			on_hover:   iv.on_hover
		}
	}
	return layout
}

pub fn image(cfg ImageCfg) ImageView {
	return ImageView{
		id:         cfg.id
		file_name:  cfg.file_name
		width:      cfg.width
		min_width:  cfg.min_width
		height:     cfg.height
		min_height: cfg.min_height
		invisible:  cfg.invisible
		cfg:        &cfg
		on_click:   cfg.on_click
		on_hover:   cfg.on_hover
	}
}
