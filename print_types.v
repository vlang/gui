module gui

const native_print_error_code_invalid_cfg = 'invalid_cfg'
const native_print_error_code_io = 'io_error'
const native_print_error_code_render = 'render_error'
const native_print_error_code_internal = 'internal'

pub enum PaperSize as u8 {
	letter
	legal
	a4
	a3
}

pub enum PrintOrientation as u8 {
	portrait
	landscape
}

pub struct PrintMargins {
pub:
	top    f32 = 36.0
	right  f32 = 36.0
	bottom f32 = 36.0
	left   f32 = 36.0
}

pub fn default_print_margins() PrintMargins {
	return PrintMargins{}
}

pub enum PrintScaleMode as u8 {
	fit_to_page
	actual_size
}

pub enum PrintDuplexMode as u8 {
	default_mode
	simplex
	long_edge
	short_edge
}

pub enum PrintColorMode as u8 {
	default_mode
	color
	grayscale
}

pub struct PrintPageRange {
pub:
	from int
	to   int
}

pub struct PrintHeaderFooterCfg {
pub:
	enabled bool
	left    string
	center  string
	right   string
}

pub enum PrintJobSourceKind as u8 {
	current_view
	pdf_path
}

pub struct PrintJobSource {
pub:
	kind     PrintJobSourceKind = .current_view
	pdf_path string
}

pub struct PrintJob {
pub:
	output_path   string
	title         string
	job_name      string
	paper         PaperSize        = .a4
	orientation   PrintOrientation = .portrait
	margins       PrintMargins     = default_print_margins()
	source        PrintJobSource
	paginate      bool
	scale_mode    PrintScaleMode = .fit_to_page
	page_ranges   []PrintPageRange
	copies        int             = 1
	duplex        PrintDuplexMode = .default_mode
	color_mode    PrintColorMode  = .default_mode
	header        PrintHeaderFooterCfg
	footer        PrintHeaderFooterCfg
	source_width  f32
	source_height f32
	raster_dpi    int = 300
	jpeg_quality  int = 85
}

pub enum PrintRunStatus as u8 {
	ok
	cancel
	error
}

pub struct PrintWarning {
pub:
	code    string
	message string
}

pub struct PrintRunResult {
pub:
	status        PrintRunStatus
	error_code    string
	error_message string
	pdf_path      string
	warnings      []PrintWarning
}

pub enum PrintExportStatus as u8 {
	ok
	error
}

pub struct PrintExportResult {
pub:
	status        PrintExportStatus
	path          string
	error_code    string
	error_message string
}

pub fn (result PrintExportResult) is_ok() bool {
	return result.status == .ok
}

fn print_run_error_result(code string, message string) PrintRunResult {
	return PrintRunResult{
		status:        .error
		error_code:    code
		error_message: message
	}
}

fn print_run_cancel_result() PrintRunResult {
	return PrintRunResult{
		status: .cancel
	}
}

fn print_run_ok_result(path string, warnings []PrintWarning) PrintRunResult {
	return PrintRunResult{
		status:   .ok
		pdf_path: path
		warnings: warnings
	}
}

fn print_export_error_result(path string, code string, message string) PrintExportResult {
	return PrintExportResult{
		status:        .error
		path:          path
		error_code:    code
		error_message: message
	}
}

fn print_export_ok_result(path string) PrintExportResult {
	return PrintExportResult{
		status: .ok
		path:   path
	}
}

fn print_page_size(paper PaperSize, orientation PrintOrientation) (f32, f32) {
	mut width := f32(595.0)
	mut height := f32(842.0)
	match paper {
		.letter {
			width = 612.0
			height = 792.0
		}
		.legal {
			width = 612.0
			height = 1008.0
		}
		.a4 {
			width = 595.0
			height = 842.0
		}
		.a3 {
			width = 842.0
			height = 1191.0
		}
	}
	return if orientation == .landscape {
		height, width
	} else {
		width, height
	}
}

fn validate_print_margins(page_width f32, page_height f32, margins PrintMargins) ! {
	if margins.left < 0 || margins.right < 0 || margins.top < 0 || margins.bottom < 0 {
		return error('margins must be non-negative')
	}
	if margins.left + margins.right >= page_width {
		return error('horizontal margins exceed printable width')
	}
	if margins.top + margins.bottom >= page_height {
		return error('vertical margins exceed printable height')
	}
}

fn validate_print_job(job PrintJob) ! {
	page_width, page_height := print_page_size(job.paper, job.orientation)
	validate_print_margins(page_width, page_height, job.margins)!
	if job.copies < 1 {
		return error('copies must be >= 1')
	}
	match job.source.kind {
		.current_view {}
		.pdf_path {
			if job.source.pdf_path.trim_space().len == 0 {
				return error('pdf_path is required for pdf_path source')
			}
		}
	}
	for range in job.page_ranges {
		if range.from < 1 || range.to < range.from {
			return error('invalid page range ${range.from}-${range.to}')
		}
	}
	validate_header_footer_cfg(job.header)!
	validate_header_footer_cfg(job.footer)!
	if job.raster_dpi < 72 || job.raster_dpi > 1200 {
		return error('raster_dpi must be 72..1200')
	}
	if job.jpeg_quality < 10 || job.jpeg_quality > 100 {
		return error('jpeg_quality must be 10..100')
	}
}

fn validate_export_print_job(job PrintJob) ! {
	if job.output_path.trim_space().len == 0 {
		return error('output_path is required')
	}
	validate_print_job(job)!
}

fn validate_header_footer_cfg(cfg PrintHeaderFooterCfg) ! {
	if !cfg.enabled {
		return
	}
	for token in extract_print_tokens(cfg.left) {
		validate_print_token(token)!
	}
	for token in extract_print_tokens(cfg.center) {
		validate_print_token(token)!
	}
	for token in extract_print_tokens(cfg.right) {
		validate_print_token(token)!
	}
}

fn extract_print_tokens(text string) []string {
	mut tokens := []string{}
	mut i := 0
	for i < text.len {
		if text[i] == `{` {
			mut j := i + 1
			for j < text.len && text[j] != `}` {
				j++
			}
			if j < text.len && j > i + 1 {
				tokens << text[i + 1..j]
				i = j + 1
				continue
			}
		}
		i++
	}
	return tokens
}

fn validate_print_token(token string) ! {
	if token in ['page', 'pages', 'date', 'title', 'job'] {
		return
	}
	return error('unsupported print token {${token}}')
}

fn normalize_print_page_ranges(ranges []PrintPageRange) []PrintPageRange {
	if ranges.len == 0 {
		return []PrintPageRange{}
	}
	mut out := ranges.clone()
	out.sort_with_compare(fn (a &PrintPageRange, b &PrintPageRange) int {
		if a.from < b.from {
			return -1
		}
		if a.from > b.from {
			return 1
		}
		if a.to < b.to {
			return -1
		}
		if a.to > b.to {
			return 1
		}
		return 0
	})
	mut merged := []PrintPageRange{}
	mut current := out[0]
	for idx in 1 .. out.len {
		range := out[idx]
		if range.from <= current.to + 1 {
			if range.to > current.to {
				current = PrintPageRange{
					from: current.from
					to:   range.to
				}
			}
			continue
		}
		merged << current
		current = range
	}
	merged << current
	return merged
}
