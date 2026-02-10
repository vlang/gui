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

pub enum NativePrintContentKind as u8 {
	current_view_pdf
	prepared_pdf_path
}

pub struct NativePrintContent {
pub:
	kind     NativePrintContentKind = .current_view_pdf
	pdf_path string
}

pub enum NativePrintStatus as u8 {
	ok
	cancel
	error
}

pub struct NativePrintResult {
pub:
	status        NativePrintStatus
	error_code    string
	error_message string
	pdf_path      string
}

pub struct NativePrintDialogCfg {
pub:
	title       string
	job_name    string
	paper       PaperSize        = .a4
	orientation PrintOrientation = .portrait
	margins     PrintMargins     = default_print_margins()
	content     NativePrintContent
	on_done     fn (NativePrintResult, mut Window) = fn (_ NativePrintResult, mut _ Window) {}
}

pub enum PdfExportStatus as u8 {
	ok
	error
}

pub struct PdfExportCfg {
pub:
	path          string
	title         string
	job_name      string
	paper         PaperSize        = .a4
	orientation   PrintOrientation = .portrait
	margins       PrintMargins     = default_print_margins()
	fit_to_page   bool             = true
	source_width  f32
	source_height f32
}

pub struct PdfExportResult {
pub:
	status        PdfExportStatus
	path          string
	error_code    string
	error_message string
}

pub fn (result PdfExportResult) is_ok() bool {
	return result.status == .ok
}

fn native_print_error_result(code string, message string) NativePrintResult {
	return NativePrintResult{
		status:        .error
		error_code:    code
		error_message: message
	}
}

fn native_print_cancel_result() NativePrintResult {
	return NativePrintResult{
		status: .cancel
	}
}

fn native_print_ok_result(path string) NativePrintResult {
	return NativePrintResult{
		status:   .ok
		pdf_path: path
	}
}

fn pdf_export_error_result(path string, code string, message string) PdfExportResult {
	return PdfExportResult{
		status:        .error
		path:          path
		error_code:    code
		error_message: message
	}
}

fn pdf_export_ok_result(path string) PdfExportResult {
	return PdfExportResult{
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

fn validate_pdf_export_cfg(cfg PdfExportCfg) ! {
	if cfg.path.trim_space().len == 0 {
		return error('pdf path is required')
	}
	page_width, page_height := print_page_size(cfg.paper, cfg.orientation)
	validate_print_margins(page_width, page_height, cfg.margins)!
}

fn validate_native_print_cfg(cfg NativePrintDialogCfg) ! {
	page_width, page_height := print_page_size(cfg.paper, cfg.orientation)
	validate_print_margins(page_width, page_height, cfg.margins)!
	match cfg.content.kind {
		.current_view_pdf {}
		.prepared_pdf_path {
			if cfg.content.pdf_path.trim_space().len == 0 {
				return error('pdf_path is required for prepared_pdf_path content')
			}
		}
	}
}
