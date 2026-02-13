module gui

// rich_text.v defines rich text types for mixed-style paragraphs.
// These types wrap vglyph's RichText/StyleRun internally while providing
// a gui-native API.
import vglyph
import math

// RichTextRun is a styled segment of text within a RichText block.
@[minify]
pub struct RichTextRun {
pub:
	text       string
	style      TextStyle
	link       string // URL for hyperlinks (empty if not a link)
	tooltip    string // tooltip text for abbreviations (empty if not an abbreviation)
	math_id    string // cache key for inline math
	math_latex string // raw LaTeX source for inline math fetch
}

// RichText contains runs of styled text for mixed-style paragraphs.
pub struct RichText {
pub mut:
	runs []RichTextRun
}

// rich_run creates a styled text run.
pub fn rich_run(text string, style TextStyle) RichTextRun {
	return RichTextRun{
		text:  text
		style: style
	}
}

// rich_link creates a hyperlink run with underline styling.
pub fn rich_link(text string, url string, style TextStyle) RichTextRun {
	return RichTextRun{
		text:  text
		link:  url
		style: TextStyle{
			...style
			color:     gui_theme.color_select
			underline: true
		}
	}
}

// rich_br creates a line break run.
pub fn rich_br() RichTextRun {
	return RichTextRun{
		text:  '\n'
		style: gui_theme.n3
	}
}

// rich_abbr creates an abbreviation run with tooltip and styled text.
pub fn rich_abbr(text string, expansion string, style TextStyle) RichTextRun {
	return RichTextRun{
		text:    text
		tooltip: expansion
		style:   TextStyle{
			...style
			typeface: .bold
		}
	}
}

// rich_footnote creates a footnote marker with tooltip showing definition.
pub fn rich_footnote(id string, content string, base_style TextStyle) RichTextRun {
	return RichTextRun{
		text:    '\xE2\x80\x89[${id}]' // thin space
		tooltip: content
		style:   TextStyle{
			...base_style
			size: base_style.size * 0.7
		}
	}
}

// to_vglyph_rich_text converts a RichText to vglyph.RichText for layout.
fn (rt RichText) to_vglyph_rich_text() vglyph.RichText {
	return rt.to_vglyph_rich_text_with_math(unsafe { nil })
}

// to_vglyph_rich_text_with_math converts RichText to vglyph.RichText,
// emitting InlineObject for math runs when cache has dimensions.
fn (rt RichText) to_vglyph_rich_text_with_math(cache &BoundedDiagramCache) vglyph.RichText {
	mut vg_runs := []vglyph.StyleRun{cap: rt.runs.len}
	for run in rt.runs {
		if run.math_id != '' && unsafe { cache != nil } {
			hash := math_cache_hash(run.math_id)
			if entry := cache.get(hash) {
				if entry.state == .ready && entry.width > 0 {
					// Scale pixel dims to points, then match
					// surrounding text size
					edpi := if entry.dpi > 0 { entry.dpi } else { f32(200.0) }
					scale := (f32(72.0) / edpi) * (run.style.size / f32(6.0))
					vg_runs << vglyph.StyleRun{
						text:  run.text
						style: vglyph.TextStyle{
							...run.style.to_vglyph_style()
							object: &vglyph.InlineObject{
								id:     run.math_id
								width:  entry.width * scale
								height: entry.height * scale
								offset: 0
							}
						}
					}
					continue
				}
			}
			// Loading/error: show raw LaTeX as fallback
			vg_runs << vglyph.StyleRun{
				text:  run.math_latex
				style: run.style.to_vglyph_style()
			}
			continue
		}
		vg_runs << vglyph.StyleRun{
			text:  run.text
			style: run.style.to_vglyph_style()
		}
	}
	return vglyph.RichText{
		runs: vg_runs
	}
}

// to_vglyph_style converts a gui TextStyle to a vglyph.TextStyle.
pub fn (ts TextStyle) to_vglyph_style() vglyph.TextStyle {
	return vglyph.TextStyle{
		font_name:     ts.family
		color:         ts.color.to_gx_color()
		bg_color:      ts.bg_color.to_gx_color()
		size:          ts.size
		features:      ts.features
		underline:     ts.underline
		strikethrough: ts.strikethrough
		typeface:      ts.typeface
	}
}

const affine_transform_epsilon = f32(0.00001)

@[inline]
fn affine_equal(a f32, b f32) bool {
	return f32(math.abs(a - b)) <= affine_transform_epsilon
}

fn affine_transforms_equal(a vglyph.AffineTransform, b vglyph.AffineTransform) bool {
	return affine_equal(a.xx, b.xx) && affine_equal(a.xy, b.xy) && affine_equal(a.yx, b.yx)
		&& affine_equal(a.yy, b.yy) && affine_equal(a.x0, b.x0) && affine_equal(a.y0, b.y0)
}

// uniform_text_transform returns a transform only when all runs have the same one.
pub fn (rt RichText) uniform_text_transform() ?vglyph.AffineTransform {
	if rt.runs.len == 0 {
		return none
	}
	mut saw_unset := false
	mut saw_set := false
	mut transform := vglyph.AffineTransform{}
	for run in rt.runs {
		if !run.style.has_text_transform() {
			saw_unset = true
			continue
		}
		run_transform := run.style.effective_text_transform()
		if !saw_set {
			transform = run_transform
			saw_set = true
			continue
		}
		if !affine_transforms_equal(transform, run_transform) {
			return none
		}
	}
	if !saw_set || saw_unset {
		return none
	}
	return transform
}

// has_mixed_text_transform returns true when run transforms are inconsistent.
pub fn (rt RichText) has_mixed_text_transform() bool {
	if rt.runs.len == 0 {
		return false
	}
	mut saw_unset := false
	mut saw_set := false
	mut transform := vglyph.AffineTransform{}
	for run in rt.runs {
		if !run.style.has_text_transform() {
			saw_unset = true
			continue
		}
		run_transform := run.style.effective_text_transform()
		if !saw_set {
			transform = run_transform
			saw_set = true
			continue
		}
		if !affine_transforms_equal(transform, run_transform) {
			return true
		}
	}
	return saw_set && saw_unset
}
