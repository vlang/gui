module gui

import net.http
import stbi
import time

struct MathFetchResult {
	res     http.Response
	err_msg string
	is_err  bool
}

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

fn fetch_math_async(mut window Window, latex string, hash i64, dpi int, fg_color Color) {
	spawn fn [mut window, latex, hash, dpi, fg_color] () {
		ch := chan MathFetchResult{}

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

		spawn fn [url, ch] () {
			result := http.fetch(
				method: .get
				url:    url
			) or {
				ch <- MathFetchResult{
					err_msg: err.msg()
					is_err:  true
				}
				return
			}
			ch <- MathFetchResult{
				res:    result
				is_err: false
			}
		}()

		// Wait with 15s timeout
		mut fetch_res := MathFetchResult{
			is_err:  true
			err_msg: 'Request timed out'
		}

		select {
			res := <-ch {
				fetch_res = res
			}
			15 * time.second {
				// use default timeout value
			}
		}

		if fetch_res.is_err {
			err_msg := fetch_res.err_msg
			window.queue_command(fn [hash, err_msg] (mut w Window) {
				w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state: .error
					error: err_msg
				})
				w.update_window()
			})
			return
		}

		result := fetch_res.res
		if result.status_code == 200 {
			// Reject oversized responses (>10MB)
			if result.body.len > 10 * 1024 * 1024 {
				body_len := result.body.len
				window.queue_command(fn [hash, body_len] (mut w Window) {
					w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
						state: .error
						error: 'Response too large (>${body_len / 1024 / 1024}MB)'
					})
					w.update_window()
				})
				return
			}
			png_bytes := result.body.bytes()
			img := stbi.load_from_memory(png_bytes.data, png_bytes.len) or {
				err_msg := err.msg()
				window.queue_command(fn [hash, err_msg] (mut w Window) {
					w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
						state: .error
						error: 'Failed to decode PNG: ${err_msg}'
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
				window.queue_command(fn [hash, err_msg] (mut w Window) {
					w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
						state: .error
						error: 'Failed to write temp file: ${err_msg}'
					})
					w.update_window()
				})
				return
			}
			img_w := f32(img.width)
			img_h := f32(img.height)
			img_dpi := f32(dpi)
			img.free()
			window.queue_command(fn [hash, tmp_path, img_w, img_h, img_dpi] (mut w Window) {
				w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state:    .ready
					png_path: tmp_path
					width:    img_w
					height:   img_h
					dpi:      img_dpi
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
			window.queue_command(fn [hash, status_code, body_preview] (mut w Window) {
				w.view_state.diagram_cache.set(hash, DiagramCacheEntry{
					state: .error
					error: 'HTTP ${status_code}: ${body_preview}'
				})
				w.update_window()
			})
		}
	}()
}
