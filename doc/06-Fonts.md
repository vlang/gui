----------
# 6 Fonts 
----------
Gui embeds a commercial-free, open-source font named Deja Vu Sans. This
font is the default family with bold, italic, and monospaced variations.
Deja Vu Sans has most of the Western Latin-1 characters one expects
(forgive me, I grew up in the US so other character sets are not
included).

So why not use the supplied system fonts? Mostly, this comes down to
consistency. System fonts vary in size so what looks well-proportioned
on one platform is not as attractive on another. It also means that
languages like Chinese simply do not render. The good news is you can
use the system fonts.

The easiest way is to modify an existing `ThemeCfg`. Here’s an example.

``` v
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

Setting the `family` to an empty string forces Gui to look for and load
system fonts for that platform.

Most views in Gui have their own text style parameter allowing views to
have different font families if desired.
