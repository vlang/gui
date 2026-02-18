module gui

import gmarkdown as markdown
import vglyph

// markdown_style.v bridges the style-free markdown AST to
// gui-styled MarkdownBlock/RichText types.

const md_superscript_features = &vglyph.FontFeatures{
	opentype_features: [vglyph.FontFeature{'sups', 1}]
}

const md_subscript_features = &vglyph.FontFeatures{
	opentype_features: [vglyph.FontFeature{'subs', 1}]
}

// markdown_to_blocks parses markdown source and returns styled blocks.
fn markdown_to_blocks(source string, style MarkdownStyle) []MarkdownBlock {
	ast := markdown.parse_with_options(source, markdown.ParseOptions{
		hard_line_breaks: style.hard_line_breaks
	})
	return style_md_blocks(ast, style)
}

// markdown_to_rich_text parses markdown and returns a single RichText.
pub fn markdown_to_rich_text(source string, style MarkdownStyle) RichText {
	blocks := markdown_to_blocks(source, style)
	mut all_runs := []RichTextRun{}
	for i, block in blocks {
		all_runs << block.content.runs
		if i < blocks.len - 1 {
			all_runs << rich_br()
		}
	}
	return RichText{
		runs: all_runs
	}
}

fn style_md_blocks(blocks []markdown.MdBlock, style MarkdownStyle) []MarkdownBlock {
	mut result := []MarkdownBlock{cap: blocks.len}
	for block in blocks {
		result << style_md_block(block, style)
	}
	return result
}

fn style_md_block(block markdown.MdBlock, style MarkdownStyle) MarkdownBlock {
	// Determine base style for runs
	base_style := if block.header_level > 0 {
		match block.header_level {
			1 { style.h1 }
			2 { style.h2 }
			3 { style.h3 }
			4 { style.h4 }
			5 { style.h5 }
			else { style.h6 }
		}
	} else if block.is_def_term {
		style.bold
	} else {
		style.text
	}

	mut styled_block := MarkdownBlock{
		header_level:     block.header_level
		is_code:          block.is_code
		is_hr:            block.is_hr
		is_blockquote:    block.is_blockquote
		is_image:         block.is_image
		is_table:         block.is_table
		is_list:          block.is_list
		is_math:          block.is_math
		is_def_term:      block.is_def_term
		is_def_value:     block.is_def_value
		blockquote_depth: block.blockquote_depth
		list_prefix:      block.list_prefix
		list_indent:      block.list_indent
		image_src:        block.image_src
		image_alt:        block.image_alt
		image_width:      block.image_width
		image_height:     block.image_height
		code_language:    block.code_language
		math_latex:       block.math_latex
		anchor_slug:      block.anchor_slug
		content:          style_md_runs(block.runs, base_style, style)
	}

	if table := block.table_data {
		styled_block.table_data = style_md_table(table, style)
	}

	return styled_block
}

fn style_md_runs(runs []markdown.MdRun, base_style TextStyle, style MarkdownStyle) RichText {
	mut styled := []RichTextRun{cap: runs.len}
	for run in runs {
		styled << style_md_run(run, base_style, style)
	}
	return RichText{
		runs: styled
	}
}

fn style_md_run(run markdown.MdRun, base_style TextStyle, style MarkdownStyle) RichTextRun {
	mut s := md_format_to_style(run.format, base_style, style)

	// Apply code token coloring
	if run.format == .code && run.code_token != .plain {
		s = md_code_token_style(run.code_token, style)
	}

	// Apply strikethrough
	if run.strikethrough {
		s = TextStyle{
			...s
			strikethrough: true
		}
	}

	// Apply highlight background
	if run.highlight {
		s = TextStyle{
			...s
			bg_color: style.highlight_bg
		}
	}

	// Apply superscript
	if run.superscript {
		s = TextStyle{
			...s
			size:     s.size * 1.2
			features: md_superscript_features
		}
	}

	// Apply subscript
	if run.subscript {
		s = TextStyle{
			...s
			size:     s.size * 1.2
			features: md_subscript_features
		}
	}

	// Apply underline
	if run.underline {
		s = TextStyle{
			...s
			underline: true
		}
	}

	// Link coloring
	if run.link != '' {
		s = TextStyle{
			...s
			color:     style.link_color
			underline: true
		}
	}

	// Footnote sizing
	if run.tooltip != '' && run.link == '' && run.text.starts_with('\xE2\x80\x89[') {
		// Footnote marker — reduce size
		s = TextStyle{
			...s
			size: s.size * 0.7
		}
	}

	// Abbreviation — bold typeface
	if run.tooltip != '' && run.link == '' && !run.text.starts_with('\xE2\x80\x89[') {
		s = TextStyle{
			...s
			typeface: .bold
		}
	}

	return RichTextRun{
		text:       run.text
		style:      s
		link:       run.link
		tooltip:    run.tooltip
		math_id:    run.math_id
		math_latex: run.math_latex
	}
}

fn md_format_to_style(fmt markdown.MdFormat, base TextStyle, style MarkdownStyle) TextStyle {
	return match fmt {
		.bold {
			TextStyle{
				...style.bold
				size:     base.size
				bg_color: base.bg_color
			}
		}
		.italic {
			TextStyle{
				...style.italic
				size:     base.size
				bg_color: base.bg_color
			}
		}
		.bold_italic {
			TextStyle{
				...style.bold_italic
				size:     base.size
				bg_color: base.bg_color
			}
		}
		.code {
			style.code
		}
		.plain {
			base
		}
	}
}

fn md_code_token_style(kind markdown.MdCodeTokenKind, style MarkdownStyle) TextStyle {
	return match kind {
		.plain {
			style.code
		}
		.keyword {
			TextStyle{
				...style.code
				color: style.code_keyword_color
			}
		}
		.string_ {
			TextStyle{
				...style.code
				color: style.code_string_color
			}
		}
		.number {
			TextStyle{
				...style.code
				color: style.code_number_color
			}
		}
		.comment {
			TextStyle{
				...style.code
				color: style.code_comment_color
			}
		}
		.operator {
			TextStyle{
				...style.code
				color: style.code_operator_color
			}
		}
	}
}

fn style_md_table(table markdown.MdTable, style MarkdownStyle) ParsedTable {
	mut header_rich := []RichText{cap: table.headers.len}
	for h in table.headers {
		header_rich << style_md_runs(h, style.text, style)
	}

	mut rows := [][]RichText{cap: table.rows.len}
	for row in table.rows {
		mut styled_row := []RichText{len: table.col_count, init: RichText{}}
		for j, cell in row {
			if j < table.col_count {
				styled_row[j] = style_md_runs(cell, style.text, style)
			}
		}
		rows << styled_row
	}

	return ParsedTable{
		headers:    header_rich
		alignments: md_aligns_to_haligns(table.alignments)
		rows:       rows
	}
}

fn md_aligns_to_haligns(aligns []markdown.MdAlign) []HorizontalAlign {
	mut result := []HorizontalAlign{len: aligns.len, init: HorizontalAlign.start}
	for i, a in aligns {
		result[i] = md_align_to_halign(a)
	}
	return result
}

fn md_align_to_halign(a markdown.MdAlign) HorizontalAlign {
	return match a {
		.start { HorizontalAlign.start }
		.end_ { HorizontalAlign.end }
		.center { HorizontalAlign.center }
		.left { HorizontalAlign.left }
		.right { HorizontalAlign.right }
	}
}
