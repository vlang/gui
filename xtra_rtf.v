module gui

// rich_text.v defines rich text types for mixed-style paragraphs.
// These types wrap vglyph's RichText/StyleRun internally while providing
// a gui-native API.
import vglyph

// RichTextRun is a styled segment of text within a RichText block.
@[minify]
pub struct RichTextRun {
pub:
	text    string
	style   TextStyle
	link    string // URL for hyperlinks (empty if not a link)
	tooltip string // tooltip text for abbreviations (empty if not an abbreviation)
}

// RichText contains runs of styled text for mixed-style paragraphs.
pub struct RichText {
pub:
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

// to_vglyph_rich_text converts a RichText to vglyph.RichText for layout.
fn (rt RichText) to_vglyph_rich_text() vglyph.RichText {
	mut vg_runs := []vglyph.StyleRun{cap: rt.runs.len}
	for run in rt.runs {
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
