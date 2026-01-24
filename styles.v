module gui

// styles.v contains style definitions for all GUI components used in the framework.
// Each component has its own style struct that defines visual properties like colors,
// padding, borders, text styles etc. The styles provide consistent theming across
// the entire GUI framework.
import gg
import time
import vglyph

// BoxShadow defines the visual properties of a drop shadow.
// It tries to mimic the CSS box-shadow property logic where possible.
pub struct BoxShadow {
pub:
	color         Color // The color of the shadow (usually with alpha < 255)
	offset_x      f32   // Horizontal offset in pixels. Positive values move shadow right.
	offset_y      f32   // Vertical offset in pixels. Positive values move shadow down.
	blur_radius   f32   // The blur radius in pixels. Higher values make the shadow softer and larger.
	spread_radius f32   // The spread radius in pixels. Positive values expand the shadow, negative contract it.
}

pub enum GradientType {
	linear
	radial
}

pub struct GradientStop {
pub:
	color Color
	pos   f32 // 0.0 to 1.0 (0% to 100%)
}

pub struct Gradient {
pub:
	stops   []GradientStop
	start_x f32 // 0.0 to 1.0 (relative to container width)
	start_y f32
	end_x   f32 // 0.0 to 1.0
	end_y   f32
	type    GradientType = .linear
}

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
	border_width       f32
	radius             f32 = radius_medium
	radius_border      f32 = radius_medium
}

pub struct ContainerStyle {
pub:
	color           Color = color_transparent
	fill            bool
	padding         Padding = padding_medium
	radius          f32     = radius_medium
	blur_radius     f32
	spacing         f32 = spacing_medium
	shadow          BoxShadow
	gradient        &Gradient = unsafe { nil }
	border_gradient &Gradient = unsafe { nil }
	border_width    f32       = 1.0
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
	border_width             f32

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
	border_width     f32

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
	border_width   f32

	radius         f32     = radius_medium
	radius_border  f32     = radius_medium
}

pub struct InputStyle {
pub:
	color              Color   = color_interior_dark
	color_hover        Color   = color_hover_dark
	color_border       Color   = color_border_dark
	color_border_focus Color   = color_select_dark
	color_focus        Color   = color_active_dark
	fill               bool    = true
	fill_border        bool    = true
	padding            Padding = padding_small
	padding_border     Padding = padding_none
	border_width       f32
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
	border_width     f32

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
	padding_submenu        Padding   = padding_small
	padding_subtitle       Padding   = padding_two_five
	border_width           f32

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
	color          Color   = color_interior_dark
	color_hover    Color   = color_hover_dark
	color_focus    Color   = color_select_dark
	color_border   Color   = color_border_dark
	color_select   Color   = color_text_dark
	color_unselect Color   = color_active_dark
	padding        Padding = pad_all(4)
	border_width   f32
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
	border_width   f32

	radius         f32     = radius_small
	radius_border  f32     = radius_small
}

pub struct RectangleStyle {
pub:
	color        Color = color_border_dark
	radius       f32   = radius_medium
	fill         bool
	gradient     &Gradient = unsafe { nil }
	border_width f32       = 1.0
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
	border_width     f32

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
	border_width       f32

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
	align          TextAlignment = .left
	underline      bool
	strikethrough  bool
	// features is a pointer to font features (OpenType features and variation axes).
	features &vglyph.FontFeatures = unsafe { nil }
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
			features:      ts.features
			underline:     ts.underline
			strikethrough: ts.strikethrough
		}
		block: vglyph.BlockStyle{
			align: match ts.align {
				.left { vglyph.Alignment.left }
				.center { vglyph.Alignment.center }
				.right { vglyph.Alignment.right }
			}
		}
	}
}

pub struct ToggleStyle {
pub:
	color              Color   = color_interior_dark
	color_border       Color   = color_border_dark
	color_border_focus Color   = color_select_dark
	color_click        Color   = color_interior_dark
	color_focus        Color   = color_active_dark
	color_hover        Color   = color_hover_dark
	color_select       Color   = color_interior_dark
	fill               bool    = true
	fill_border        bool    = true
	padding            Padding = padding(1, 1, 1, 2)

	border_width       f32
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
	border_width       f32

	radius             f32           = radius_small
	radius_border      f32           = radius_small
	text_style         TextStyle     = text_style_dark
}

pub struct TreeStyle {
pub:
	indent          f32 = 25
	spacing         f32
	blur_radius     f32
	shadow          BoxShadow
	text_style      TextStyle = text_style_dark
	text_style_icon TextStyle = TextStyle{
		...text_style_icon_dark
		family: font_file_icon
		size:   size_text_small
	}
}
