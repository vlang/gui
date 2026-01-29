module gui

// view_markdown.v defines the Markdown view component.
// It parses markdown source and renders it using the RTF infrastructure.

// MarkdownStyle controls rendered markdown appearance.
@[minify]
pub struct MarkdownStyle {
pub:
	text          TextStyle = gui_theme.n3
	h1            TextStyle = gui_theme.b1
	h2            TextStyle = gui_theme.b2
	h3            TextStyle = gui_theme.b3
	h4            TextStyle = gui_theme.b4
	h5            TextStyle = gui_theme.b5
	h6            TextStyle = gui_theme.b6
	bold          TextStyle = gui_theme.b3
	italic        TextStyle = gui_theme.i3
	code          TextStyle = gui_theme.m3
	code_block_bg Color     = gui_theme.color_interior
	hr_color      Color     = gui_theme.color_border
	link_color    Color     = gui_theme.color_select
	block_spacing f32       = 8
}

// MarkdownCfg configures a Markdown View.
@[minify]
pub struct MarkdownCfg {
pub:
	id         string
	source     string // Raw markdown text
	style      MarkdownStyle
	id_focus   u32
	mode       TextMode = .wrap
	min_width  f32
	invisible  bool
	clip       bool
	focus_skip bool
	disabled   bool
}

// markdown creates a view from the given MarkdownCfg
pub fn markdown(cfg MarkdownCfg) View {
	if cfg.invisible {
		return invisible_container_view()
	}

	blocks := markdown_to_blocks(cfg.source, cfg.style)

	// Build content views from blocks
	mut content := []View{cap: blocks.len}
	for block in blocks {
		if block.is_code {
			// Code block in a column with background
			content << column(
				color:   cfg.style.code_block_bg
				padding: gui_theme.padding_medium
				radius:  gui_theme.radius_small
				sizing:  fit_fit
				content: [
					rtf(
						rich_text: block.content
						mode:      .single_line
					),
				]
			)
		} else {
			content << rtf(
				id:         cfg.id
				id_focus:   cfg.id_focus
				clip:       cfg.clip
				focus_skip: cfg.focus_skip
				disabled:   cfg.disabled
				min_width:  cfg.min_width
				mode:       cfg.mode
				rich_text:  block.content
			)
		}
	}

	return column(
		spacing: cfg.style.block_spacing
		sizing:  if cfg.mode in [.wrap, .wrap_keep_spaces] { fill_fit } else { fit_fit }
		content: content
	)
}
