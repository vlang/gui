module gui

import time
import strings

// view_markdown.v defines the Markdown view component.
// It parses markdown source and renders it using the RTF infrastructure.

// MarkdownStyle controls rendered markdown appearance.
@[minify]
pub struct MarkdownStyle {
pub:
	text                TextStyle = gui_theme.n3
	h1                  TextStyle = gui_theme.b1
	h2                  TextStyle = gui_theme.b2
	h3                  TextStyle = gui_theme.b3
	h4                  TextStyle = gui_theme.b4
	h5                  TextStyle = gui_theme.b5
	h6                  TextStyle = gui_theme.b6
	bold                TextStyle = gui_theme.b3
	italic              TextStyle = gui_theme.i3
	bold_italic         TextStyle = gui_theme.bi3
	code                TextStyle = gui_theme.m5
	code_block_bg       Color     = rgb(40, 44, 52)
	code_keyword_color  Color     = gui_theme.color_select
	code_string_color   Color     = rgb(152, 195, 121)
	code_number_color   Color     = rgb(209, 154, 102)
	code_comment_color  Color     = rgb(128, 128, 128)
	code_operator_color Color     = gui_theme.n3.color
	hr_color            Color     = gui_theme.color_border
	link_color          Color     = gui_theme.color_select
	blockquote_border   Color     = gui_theme.color_border
	blockquote_bg       Color     = rgba(128, 128, 128, 20)
	block_spacing       f32       = 8
	nest_indent         f32       = 16 // indent per nesting level for lists/blockquotes
	prefix_char_width   f32       = 8  // approx char width for list prefix column
	code_block_padding  Padding   = padding(10, 10, 10, 10)
	code_block_radius   f32       = 3.5
	h1_separator        bool
	h2_separator        bool
	// Table styling
	table_border_style TableBorderStyle = .header_only
	table_border_color Color            = gui_theme.color_border
	table_border_size  f32              = 1
	table_head_style   TextStyle        = gui_theme.b3
	table_cell_style   TextStyle        = gui_theme.n3
	table_cell_padding Padding          = padding(5, 10, 5, 10)
	table_row_alt      ?Color
	math_dpi_display   int   = 150
	math_dpi_inline    int   = 200
	mermaid_bg         Color = rgba(248, 248, 255, 255)
}

// MarkdownCfg configures a Markdown View.
// NOTE: Rendering math (LaTeX) and mermaid diagrams sends the source
// content to external third-party APIs (codecogs.com and kroki.io).
@[minify]
pub struct MarkdownCfg {
pub:
	id            string
	source        string // Raw markdown text
	style         MarkdownStyle
	id_focus      u32
	mode          TextMode = .wrap
	min_width     f32
	invisible     bool
	clip          bool
	focus_skip    bool
	disabled      bool
	color         Color = color_transparent
	color_border  Color = color_transparent
	size_border   f32
	radius        f32
	padding       Padding
	mermaid_width int = 500
}

// rich_text_plain extracts plain text from RichText for width calculation.
fn rich_text_plain(rt RichText) string {
	if rt.runs.len == 0 {
		return ''
	}
	mut sb := strings.new_builder(rt.runs.len * 32)
	for run in rt.runs {
		sb.write_string(run.text)
	}
	return sb.str()
}

// build_markdown_table_data converts parsed table to TableRowCfg array.
fn build_markdown_table_data(parsed ParsedTable, style MarkdownStyle) []TableRowCfg {
	mut rows := []TableRowCfg{cap: parsed.rows.len + 1}
	// Header row
	mut header_cells := []TableCellCfg{cap: parsed.headers.len}
	for h in parsed.headers {
		header_cells << TableCellCfg{
			value:     rich_text_plain(h)
			rich_text: h
			head_cell: true
			content:   rtf(rich_text: h, mode: .single_line)
		}
	}
	rows << TableRowCfg{
		cells: header_cells
	}
	// Data rows
	for r in parsed.rows {
		mut cells := []TableCellCfg{cap: r.len}
		for cell in r {
			cells << TableCellCfg{
				value:     rich_text_plain(cell)
				rich_text: cell
				content:   rtf(rich_text: cell, mode: .single_line)
			}
		}
		rows << TableRowCfg{
			cells: cells
		}
	}
	return rows
}

// markdown creates a view from the given MarkdownCfg
pub fn (window &Window) markdown(cfg MarkdownCfg) View {
	if cfg.invisible {
		return invisible_container_view()
	}

	// Cache lookup using source hash
	hash := cfg.source.hash()
	blocks := if cached := window.view_state.markdown_cache.get(hash) {
		cached
	} else {
		parsed := markdown_to_blocks(cfg.source, cfg.style)
		unsafe {
			mut w := window
			w.view_state.markdown_cache.set(hash, parsed)
		}
		parsed
	}

	// Trigger inline math fetches for unseen math runs
	{
		mut w := unsafe { window }
		for block in blocks {
			for run in block.content.runs {
				if run.math_id != '' {
					mhash := math_cache_hash(run.math_id)
					if _ := w.view_state.diagram_cache.get(mhash) {
					} else {
						if w.view_state.diagram_cache.loading_count() >= max_concurrent_diagram_fetches {
							continue
						}
						w.view_state.diagram_cache.set(mhash, DiagramCacheEntry{
							state: .loading
						})
						fetch_math_async(mut w, run.math_latex, mhash, cfg.style.math_dpi_inline,
							cfg.style.text.color)
					}
				}
			}
		}
	}

	// Build content views from blocks
	mut content := []View{cap: blocks.len}
	mut list_items := []View{cap: 10} // accumulate consecutive list items
	mut prev_was_blockquote := false
	for i, block in blocks {
		// Extra space after blockquote group
		if prev_was_blockquote && !block.is_blockquote {
			content << rectangle(
				sizing:      fill_fixed
				height:      cfg.style.block_spacing
				size_border: 0
			)
		}
		prev_was_blockquote = block.is_blockquote
		// Check if we need to flush accumulated list items
		if !block.is_list && list_items.len > 0 {
			content << column(
				sizing:      fill_fit
				padding:     padding_none
				size_border: 0
				spacing:     cfg.style.block_spacing / 2
				content:     list_items
			)
			list_items = []View{cap: 10}
			// Extra space after outer list
			content << rectangle(
				sizing:      fill_fixed
				height:      cfg.style.block_spacing
				size_border: 0
			)
		}
		if block.is_math {
			// Display math block — async render via Codecogs
			// NOTE: LaTeX source is sent to external codecogs API
			diagram_hash := math_cache_hash('display_${block.math_latex.hash()}')
			mut w := unsafe { window }
			if entry := w.view_state.diagram_cache.get(diagram_hash) {
				match entry.state {
					.loading {
						content << column(
							color:       cfg.style.code_block_bg
							padding:     cfg.style.code_block_padding
							radius:      cfg.style.code_block_radius
							size_border: 0
							sizing:      fill_fit
							h_align:     .center
							content:     [
								text(
									text:       block.math_latex
									text_style: cfg.style.code
								),
							]
						)
					}
					.ready {
						content << column(
							padding:     cfg.style.code_block_padding
							radius:      cfg.style.code_block_radius
							size_border: 0
							sizing:      fill_fit
							h_align:     .center
							content:     [
								image(src: entry.png_path),
							]
						)
					}
					.error {
						content << column(
							color:       cfg.style.code_block_bg
							padding:     cfg.style.code_block_padding
							radius:      cfg.style.code_block_radius
							size_border: 0
							sizing:      fill_fit
							content:     [
								text(
									text:       entry.error
									text_style: TextStyle{
										...cfg.style.code
										color: rgba(200, 50, 50, 255)
									}
								),
							]
						)
					}
				}
			} else {
				// Start async fetch (if under concurrency limit)
				if w.view_state.diagram_cache.loading_count() < max_concurrent_diagram_fetches {
					w.view_state.diagram_cache.set(diagram_hash, DiagramCacheEntry{
						state: .loading
					})
					fetch_math_async(mut w, block.math_latex, diagram_hash, cfg.style.math_dpi_display,
						cfg.style.text.color)
				}
				content << column(
					color:       cfg.style.code_block_bg
					padding:     cfg.style.code_block_padding
					radius:      cfg.style.code_block_radius
					size_border: 0
					sizing:      fill_fit
					h_align:     .center
					content:     [
						text(
							text:       block.math_latex
							text_style: cfg.style.code
						),
					]
				)
			}
		} else if block.is_code {
			if block.code_language == 'mermaid' {
				// Mermaid diagram - async render via Kroki (PNG format)
				// NOTE: Mermaid source is sent to external kroki.io API
				source := rich_text_plain(block.content)
				// Combine hash with length for better collision resistance
				diagram_hash := i64((u64(source.hash()) << 32) | u64(source.len))
				mut w := unsafe { window }
				if entry := w.view_state.diagram_cache.get(diagram_hash) {
					match entry.state {
						.loading {
							content << column(
								color:       cfg.style.code_block_bg
								padding:     cfg.style.code_block_padding
								radius:      cfg.style.code_block_radius
								size_border: 0
								sizing:      fill_fit
								h_align:     .center
								content:     [text(text: 'Loading diagram...')]
							)
						}
						.ready {
							content << column(
								color:       cfg.style.mermaid_bg
								padding:     cfg.style.code_block_padding
								radius:      cfg.style.code_block_radius
								size_border: 0
								sizing:      fill_fit
								content:     [
									image(src: entry.png_path),
								]
							)
						}
						.error {
							content << column(
								color:       cfg.style.code_block_bg
								padding:     cfg.style.code_block_padding
								radius:      cfg.style.code_block_radius
								size_border: 0
								sizing:      fill_fit
								content:     [
									text(
										text:       entry.error
										text_style: TextStyle{
											...cfg.style.code
											color: rgba(200, 50, 50, 255)
										}
									),
								]
							)
						}
					}
				} else {
					// Start async fetch (if under concurrency limit)
					if w.view_state.diagram_cache.loading_count() < max_concurrent_diagram_fetches {
						w.view_state.diagram_cache.set(diagram_hash, DiagramCacheEntry{
							state: .loading
						})
						fetch_mermaid_async(mut w, source, diagram_hash, cfg.mermaid_width,
							cfg.style.mermaid_bg.r, cfg.style.mermaid_bg.g, cfg.style.mermaid_bg.b)
					}
					content << column(
						color:       cfg.style.code_block_bg
						padding:     cfg.style.code_block_padding
						radius:      cfg.style.code_block_radius
						size_border: 0
						sizing:      fill_fit
						h_align:     .center
						content:     [text(text: 'Loading diagram...')]
					)
				}
			} else {
				// Regular code block in a column with background
				code_text := rich_text_plain(block.content)
				cp_id := 'md_cp_${code_text.hash()}'
				mut w := unsafe { window }
				white120 := rgba(255, 255, 255, 120)
				cp_alt := w.has_animation('btn_alt_${cp_id}')
				content << column(
					color:       cfg.style.code_block_bg
					padding:     cfg.style.code_block_padding
					radius:      cfg.style.code_block_radius
					size_border: 0
					sizing:      fill_fit
					clip:        true
					content:     [
						rtf(
							rich_text: block.content
							mode:      .single_line
						),
						button(
							id:             cp_id
							show_alt:       cp_alt
							size_border:    if cp_alt { f32(1) } else { 0 }
							color_border:   white120
							float:          true
							float_anchor:   .top_right
							float_tie_off:  .top_right
							float_offset_x: -4
							float_offset_y: 4
							padding:        pad_all(4)
							radius:         4
							color:          rgba(255, 255, 255, 15)
							color_hover:    rgba(255, 255, 255, 40)
							on_click:       fn [code_text] (_ &Layout, mut e Event, mut _ Window) {
								to_clipboard(code_text)
								e.is_handled = true
							}
							content:        [
								text(
									text:       icon_document
									text_style: TextStyle{
										family: icon_font_name
										size:   12
										color:  white120
									}
								),
							]
							alt_content:    [
								text(
									text:       'Copied ✓'
									text_style: TextStyle{
										size:  11
										color: white120
									}
								),
							]
							alt_duration:   2 * time.second
						),
					]
				)
			}
		} else if block.is_table {
			// Table rendered using table view
			if parsed := block.table_data {
				mut w := unsafe { window }
				content << w.table(
					border_style:      cfg.style.table_border_style
					color_border:      cfg.style.table_border_color
					size_border:       cfg.style.table_border_size
					text_style_head:   cfg.style.table_head_style
					text_style:        cfg.style.table_cell_style
					cell_padding:      cfg.style.table_cell_padding
					color_row_alt:     cfg.style.table_row_alt
					column_alignments: parsed.alignments
					data:              build_markdown_table_data(parsed, cfg.style)
				)
			} else {
				// Fallback: render as code block
				content << column(
					color:       cfg.style.code_block_bg
					padding:     cfg.style.code_block_padding
					radius:      cfg.style.code_block_radius
					size_border: 0
					sizing:      fill_fit
					clip:        true
					content:     [
						rtf(
							rich_text: block.content
							mode:      .single_line
						),
					]
				)
			}
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
				sizing:      fill_fit
				size_border: 0
				padding:     padding(0, 0, 0, left_margin)
				content:     [
					rectangle(
						sizing: fixed_fill
						width:  3
						color:  cfg.style.blockquote_border
					),
					column(
						padding:     padding_none
						size_border: 0
						sizing:      fill_fit
						content:     [
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
			if block.image_src.to_lower().ends_with('.svg') {
				content << svg(
					file_name: block.image_src
					width:     block.image_width
					height:    block.image_height
				)
			} else {
				content << image(
					src:    block.image_src
					width:  block.image_width
					height: block.image_height
				)
			}
		} else if block.header_level > 0 {
			// Header block
			content << rtf(rich_text: block.content, mode: cfg.mode)
			if (block.header_level == 1 && cfg.style.h1_separator)
				|| (block.header_level == 2 && cfg.style.h2_separator) {
				content << rectangle(
					sizing: fill_fixed
					height: 1
					color:  cfg.style.hr_color
				)
			}
		} else if block.is_def_term {
			// Definition term - rendered bold
			content << rtf(rich_text: block.content, mode: cfg.mode)
		} else if block.is_def_value {
			// Definition value - indented
			content << row(
				sizing:  fill_fit
				padding: padding(0, 0, 0, cfg.style.nest_indent)
				content: [rtf(rich_text: block.content, mode: cfg.mode)]
			)
		} else if block.is_list {
			// List item as two-column row: fixed bullet column + fill content column
			indent_width := if block.list_indent > 0 {
				f32(block.list_indent - 1) * cfg.style.nest_indent
			} else {
				0
			}
			mut prefix_width := f32(block.list_prefix.len) * cfg.style.prefix_char_width
			if block.list_prefix == '• ' {
				prefix_width /= 2
			}
			list_items << row(
				sizing:      fill_fit
				spacing:     0
				size_border: 0
				padding:     padding(0, 0, 0, indent_width)
				content:     [
					column(
						sizing:      fixed_fit
						width:       prefix_width
						padding:     padding_none
						size_border: 0
						content:     [
							text(
								text:       block.list_prefix
								text_style: cfg.style.text
							),
						]
					),
					column(
						sizing:      fill_fit
						padding:     padding_none
						size_border: 0
						content:     [
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
					sizing:      fill_fit
					padding:     padding_none
					size_border: 0
					spacing:     cfg.style.block_spacing / 2
					content:     list_items
				)
				list_items = []View{cap: 10}
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

	source := cfg.source
	cp_doc_id := 'md_cp_doc_${hash}'
	mut w2 := unsafe { window }
	doc_icon_color := cfg.style.text.color
	doc_alt := w2.has_animation('btn_alt_${cp_doc_id}')
	content << button(
		id:             cp_doc_id
		show_alt:       doc_alt
		size_border:    if doc_alt { f32(1) } else { 0 }
		color_border:   doc_icon_color
		float:          true
		float_anchor:   .top_right
		float_tie_off:  .top_right
		float_offset_x: -4
		float_offset_y: 4
		padding:        pad_all(4)
		radius:         4
		color:          rgba(128, 128, 128, 20)
		color_hover:    rgba(128, 128, 128, 50)
		on_click:       fn [source] (_ &Layout, mut e Event, mut _ Window) {
			to_clipboard(source)
			e.is_handled = true
		}
		content:        [
			text(
				text:       icon_document
				text_style: TextStyle{
					family: icon_font_name
					size:   12
					color:  doc_icon_color
				}
			),
		]
		alt_content:    [
			text(
				text:       'Copied ✓'
				text_style: TextStyle{
					size:  11
					color: doc_icon_color
				}
			),
		]
		alt_duration:   2 * time.second
	)

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
