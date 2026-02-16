module gui

import net.http
import os
import stbi

// math_cache_hash computes a cache key for a math expression ID.
fn math_cache_hash(math_id string) i64 {
	return i64((u64(math_id.hash()) << 32) | u64(math_id.len))
}

// fetch_math_async fetches a LaTeX math image from codecogs in
// a background thread. Uses PNG format. Updates diagram_cache
// with result and triggers window refresh.
//
// PRIVACY NOTE: LaTeX source is sent to external third-party
// API (latex.codecogs.com) for rendering. This may leak
// document content to the service provider.
// Use MarkdownCfg.disable_external_apis to disable this.
//
// sanitize_latex strips dangerous TeX commands that could
// enable shell escape or file access on the remote renderer.
fn sanitize_latex(s string) string {
	// Block shell-escape and file-access commands.
	// Loop until stable: single-pass replace can miss
	// nested payloads like `\inp\inputut` that reassemble
	// into `\input` after one removal pass.
	blocked := [
		'\\write18',
		'\\input',
		'\\include',
		'\\openin',
		'\\openout',
		'\\read',
		'\\write',
		'\\csname',
		'\\immediate',
		'\\catcode',
		'\\special',
		'\\outer',
		'\\def',
		'\\edef',
		'\\gdef',
		'\\xdef',
		'\\let',
		'\\futurelet',
		'\\aliasfont',
		'\\batchmode',
		'\\copy',
		'\\count',
		'\\countdef',
		'\\dimen',
		'\\dimendef',
		'\\errorstopmode',
		'\\font',
		'\\fontdimen',
		'\\halign',
		'\\hrule',
		'\\hyphenation',
		'\\if',
		'\\ifcase',
		'\\ifcat',
		'\\ifdim',
		'\\ifeof',
		'\\iffalse',
		'\\ifhbox',
		'\\ifhmode',
		'\\ifinner',
		'\\ifmmode',
		'\\ifnum',
		'\\ifodd',
		'\\iftrue',
		'\\ifvbox',
		'\\ifvmode',
		'\\ifvoid',
		'\\ifx',
		'\\jobname',
		'\\kern',
		'\\long',
		'\\mag',
		'\\mark',
		'\\meaning',
		'\\messages',
		'\\newcount',
		'\\newdimen',
		'\\newif',
		'\\newread',
		'\\newskip',
		'\\newwrite',
		'\\noexpand',
		'\\nonstopmode',
		'\\output',
		'\\pausing',
		'\\primitive',
		'\\readline',
		'\\scrollmode',
		'\\setbox',
		'\\show',
		'\\showbox',
		'\\showlists',
		'\\showthe',
		'\\skip',
		'\\skipdef',
		'\\the',
		'\\toks',
		'\\toksdef',
		'\\tracingall',
		'\\tracingcommands',
		'\\tracinglostchars',
		'\\tracingmacros',
		'\\tracingonline',
		'\\tracingoutput',
		'\\tracingpages',
		'\\tracingparagraphs',
		'\\tracingrestores',
		'\\tracingstats',
		'\\vcenter',
		'\\valign',
		'\\vrule',
	]
	if s.len > max_latex_source_len {
		return ''
	}
	mut result := s
	for _ in 0 .. 10 {
		prev := result
		for cmd in blocked {
			result = result.replace(cmd, '')
		}
		if result == prev {
			break
		}
	}
	return result
}

fn fetch_math_http(url string) !http.Response {
	mut req := http.prepare(
		method: .get
		url:    url
	)!
	req.read_timeout = i64(diagram_fetch_timeout)
	req.write_timeout = i64(diagram_fetch_timeout)
	return req.do()!
}

fn fetch_math_async(mut window Window, latex string, hash i64, request_id u64, dpi int, fg_color Color) {
	spawn fn [mut window, latex, hash, request_id, dpi, fg_color] () {
		safe_latex := sanitize_latex(latex)

		// Build codecogs URL with DPI and optional color prefix.
		// Use named color to avoid bracket syntax that breaks
		// when percent-encoded.
		dpi_str := '${dpi}'
		lum := 0.299 * f64(fg_color.r) + 0.587 * f64(fg_color.g) + 0.114 * f64(fg_color.b)
		color_cmd := if lum > 128.0 { '\\color{white}' } else { '' }
		prefix := '\\dpi{${dpi_str}}${color_cmd}'
		// Replace spaces with {} (empty group) — acts as
		// command terminator without visible output. V's
		// http library re-encodes %20 as + which codecogs
		// renders as literal plus signs.
		encoded := (prefix + safe_latex).replace(' ', '{}').replace('#', '%23').replace('&',
			'%26')
		url := 'https://latex.codecogs.com/png.image?${encoded}'
		result := fetch_math_http(url) or {
			err_msg := err.msg()
			window.queue_command(fn [hash, request_id, err_msg] (mut w Window) {
				if !diagram_cache_should_apply_result(&w.view_state.diagram_cache, hash,
					request_id) {
					return
				}
				w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state:      .error
					error:      err_msg
					request_id: request_id
				})
				w.update_window()
			})
			return
		}
		if result.status_code == 200 {
			// Reject oversized responses (>10MB)
			if result.body.len > 10 * 1024 * 1024 {
				body_len := result.body.len
				window.queue_command(fn [hash, request_id, body_len] (mut w Window) {
					if !diagram_cache_should_apply_result(&w.view_state.diagram_cache,
						hash, request_id) {
						return
					}
					w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
						state:      .error
						error:      'Response too large (>${body_len / 1024 / 1024}MB)'
						request_id: request_id
					})
					w.update_window()
				})
				return
			}
			png_bytes := result.body.bytes()
			img := stbi.load_from_memory(png_bytes.data, png_bytes.len) or {
				err_msg := err.msg()
				window.queue_command(fn [hash, request_id, err_msg] (mut w Window) {
					if !diagram_cache_should_apply_result(&w.view_state.diagram_cache,
						hash, request_id) {
						return
					}
					w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
						state:      .error
						error:      'Failed to decode PNG: ${err_msg}'
						request_id: request_id
					})
					w.update_window()
				})
				return
			}

			// No transparent fill — keep PNG alpha for blending
			// with any background color

			tmp_path := write_stbi_temp('math', hash, img) or {
				img.free()
				err_msg := err.msg()
				window.queue_command(fn [hash, request_id, err_msg] (mut w Window) {
					if !diagram_cache_should_apply_result(&w.view_state.diagram_cache,
						hash, request_id) {
						return
					}
					w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
						state:      .error
						error:      'Failed to write temp file: ${err_msg}'
						request_id: request_id
					})
					w.update_window()
				})
				return
			}
			img_w := f32(img.width)
			img_h := f32(img.height)
			img_dpi := f32(dpi)
			img.free()
			window.queue_command(fn [hash, request_id, tmp_path, img_w, img_h, img_dpi] (mut w Window) {
				if !diagram_cache_should_apply_result(&w.view_state.diagram_cache, hash,
					request_id) {
					os.rm(tmp_path) or {}
					return
				}
				w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state:      .ready
					png_path:   tmp_path
					width:      img_w
					height:     img_h
					dpi:        img_dpi
					request_id: request_id
				})
				// No markdown_cache clear needed: parsed blocks
				// don't change; RTF reads math dims from
				// diagram_cache at render time. update_window
				// triggers view rebuild picking up new
				// dimensions via to_vglyph_rich_text_with_math.
				w.update_window()
			})
		} else {
			body_preview := if result.body.len > 200 {
				result.body[..200] + '...'
			} else {
				result.body
			}
			status_code := result.status_code
			window.queue_command(fn [hash, request_id, status_code, body_preview] (mut w Window) {
				if !diagram_cache_should_apply_result(&w.view_state.diagram_cache, hash,
					request_id) {
					return
				}
				w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state:      .error
					error:      'HTTP ${status_code}: ${body_preview}'
					request_id: request_id
				})
				w.update_window()
			})
		}
	}()
}
