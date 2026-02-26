module gui

import gmarkdown

// Source length caps for external API submissions (used by
// markdown_math.v and markdown_mermaid.v).
const max_latex_source_len = gmarkdown.max_latex_source_len
const max_mermaid_source_len = gmarkdown.max_mermaid_source_len

// MarkdownBlock represents a parsed, styled block of markdown.
struct MarkdownBlock {
	header_level     int
	is_code          bool
	is_hr            bool
	is_blockquote    bool
	is_image         bool
	is_table         bool
	is_list          bool
	is_math          bool
	is_def_term      bool
	is_def_value     bool
	blockquote_depth int
	list_prefix      string
	list_indent      int
	image_src        string
	image_alt        string
	image_width      f32
	image_height     f32
	code_language    string
	math_latex       string
	anchor_slug      string
	base_style       TextStyle
pub mut:
	content    RichText
	table_data ?ParsedTable
}

// ParsedTable represents a parsed, styled markdown table.
struct ParsedTable {
	headers    []RichText
	alignments []HorizontalAlign
	rows       [][]RichText
}
