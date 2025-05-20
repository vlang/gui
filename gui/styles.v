module gui

import gx

pub struct ButtonStyle {
pub:
	color              Color   = color_2_dark
	color_border       Color   = color_border_dark
	color_border_focus Color   = color_link_dark
	color_click        Color   = color_4_dark
	color_focus        Color   = color_5_dark
	color_hover        Color   = color_3_dark
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

pub struct DialogStyle {
pub:
	color            Color           = color_2_dark
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

pub struct InputStyle {
pub:
	color              Color     = color_2_dark
	color_border       Color     = color_border_dark
	color_border_focus Color     = color_link_dark
	color_focus        Color     = color_5_dark
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
}

pub struct MenubarStyle {
pub:
	width_submenu_min      f32       = 50
	width_submenu_max      f32       = 200
	color                  Color     = color_2_dark
	color_border           Color     = color_border_dark
	color_selected         Color     = color_5_dark
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
	text_style             TextStyle = TextStyle{
		size: size_text_small
	}
	text_style_subtitle    TextStyle = TextStyle{
		size: size_text_x_small
	}
}

pub struct ProgressBarStyle {
pub:
	color           Color     = color_2_dark
	color_bar       Color     = color_5_dark
	fill            bool      = true
	padding         Padding   = padding_medium
	radius          f32       = radius_medium
	size            f32       = size_progress_bar
	text_show       bool      = true
	text_background Color     = color_transparent
	text_fill       bool      = true
	text_padding    Padding   = padding_two_five
	text_style      TextStyle = text_style_dark
}

pub struct RadioStyle {
pub:
	color            Color   = color_2_dark
	color_focus      Color   = color_link_dark
	color_border     Color   = color_5_dark
	color_selected   Color   = color_text_dark
	color_unselected Color   = color_5_dark
	padding          Padding = pad_all(4)
}

pub struct RangeSliderStyle {
pub:
	size           f32     = 7
	thumb_size     f32     = 15
	color          Color   = color_2_dark
	color_click    Color   = color_4_dark
	color_left     Color   = color_link_dark
	color_focus    Color   = color_4_dark
	color_hover    Color   = color_3_dark
	color_border   Color   = color_5_dark
	color_thumb    Color   = color_link_dark
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
	color_thumb      Color = color_5_dark
	color_background Color = color_transparent
	fill_thumb       bool  = true
	fill_background  bool
	radius           f32 = radius_small
	radius_thumb     f32 = radius_small
	offset_x         f32 = -3
	offset_y         f32
}

pub struct TextStyle {
pub:
	color        Color
	size         int
	family       string
	line_spacing f32
}

fn (tc TextStyle) to_text_cfg() gx.TextCfg {
	return gx.TextCfg{
		color:  tc.color.to_gx_color()
		size:   tc.size
		family: tc.family
		bold:   true
	}
}

pub struct SwitchStyle {
pub:
	color              Color   = color_2_dark
	color_border       Color   = color_border_dark
	color_border_focus Color   = color_link_dark
	color_click        Color   = color_2_dark
	color_focus        Color   = color_2_dark
	color_hover        Color   = color_5_dark
	color_selected     Color   = color_text_dark
	color_unselected   Color   = color_5_dark
	fill               bool    = true
	fill_border        bool    = true
	padding            Padding = padding_three
	padding_border     Padding = padding_none
	radius             f32     = radius_large * 2
	radius_border      f32     = radius_large * 2
}

pub struct ToggleStyle {
pub:
	color              Color     = color_2_dark
	color_border       Color     = color_border_dark
	color_border_focus Color     = color_link_dark
	color_click        Color     = color_2_dark
	color_focus        Color     = color_5_dark
	color_hover        Color     = color_3_dark
	color_selected     Color     = color_1_dark
	fill               bool      = true
	fill_border        bool      = true
	padding            Padding   = padding_one
	padding_border     Padding   = padding_none
	radius             f32       = radius_small
	radius_border      f32       = radius_small
	text_style         TextStyle = TextStyle{
		size: size_text_small
	}
}
