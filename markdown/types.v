module markdown

// Bounds for multi-line constructs (self-synchronization limits)
pub const max_blockquote_lines = 100
pub const max_table_lines = 500
pub const max_table_columns = 100
pub const max_list_continuation_lines = 50
pub const max_footnote_continuation_lines = 20
pub const max_paragraph_continuation_lines = 100
pub const max_code_block_lines = 10000
pub const max_math_block_lines = 200

// Inline parsing limits
pub const max_inline_nesting_depth = 16

// Source length caps for external API submissions
pub const max_latex_source_len = 2000
pub const max_mermaid_source_len = 10000

// Metadata collection limits
pub const max_abbreviation_defs = 1000
pub const max_footnote_defs = 10000
pub const max_link_defs = 10000

pub enum MdAlign as u8 {
	start
	end_
	center
	left
	right
}

pub enum MdFormat as u8 {
	plain
	bold
	italic
	bold_italic
	code
}

pub struct MdRun {
pub:
	text          string
	format        MdFormat = .plain
	strikethrough bool
	underline     bool
	highlight     bool // ==text==
	superscript   bool
	subscript     bool
	link          string
	tooltip       string // abbreviation or footnote
	math_id       string
	math_latex    string
	code_token    MdCodeTokenKind = .plain
}

pub struct MdBlock {
pub:
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
pub mut:
	runs       []MdRun
	table_data ?MdTable
}

pub struct MdTable {
pub:
	headers    [][]MdRun
	alignments []MdAlign
	rows       [][][]MdRun // each row is [][]MdRun (cells of runs)
	col_count  int
}

pub enum MdCodeTokenKind as u8 {
	plain
	keyword
	string_
	number
	comment
	operator
}

pub enum MdCodeLanguage {
	generic
	vlang
	javascript
	typescript
	python
	json
	golang
	rust
	c_lang
	shell
	html
}

// MdCodeToken represents a highlighted token span.
pub struct MdCodeToken {
pub:
	kind MdCodeTokenKind
pub mut:
	start int
	end   int
}

// CodeBlockState tracks whether we're inside a fenced code block.
pub struct CodeBlockState {
pub:
	in_code_block bool
	fence_char    u8
	fence_count   int
}

// CodeFence represents a parsed code fence line.
pub struct CodeFence {
pub:
	char     u8
	count    int
	language string
}

// ParseOptions controls parsing behavior.
pub struct ParseOptions {
pub:
	hard_line_breaks bool
}

// MdScanner provides line-indexed access to markdown source text.
pub struct MdScanner {
	source  string
	offsets []int
}

pub fn new_scanner(source string) MdScanner {
	mut offsets := [0]
	for i := 0; i < source.len; i++ {
		if source[i] == `\n` {
			offsets << i + 1
		}
	}
	return MdScanner{
		source:  source
		offsets: offsets
	}
}

pub fn (s MdScanner) get_line(i int) string {
	if i < 0 || i >= s.offsets.len {
		return ''
	}
	start := s.offsets[i]
	end := if i + 1 < s.offsets.len {
		s.offsets[i + 1] - 1
	} else {
		s.source.len
	}
	// Handle \r\n
	mut real_end := end
	if real_end > start && s.source[real_end - 1] == `\r` {
		real_end--
	}
	return s.source[start..real_end]
}

pub fn (s MdScanner) len() int {
	return s.offsets.len
}
