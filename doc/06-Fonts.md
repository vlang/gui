# 6 Fonts

Gui embeds a commercial-free, open-source text font (DejaVu Sans) and
ships an icon font. By default, Gui uses DejaVu Sans for text with bold,
italic, and monospaced variants.

What’s included - Text fonts (embedded and auto-installed on first
run): - DejaVu Sans Regular, Bold, Italic, Mono - Icon font: - Feather
Icons (as a TTF and exposed via `icon_*` constants)

Why embed fonts? - Consistency across platforms: system defaults differ
in metrics and hinting, so layouts that look balanced on one OS may
appear off on another. - Predictable glyph coverage: DejaVu Sans covers
most Western Latin-1 characters. For broader scripts (e.g., CJK), switch
to a system font or a custom font that includes the glyphs you need.

Where are the embedded files placed? - On first use, Gui writes the
bundled TTFs to your platform’s data directory (`os.data_dir()`). You
don’t need to manage these files manually.

Using system fonts (platform default) The easiest way is to modify a
`ThemeCfg` and set the text style’s `family` to an empty string. This
tells Gui to use the platform’s default font for all text.

```v
import gui

fn create_system_font_theme() gui.Theme {
	return gui.theme_maker(gui.ThemeCfg{
		...gui.theme_dark_bordered_cfg
		text_style: gui.TextStyle{
			...gui.theme_dark_bordered_cfg.text_style
			family: ''
		}
	})
}
```

Per-view overrides Most views accept a `text_style`, so you can change
the font on a per-view basis without altering the entire theme.

```v
import gui

gui.text(
	text:       'Hello, system font!'
	text_style: gui.TextStyle{
		...gui.theme().text_style
		family: '' // empty = use platform default for this view only
	}
)
```

Using a specific font file You can point `family` to a path for a
specific TTF/OTF. If you provide the “Regular” face, Gui will try to
locate Bold/Italic/Mono variants automatically.

```v
import gui

gui.text(
	text:       'Custom font'
	text_style: gui.TextStyle{
		...gui.theme().text_style
		family: '/path/to/MyFont-Regular.ttf'
	}
)
```

Icon fonts Gui includes an icon font and a set of `icon_*` constants for
common symbols. To render icons, use a text view with the icon font
family and supply the desired icon glyph.

```v
import gui

gui.text(
	text:       gui.icons_map['icon_check'] // or a specific icon constant
	text_style: gui.TextStyle{
		...gui.theme().text_style
		family: gui.font_file_icon
		size:   18
	}
)
```

Tip: See `examples/icon_font_demo.v` for a complete walkthrough.

Other text style knobs

- `size` (int): font size in pixels.
- `line_spacing` (f32): additional spacing between lines.
- `color`: text color. These are exposed on `TextStyle` and can be tweaked
  globally (theme) or locally (per view).

Troubleshooting

- Missing glyphs: If characters don’t render (e.g., Chinese), switch to a system
  font (`family: ''`) or a custom font with proper coverage.
- Inconsistent layout across OSes: Prefer the embedded fonts for uniform metrics,
  or pin a specific custom font across platforms.

Related examples - `examples/system_font.v` — toggle between embedded
and system fonts - `examples/fonts.v` — font basics and text styling -
`examples/icon_font_demo.v` — using the icon font