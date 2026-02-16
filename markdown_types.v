module gui

// Bounds for multi-line constructs (self-synchronization limits)
const max_blockquote_lines = 100
const max_table_lines = 500
const max_table_columns = 100
const max_list_continuation_lines = 50
const max_footnote_continuation_lines = 20
const max_paragraph_continuation_lines = 100
const max_code_block_lines = 10000
const max_math_block_lines = 200

// Inline parsing limits
const max_inline_nesting_depth = 16

// Source length caps for external API submissions
const max_latex_source_len = 2000
const max_mermaid_source_len = 10000

// Metadata collection limits
const max_abbreviation_defs = 1000
const max_footnote_defs = 10000
const max_link_defs = 10000

// CodeBlockState tracks whether we're inside a fenced code block.
struct CodeBlockState {
	in_code_block bool
	fence_char    u8
	fence_count   int
}

// CodeFence represents a parsed code fence line.
struct CodeFence {
	char     u8
	count    int
	language string
}

// MarkdownBlock represents a parsed block of markdown content.
struct MarkdownBlock {
	header_level     int // 0=not header, 1-6 for h1-h6
	is_code          bool
	is_hr            bool
	is_blockquote    bool
	is_image         bool
	is_table         bool
	is_list          bool
	is_math          bool
	is_def_term      bool // definition list term
	is_def_value     bool // definition list value
	blockquote_depth int
	list_prefix      string // "• ", "1. ", "☐ ", "☑ "
	list_indent      int    // nesting level (0, 1, 2...)
	image_src        string
	image_alt        string
	image_width      f32    // 0 = auto
	image_height     f32    // 0 = auto
	code_language    string // language hint from code fence
	math_latex       string // raw LaTeX source for math blocks
	anchor_slug      string // URL slug for heading anchors
pub mut:
	content    RichText
	table_data ?ParsedTable // parsed table with inline formatting
}

// ParsedTable represents a parsed markdown table.
struct ParsedTable {
	headers    []RichText
	alignments []HorizontalAlign
	rows       [][]RichText
}
