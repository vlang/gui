module gui

// styles.v contains style definitions for all GUI components used in the framework.
// Each component has its own style struct that defines visual properties like colors,
// padding, borders, text styles etc. The styles provide consistent theming across
// the entire GUI framework.
import gg
import time
import vglyph

pub struct ButtonStyle {
pub:
	color              Color   = color_interior_dark
	color_hover        Color   = color_hover_dark
	color_focus        Color   = color_active_dark
	color_click        Color   = color_active_dark
	color_border       Color   = color_border_dark
	color_border_focus Color   = color_select_dark
	fill               bool    = true
	fill_border        bool    = true
	padding            Padding = padding_button
	padding_border     Padding = padding_none
	radius             f32     = radius_medium
	radius_border      f32     = radius_medium
}

pub struct ContainerStyle {
pub:
	color   Color = color_transparent
	fill    bool
	padding Padding = padding_medium
	radius  f32     = radius_medium
	spacing f32     = spacing_medium
}

pub struct DatePickerStyle {
pub:
	hide_today_indicator     bool
	monday_first_day_of_week bool
	show_adjacent_months     bool
	cell_spacing             f32 = 3
	weekdays_len             DatePickerWeekdayLen
	color                    Color     = color_interior_dark
	color_hover              Color     = color_hover_dark
	color_focus              Color     = color_focus_dark
	color_click              Color     = color_active_dark
	color_border             Color     = color_border_dark
	color_border_focus       Color     = color_select_dark
	color_select             Color     = color_select_dark
	fill                     bool      = true
	fill_border              bool      = true
	padding                  Padding   = padding_none
	padding_border           Padding   = padding_none
	radius                   f32       = radius_medium
	radius_border            f32       = radius_medium
	text_style               TextStyle = text_style_dark
}

pub struct DialogStyle {
pub:
	color            Color           = color_panel_dark
	color_border     Color           = color_border_dark
	fill             bool            = true
	fill_border      bool            = true
	padding          Padding         = padding_large
	padding_border   Padding         = padding_none
	radius           f32             = radius_medium
	radius_border    f32             = radius_medium
	align_buttons    HorizontalAlign = .center
	title_text_style TextStyle       = TextStyle{
		...text_style_dark
		size: size_text_large
	}
	text_style       TextStyle = text_style_dark
}

pub struct ExpandPanelStyle {
	color          Color   = color_panel_dark
	color_border   Color   = color_border_dark
	fill           bool    = true
	fill_border    bool    = true
	padding        Padding = padding_one
	padding_border Padding = padding_none
	radius         f32     = radius_medium
	radius_border  f32     = radius_medium
}

pub struct InputStyle {
pub:
	color              Color     = color_interior_dark
	color_hover        Color     = color_hover_dark
	color_border       Color     = color_border_dark
	color_border_focus Color     = color_select_dark
	color_focus        Color     = color_active_dark
	fill               bool      = true
	fill_border        bool      = true
	padding            Padding   = padding_small
	padding_border     Padding   = padding_none
	radius             f32       = radius_medium
	radius_border      f32       = radius_medium
	text_style         TextStyle = text_style_dark
	placeholder_style  TextStyle = TextStyle{
		...text_style_dark
		color: Color{
			r: text_style_dark.color.a
			g: text_style_dark.color.g
			b: text_style_dark.color.b
			a: 100
		}
	}
	icon_style         TextStyle = TextStyle{
		...text_style_dark
		size:   size_text_medium
		family: font_file_icon
	}
}

pub struct ListBoxStyle {
pub:
	color            Color     = color_interior_dark
	color_hover      Color     = color_hover_dark
	color_border     Color     = color_border_dark
	color_select     Color     = color_select_dark
	fill             bool      = true
	fill_border      bool      = true
	padding          Padding   = padding_button
	padding_border   Padding   = padding_none
	radius           f32       = radius_medium
	radius_border    f32       = radius_medium
	text_style       TextStyle = text_style_dark
	subheading_style TextStyle = text_style_dark
}

pub struct MenubarStyle {
pub:
	width_submenu_min      f32       = 50
	width_submenu_max      f32       = 200
	color                  Color     = color_interior_dark
	color_border           Color     = color_border_dark
	color_select           Color     = color_select_dark
	padding                Padding   = padding_small
	padding_menu_item      Padding   = padding_two_five
	padding_border         Padding   = padding_none
	padding_submenu        Padding   = padding_small
	padding_submenu_border Padding   = padding_none
	padding_subtitle       Padding   = padding_two_five
	radius                 f32       = radius_small
	radius_border          f32       = radius_border
	radius_submenu         f32       = radius_small
	radius_menu_item       f32       = radius_small
	spacing                f32       = gui_theme.spacing_medium
	spacing_submenu        f32       = 1
	text_style             TextStyle = text_style_dark
	text_style_subtitle    TextStyle = TextStyle{
		...text_style_dark
		size: size_text_small
	}
}

pub struct ProgressBarStyle {
pub:
	size            f32       = size_progress_bar
	padding         Padding   = padding_medium
	radius          f32       = radius_medium
	fill            bool      = true
	color           Color     = color_interior_dark
	color_bar       Color     = color_active_dark
	text_show       bool      = true
	text_background Color     = color_transparent
	text_fill       bool      = true
	text_padding    Padding   = padding_two_five
	text_style      TextStyle = text_style_dark
}

pub struct RadioStyle {
pub:
	color          Color     = color_interior_dark
	color_hover    Color     = color_hover_dark
	color_focus    Color     = color_select_dark
	color_border   Color     = color_border_dark
	color_select   Color     = color_text_dark
	color_unselect Color     = color_active_dark
	padding        Padding   = pad_all(4)
	text_style     TextStyle = text_style_dark
}

pub struct RangeSliderStyle {
pub:
	size           f32     = 7
	thumb_size     f32     = 15
	color          Color   = color_interior_dark
	color_click    Color   = color_select_dark
	color_thumb    Color   = color_active_dark
	color_left     Color   = color_active_dark
	color_focus    Color   = color_focus_dark
	color_hover    Color   = color_hover_dark
	color_border   Color   = color_border_dark
	fill           bool    = true
	fill_border    bool    = true
	padding        Padding = padding_none
	padding_border Padding = padding_none
	radius         f32     = radius_small
	radius_border  f32     = radius_small
}

pub struct RectangleStyle {
pub:
	color  Color = color_border_dark
	radius f32   = radius_medium
	fill   bool
}

pub struct ScrollbarStyle {
pub:
	size             f32   = 7
	color_thumb      Color = color_active_dark
	color_background Color = color_transparent
	fill_thumb       bool  = true
	fill_background  bool
	radius           f32 = radius_small
	radius_thumb     f32 = radius_small
	gap_edge         f32 = 3
	gap_end          f32 = 2
}

pub struct SelectStyle {
pub:
	min_width          f32       = 75
	max_width          f32       = 200
	color              Color     = color_interior_dark
	color_focus        Color     = color_interior_dark
	color_border       Color     = color_border_dark
	color_border_focus Color     = color_select_dark
	color_select       Color     = color_select_dark
	fill               bool      = true
	fill_border        bool      = true
	padding            Padding   = padding_small
	padding_border     Padding   = padding_one
	radius             f32       = radius_medium
	radius_border      f32       = radius_medium
	text_style         TextStyle = text_style_dark
	subheading_style   TextStyle = text_style_dark
	placeholder_style  TextStyle = TextStyle{
		...text_style_dark
		color: Color{
			r: text_style_dark.color.a
			g: text_style_dark.color.g
			b: text_style_dark.color.b
			a: 100
		}
	}
}

pub struct SwitchStyle {
pub:
	color              Color     = color_interior_dark
	color_click        Color     = color_interior_dark
	color_focus        Color     = color_focus_dark
	color_hover        Color     = color_hover_dark
	color_border       Color     = color_border_dark
	color_border_focus Color     = color_select_dark
	color_select       Color     = color_select_dark
	color_unselect     Color     = color_active_dark
	fill               bool      = true
	fill_border        bool      = true
	padding            Padding   = padding_three
	padding_border     Padding   = padding_none
	radius             f32       = radius_large * 2
	radius_border      f32       = radius_large * 2
	text_style         TextStyle = text_style_dark
}

@[minify]
pub struct TextStyle {
pub:
	family         string
	color          Color
	size           f32 = size_text_medium
	line_spacing   f32
	letter_spacing f32
	underline      bool
	strikethrough  bool
	// features is a map of OpenType feature tags to their values.
	// For example: {'wdth': 100.0, 'wght': 400.0}
	features map[string]f32
}

fn (ts TextStyle) to_text_cfg() gg.TextCfg {
	return gg.TextCfg{
		color:  ts.color.to_gx_color()
		size:   int(ts.size)
		family: ts.family
	}
}

pub fn (ts TextStyle) to_vglyph_cfg() vglyph.TextConfig {
	return vglyph.TextConfig{
		style: vglyph.TextStyle{
			font_name:     ts.family
			color:         ts.color.to_gx_color()
			size:          ts.size
			features:      &vglyph.FontFeatures{
				variation_axes: ts.features
			}
			underline:     ts.underline
			strikethrough: ts.strikethrough
		}
	}
}

pub struct ToggleStyle {
pub:
	color              Color     = color_interior_dark
	color_border       Color     = color_border_dark
	color_border_focus Color     = color_select_dark
	color_click        Color     = color_interior_dark
	color_focus        Color     = color_active_dark
	color_hover        Color     = color_hover_dark
	color_select       Color     = color_interior_dark
	fill               bool      = true
	fill_border        bool      = true
	padding            Padding   = padding(1, 1, 1, 2)
	padding_border     Padding   = padding_none
	radius             f32       = radius_small
	radius_border      f32       = radius_small
	text_style         TextStyle = text_style_icon_dark
	text_style_label   TextStyle = text_style_dark
}

pub struct TooltipStyle {
	delay              time.Duration = 500 * time.millisecond
	color              Color         = color_interior_dark
	color_hover        Color         = color_hover_dark
	color_focus        Color         = color_active_dark
	color_click        Color         = color_active_dark
	color_border       Color         = color_border_dark
	color_border_focus Color         = color_select_dark
	fill               bool          = true
	fill_border        bool          = true
	padding            Padding       = padding_small
	padding_border     Padding       = padding_none
	radius             f32           = radius_small
	radius_border      f32           = radius_small
	text_style         TextStyle     = text_style_dark
}

pub struct TreeStyle {
pub:
	indent          f32       = 25
	spacing         f32       = pad_small
	text_style      TextStyle = text_style_dark
	text_style_icon TextStyle = TextStyle{
		...text_style_icon_dark
		family: font_file_icon
		size:   size_text_small
	}
}
