module gui

// view_markdown.v defines the Markdown view component.
// It parses markdown source and renders it using the RTF infrastructure.

// MarkdownStyle controls rendered markdown appearance.
@[minify]
pub struct MarkdownStyle {
pub:
	text              TextStyle = gui_theme.n3
	h1                TextStyle = gui_theme.b1
	h2                TextStyle = gui_theme.b2
	h3                TextStyle = gui_theme.b3
	h4                TextStyle = gui_theme.b4
	h5                TextStyle = gui_theme.b5
	h6                TextStyle = gui_theme.b6
	bold              TextStyle = gui_theme.b3
	italic            TextStyle = gui_theme.i3
	bold_italic       TextStyle = gui_theme.b3 // TODO: needs vglyph bold+italic support
	code              TextStyle = gui_theme.m5
	code_block_bg     Color     = gui_theme.color_interior
	hr_color          Color     = gui_theme.color_border
	link_color        Color     = gui_theme.color_select
	blockquote_border Color     = gui_theme.color_border
	blockquote_bg     Color     = rgba(128, 128, 128, 20)
	block_spacing     f32       = 8
	nest_indent       f32       = 16 // indent per nesting level for lists/blockquotes
	prefix_char_width f32       = 8  // approx char width for list prefix column
}

// MarkdownCfg configures a Markdown View.
@[minify]
pub struct MarkdownCfg {
pub:
	id           string
	source       string // Raw markdown text
	style        MarkdownStyle
	id_focus     u32
	mode         TextMode = .wrap
	min_width    f32
	invisible    bool
	clip         bool
	focus_skip   bool
	disabled     bool
	color        Color = color_transparent
	color_border Color = color_transparent
	size_border  f32
	radius       f32
	padding      Padding
}

// markdown creates a view from the given MarkdownCfg
pub fn markdown(cfg MarkdownCfg) View {
	if cfg.invisible {
		return invisible_container_view()
	}

	blocks := markdown_to_blocks(cfg.source, cfg.style)

	// Build content views from blocks
	mut content := []View{cap: blocks.len}
	mut list_items := []View{} // accumulate consecutive list items
	for i, block in blocks {
		// Check if we need to flush accumulated list items
		if !block.is_list && list_items.len > 0 {
			content << column(
				sizing:  fill_fit
				padding: Padding{}
				spacing: cfg.style.block_spacing / 2
				content: list_items.clone()
			)
			list_items.clear()
		}
		if block.is_code || block.is_table {
			// Code block / table in a column with background
			content << column(
				color:   cfg.style.code_block_bg
				padding: gui_theme.padding_medium
				radius:  gui_theme.radius_small
				sizing:  fill_fit
				clip:    block.is_code
				content: [
					rtf(
						rich_text: block.content
						mode:      .single_line
					),
				]
			)
		} else if block.is_hr {
			// Horizontal rule - fill width
			content << rectangle(
				sizing: fill_fixed
				height: 1
				color:  cfg.style.hr_color
			)
		} else if block.is_blockquote {
			// Blockquote with left border, increased margin for nested quotes
			left_margin := f32(block.blockquote_depth - 1) * cfg.style.nest_indent
			content << row(
				sizing:  fill_fit
				padding: padding(0, 0, 0, left_margin)
				content: [
					rectangle(
						sizing: fixed_fill
						width:  3
						color:  cfg.style.blockquote_border
					),
					column(
						color:   cfg.style.blockquote_bg
						padding: padding(8, 12, 8, 12)
						sizing:  fill_fit
						content: [
							rtf(
								rich_text: block.content
								mode:      cfg.mode
							),
						]
					),
				]
			)
		} else if block.is_image {
			// Image block
			content << image(file_name: block.image_src)
		} else if block.is_list {
			// List item as two-column row: fixed bullet column + fill content column
			indent_width := if block.list_indent > 0 {
				f32(block.list_indent - 1) * cfg.style.nest_indent
			} else {
				0
			}
			prefix_width := f32(block.list_prefix.len) * cfg.style.prefix_char_width
			list_items << row(
				sizing:  fill_fit
				spacing: 0
				padding: padding(0, 0, 0, indent_width)
				content: [
					column(
						sizing:  fixed_fit
						width:   prefix_width
						padding: padding_none
						content: [
							text(
								text:       block.list_prefix
								text_style: cfg.style.text
							),
						]
					),
					column(
						sizing:  fill_fit
						padding: padding_none
						content: [
							rtf(
								rich_text: block.content
								mode:      cfg.mode
							),
						]
					),
				]
			)
			// Flush if last block
			if i == blocks.len - 1 {
				content << column(
					sizing:  fill_fit
					padding: Padding{}
					spacing: cfg.style.block_spacing / 2
					content: list_items.clone()
				)
				list_items.clear()
			}
			continue
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
		color:        cfg.color
		color_border: cfg.color_border
		size_border:  cfg.size_border
		radius:       cfg.radius
		padding:      cfg.padding
		spacing:      cfg.style.block_spacing
		sizing:       if cfg.mode in [.wrap, .wrap_keep_spaces] { fill_fit } else { fit_fit }
		content:      content
	)
}
