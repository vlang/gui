// Data grid: CSV/TSV/PDF/XLSX import and export.
module gui

import compress.szip
import encoding.csv
import math
import os
import strconv
import strings
import time

// grid_data_from_csv parses CSV data into data-grid columns and rows.
//
// - First CSV row becomes column headers.
// - Blank headers are replaced with `Column N`.
// - Duplicate header ids are suffixed (`name`, `name_2`, ...).
// - Row ids are generated as 1-based strings in CSV order.
pub fn grid_data_from_csv(data string) !GridCsvData {
	if data.trim_space().len == 0 {
		return error('csv data is required')
	}
	mut source := data
	if !source.ends_with('\n') {
		source += '\n'
	}
	mut parser := csv.csv_reader_from_string(source) or {
		return error('failed to create CSV parser: ${err.msg()}')
	}
	row_count := parser.rows_count() or {
		return error('failed to get CSV row count: ${err.msg()}')
	}
	if row_count <= 0 {
		return error('csv data contains no rows')
	}
	mut parsed_rows := [][]string{cap: int(row_count)}
	mut max_cols := 0
	for row_idx in 0 .. int(row_count) {
		fields := parser.get_row(row_idx) or {
			return error('failed to parse CSV row ${row_idx + 1}: ${err.msg()}')
		}
		decoded := fields.map(data_grid_csv_unquote(it))
		if decoded.len > max_cols {
			max_cols = decoded.len
		}
		parsed_rows << decoded
	}
	if max_cols <= 0 {
		return error('csv header row is empty')
	}
	columns := data_grid_csv_columns(parsed_rows[0], max_cols)
	mut rows := []GridRow{cap: int_max(0, parsed_rows.len - 1)}
	for row_idx in 1 .. parsed_rows.len {
		fields := parsed_rows[row_idx]
		mut cells := map[string]string{}
		for col_idx, col in columns {
			cells[col.id] = if col_idx < fields.len { fields[col_idx] } else { '' }
		}
		rows << GridRow{
			id:    '${row_idx}'
			cells: cells
		}
	}
	return GridCsvData{
		columns: columns
		rows:    rows
	}
}

// grid_rows_to_tsv converts rows to tab-separated text with a header row.
pub fn grid_rows_to_tsv(columns []GridColumnCfg, rows []GridRow) string {
	return grid_rows_to_tsv_with_cfg(columns, rows, GridExportCfg{})
}

// grid_rows_to_tsv_with_cfg converts rows to tab-separated text with a header row.
pub fn grid_rows_to_tsv_with_cfg(columns []GridColumnCfg, rows []GridRow, export_cfg GridExportCfg) string {
	if columns.len == 0 {
		return ''
	}
	mut lines := []string{cap: rows.len + 1}
	lines << columns.map(data_grid_tsv_escape(data_grid_export_text(it.title, export_cfg))).join('\t')
	for row in rows {
		mut fields := []string{cap: columns.len}
		for col in columns {
			fields << data_grid_tsv_escape(data_grid_export_text(row.cells[col.id] or { '' },
				export_cfg))
		}
		lines << fields.join('\t')
	}
	return lines.join('\n')
}

// grid_rows_to_csv converts rows to comma-separated text with a header row.
pub fn grid_rows_to_csv(columns []GridColumnCfg, rows []GridRow) string {
	return grid_rows_to_csv_with_cfg(columns, rows, GridExportCfg{})
}

// grid_rows_to_csv_with_cfg converts rows to comma-separated text with a header row.
pub fn grid_rows_to_csv_with_cfg(columns []GridColumnCfg, rows []GridRow, export_cfg GridExportCfg) string {
	if columns.len == 0 {
		return ''
	}
	mut lines := []string{cap: rows.len + 1}
	lines << columns.map(data_grid_csv_escape(data_grid_export_text(it.title, export_cfg))).join(',')
	for row in rows {
		mut fields := []string{cap: columns.len}
		for col in columns {
			fields << data_grid_csv_escape(data_grid_export_text(row.cells[col.id] or { '' },
				export_cfg))
		}
		lines << fields.join(',')
	}
	return lines.join('\n')
}

// grid_rows_to_pdf converts rows to a simple single-page PDF table-like export.
pub fn grid_rows_to_pdf(columns []GridColumnCfg, rows []GridRow) string {
	if columns.len == 0 {
		return ''
	}
	lines := data_grid_pdf_lines(columns, rows)
	return data_grid_pdf_document(lines)
}

// grid_rows_to_pdf_file writes a simple single-page PDF table-like export.
pub fn grid_rows_to_pdf_file(path string, columns []GridColumnCfg, rows []GridRow) ! {
	target := path.trim_space()
	if target.len == 0 {
		return error('pdf path is required')
	}
	dir := os.dir(target)
	if dir.len > 0 && dir != '.' {
		os.mkdir_all(dir)!
	}
	payload := grid_rows_to_pdf(columns, rows)
	if payload.len == 0 {
		return error('no columns to export')
	}
	os.write_file(target, payload)!
}

// grid_rows_to_xlsx creates a minimal XLSX workbook and returns the file bytes.
pub fn grid_rows_to_xlsx(columns []GridColumnCfg, rows []GridRow) ![]u8 {
	return grid_rows_to_xlsx_with_cfg(columns, rows, GridExportCfg{})
}

// grid_rows_to_xlsx_with_cfg creates a minimal XLSX workbook and returns the file bytes.
pub fn grid_rows_to_xlsx_with_cfg(columns []GridColumnCfg, rows []GridRow, export_cfg GridExportCfg) ![]u8 {
	tmp_path := os.join_path(os.temp_dir(), 'gui_data_grid_${time.now().unix_micro()}.xlsx')
	defer {
		os.rm(tmp_path) or {}
	}
	grid_rows_to_xlsx_file_with_cfg(tmp_path, columns, rows, export_cfg)!
	return os.read_bytes(tmp_path)!
}

// grid_rows_to_xlsx_file writes a minimal XLSX workbook to `path`.
pub fn grid_rows_to_xlsx_file(path string, columns []GridColumnCfg, rows []GridRow) ! {
	grid_rows_to_xlsx_file_with_cfg(path, columns, rows, GridExportCfg{})!
}

// grid_rows_to_xlsx_file_with_cfg writes a minimal XLSX workbook to `path`.
pub fn grid_rows_to_xlsx_file_with_cfg(path string, columns []GridColumnCfg, rows []GridRow, export_cfg GridExportCfg) ! {
	target := path.trim_space()
	if target.len == 0 {
		return error('xlsx path is required')
	}
	dir := os.dir(target)
	if dir.len > 0 && dir != '.' {
		os.mkdir_all(dir)!
	}
	mut zip := szip.open(target, .default_compression, .write)!
	defer {
		zip.close()
	}
	data_grid_xlsx_write_entry(mut zip, '[Content_Types].xml', data_grid_xlsx_content_types_xml())!
	data_grid_xlsx_write_entry(mut zip, '_rels/.rels', data_grid_xlsx_root_rels_xml())!
	data_grid_xlsx_write_entry(mut zip, 'xl/workbook.xml', data_grid_xlsx_workbook_xml())!
	data_grid_xlsx_write_entry(mut zip, 'xl/_rels/workbook.xml.rels', data_grid_xlsx_workbook_rels_xml())!
	data_grid_xlsx_write_entry(mut zip, 'xl/worksheets/sheet1.xml', data_grid_xlsx_sheet_xml(columns,
		rows, export_cfg))!
}

fn data_grid_pdf_lines(columns []GridColumnCfg, rows []GridRow) []string {
	mut lines := []string{cap: rows.len + 1}
	mut header := []string{cap: columns.len}
	for col in columns {
		header << data_grid_pdf_clip_text(col.title)
	}
	lines << header.join(' | ')
	for row in rows {
		lines << data_grid_pdf_line(columns, row)
	}
	return lines
}

fn data_grid_pdf_line(columns []GridColumnCfg, row GridRow) string {
	mut parts := []string{cap: columns.len}
	for col in columns {
		value := row.cells[col.id] or { '' }
		parts << data_grid_pdf_clip_text(value)
	}
	return parts.join(' | ')
}

fn data_grid_pdf_clip_text(value string) string {
	runes := value.runes()
	if runes.len <= data_grid_pdf_max_line_chars {
		return value
	}
	return runes[..data_grid_pdf_max_line_chars - 3].string() + '...'
}

// Generates a multi-page PDF. Computes max lines per page from dimensions.
// Splitting lines into chunks and creating catalog → pages → [page, content]*
// sequence for a complete export.
fn data_grid_pdf_document(lines []string) string {
	if lines.len == 0 {
		return ''
	}
	mut max_lines := int((data_grid_pdf_page_height - data_grid_pdf_margin * 2) / data_grid_pdf_line_height)
	if max_lines < 1 {
		max_lines = 1
	}

	mut pages := [][]string{}
	for i := 0; i < lines.len; i += max_lines {
		end := if i + max_lines > lines.len { lines.len } else { i + max_lines }
		pages << lines[i..end].clone()
	}

	mut objects := []string{cap: 2 + pages.len * 2}
	objects << '<< /Type /Catalog /Pages 2 0 R >>'

	mut kids := []string{cap: pages.len}
	for i in 0 .. pages.len {
		page_obj_idx := 3 + i * 2
		kids << '${page_obj_idx} 0 R'
	}
	objects << '<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages.len} >>'

	for i, page_lines in pages {
		mut stream := strings.new_builder(2048)
		stream.writeln('BT')
		stream.writeln('/F1 ${pdf_num(data_grid_pdf_font_size)} Tf')
		stream.writeln('${pdf_num(data_grid_pdf_line_height)} TL')
		stream.writeln('${pdf_num(data_grid_pdf_margin)} ${pdf_num(data_grid_pdf_page_height - data_grid_pdf_margin)} Td')
		for j, line in page_lines {
			if j > 0 {
				stream.writeln('T*')
			}
			stream.writeln('(${pdf_escape_text(line)}) Tj')
		}
		stream.writeln('ET')
		content := stream.bytestr()

		content_obj_idx := 4 + i * 2
		page_obj := '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pdf_num(data_grid_pdf_page_width)} ${pdf_num(data_grid_pdf_page_height)}] /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Courier >> >> >> /Contents ${content_obj_idx} 0 R >>'
		content_obj := '<< /Length ${content.len} >>\nstream\n${content}endstream'

		objects << page_obj
		objects << content_obj
	}

	return pdf_encode(objects)
}

fn data_grid_xlsx_write_entry(mut zip szip.Zip, name string, content string) ! {
	zip.open_entry(name)!
	zip.write_entry(content.bytes())!
	zip.close_entry()
}

fn data_grid_xlsx_content_types_xml() string {
	return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
		'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
		'<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
		'<Default Extension="xml" ContentType="application/xml"/>' +
		'<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
		'<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
		'</Types>'
}

fn data_grid_xlsx_root_rels_xml() string {
	return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
		'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
		'<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
		'</Relationships>'
}

fn data_grid_xlsx_workbook_xml() string {
	return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
		'<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
		'<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>'
}

fn data_grid_xlsx_workbook_rels_xml() string {
	return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' +
		'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
		'<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
		'</Relationships>'
}

fn data_grid_xlsx_sheet_xml(columns []GridColumnCfg, rows []GridRow, export_cfg GridExportCfg) string {
	cells_per_row := int_max(1, columns.len)
	mut out := strings.new_builder(1024 + (rows.len + 1) * cells_per_row * 56)
	out.write_string('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
	out.write_string('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>')
	if columns.len > 0 {
		out.write_string('<row r="1">')
		for col_idx, col in columns {
			cell_ref := data_grid_xlsx_cell_ref(col_idx, 1)
			out.write_string(data_grid_xlsx_string_cell_xml(cell_ref, data_grid_export_text(col.title,
				export_cfg)))
		}
		out.write_string('</row>')
	}
	for row_idx, row in rows {
		xml_row := row_idx + 2
		out.write_string('<row r="${xml_row}">')
		for col_idx, col in columns {
			cell_ref := data_grid_xlsx_cell_ref(col_idx, xml_row)
			value := data_grid_export_text(row.cells[col.id] or { '' }, export_cfg)
			out.write_string(data_grid_xlsx_cell_xml(cell_ref, value, export_cfg))
		}
		out.write_string('</row>')
	}
	out.write_string('</sheetData></worksheet>')
	return out.bytestr()
}

fn data_grid_xlsx_cell_xml(cell_ref string, value string, export_cfg GridExportCfg) string {
	if !export_cfg.xlsx_auto_type {
		return data_grid_xlsx_string_cell_xml(cell_ref, value)
	}
	trimmed := value.trim_space()
	if data_grid_xlsx_is_bool(trimmed) {
		return '<c r="${cell_ref}" t="b"><v>${data_grid_xlsx_bool_value(trimmed)}</v></c>'
	}
	if data_grid_xlsx_is_number(trimmed) && data_grid_xlsx_safe_number(trimmed) {
		return '<c r="${cell_ref}"><v>${trimmed}</v></c>'
	}
	return data_grid_xlsx_string_cell_xml(cell_ref, value)
}

fn data_grid_xlsx_string_cell_xml(cell_ref string, value string) string {
	escaped := data_grid_xlsx_escape(value)
	if data_grid_xlsx_preserve_spaces(value) {
		return '<c r="${cell_ref}" t="inlineStr"><is><t xml:space="preserve">${escaped}</t></is></c>'
	}
	return '<c r="${cell_ref}" t="inlineStr"><is><t>${escaped}</t></is></c>'
}

fn data_grid_xlsx_escape(value string) string {
	return value.replace_each([
		'&',
		'&amp;',
		'<',
		'&lt;',
		'>',
		'&gt;',
		'"',
		'&quot;',
		"'",
		'&apos;',
		'\r',
		'',
		'\n',
		'&#10;',
		'\t',
		'&#9;',
	])
}

fn data_grid_xlsx_preserve_spaces(value string) bool {
	return value.len > 0 && (value[0] == ` ` || value[value.len - 1] == ` `)
}

fn data_grid_xlsx_is_bool(value string) bool {
	if value.len == 0 {
		return false
	}
	return value.to_lower() in ['true', 'false', 'yes', 'no', 'on', 'off']
}

fn data_grid_xlsx_bool_value(value string) string {
	return if value.to_lower() in ['true', 'yes', 'on'] { '1' } else { '0' }
}

fn data_grid_xlsx_is_number(value string) bool {
	if value.len == 0 {
		return false
	}
	n := strconv.atof64(value) or { return false }
	return !math.is_nan(n) && !math.is_inf(n, 0)
}

// Guards against XML injection when emitting numeric
// values as raw <v>...</v> content in XLSX. Only allows
// digits, decimal point, sign, and exponent chars.
fn data_grid_xlsx_safe_number(value string) bool {
	for c in value {
		match c {
			`0`...`9`, `.`, `+`, `-`, `e`, `E` {}
			else { return false }
		}
	}
	return true
}

fn data_grid_xlsx_cell_ref(col_idx int, row_idx int) string {
	return '${data_grid_xlsx_col_ref(col_idx)}${row_idx}'
}

// Converts 0-based column index to Excel-style letter
// reference (0→A, 25→Z, 26→AA). Uses base-26 with
// 1-based digit values (A=1 not A=0).
fn data_grid_xlsx_col_ref(col_idx int) string {
	if col_idx < 0 {
		return 'A'
	}
	mut n := col_idx + 1
	mut label := ''
	for n > 0 {
		rem := (n - 1) % 26
		label = rune(`A` + rem).str() + label
		n = (n - 1) / 26
	}
	return label
}

fn data_grid_export_text(value string, export_cfg GridExportCfg) string {
	if !export_cfg.sanitize_spreadsheet_formulas {
		return value
	}
	return data_grid_spreadsheet_safe_text(value)
}

fn data_grid_spreadsheet_safe_text(value string) string {
	if value.len == 0 {
		return value
	}
	mut first := 0
	for first < value.len && (value[first] == ` ` || value[first] == `\t`) {
		first++
	}
	if first >= value.len {
		return value
	}
	if value[first] in [`=`, `+`, `-`, `@`] {
		return "'" + value
	}
	return value
}

fn data_grid_tsv_escape(value string) string {
	if value.len == 0 {
		return ''
	}
	needs_quotes := value.contains('\t') || value.contains('"') || value.contains('\n')
		|| value.contains('\r')
	if !needs_quotes {
		return value
	}
	return '"' + value.replace('"', '""') + '"'
}

fn data_grid_csv_escape(value string) string {
	if value.len == 0 {
		return ''
	}
	needs_quotes := value.contains(',') || value.contains('"') || value.contains('\n')
		|| value.contains('\r') || value.contains('\t')
	if !needs_quotes {
		return value
	}
	escaped := value.replace('"', '""')
	return '"${escaped}"'
}

fn data_grid_csv_unquote(value string) string {
	if value.len >= 2 && value[0] == `"` && value[value.len - 1] == `"` {
		inner := value[1..value.len - 1]
		return inner.replace('""', '"')
	}
	return value
}

fn data_grid_csv_columns(header []string, max_cols int) []GridColumnCfg {
	mut columns := []GridColumnCfg{cap: max_cols}
	mut used_ids := map[string]bool{}
	for idx in 0 .. max_cols {
		header_value := if idx < header.len {
			data_grid_csv_strip_bom(header[idx], idx)
		} else {
			''
		}
		title := data_grid_csv_column_title(header_value, idx)
		base_id := if header_value.trim_space().len == 0 {
			'col_${idx + 1}'
		} else {
			data_grid_csv_column_id(title, idx)
		}
		col_id := data_grid_csv_unique_id(base_id, mut used_ids)
		columns << GridColumnCfg{
			id:    col_id
			title: title
		}
	}
	return columns
}

fn data_grid_csv_column_title(value string, idx int) string {
	title := value.trim_space()
	if title.len > 0 {
		return title
	}
	return 'Column ${idx + 1}'
}

fn data_grid_csv_column_id(title string, idx int) string {
	lower := title.to_lower()
	mut out := []u8{cap: lower.len}
	mut last_is_underscore := false
	for ch in lower.bytes() {
		is_alpha := ch >= `a` && ch <= `z`
		is_digit := ch >= `0` && ch <= `9`
		if is_alpha || is_digit {
			out << ch
			last_is_underscore = false
			continue
		}
		if !last_is_underscore {
			out << `_`
			last_is_underscore = true
		}
	}
	mut id := data_grid_trim_char_edges(out.bytestr(), `_`)
	if id.len == 0 {
		id = 'col_${idx + 1}'
	}
	return id
}

fn data_grid_trim_char_edges(value string, ch u8) string {
	if value.len == 0 {
		return ''
	}
	mut start := 0
	mut end := value.len
	for start < end && value[start] == ch {
		start++
	}
	for end > start && value[end - 1] == ch {
		end--
	}
	return value[start..end]
}

fn data_grid_csv_unique_id(base string, mut used map[string]bool) string {
	if !used[base] {
		used[base] = true
		return base
	}
	mut suffix := 2
	for {
		candidate := '${base}_${suffix}'
		if !used[candidate] {
			used[candidate] = true
			return candidate
		}
		suffix++
	}
	return base // unreachable; V requires return after for{}
}

fn data_grid_csv_strip_bom(value string, idx int) string {
	if idx != 0 || value.len < 3 {
		return value
	}
	if value[0] == u8(0xef) && value[1] == u8(0xbb) && value[2] == u8(0xbf) {
		return value[3..]
	}
	return value
}
