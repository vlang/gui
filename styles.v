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

pub enum GradientDirection {
	to_top
	to_top_right
	to_right
	to_bottom_right
	to_bottom
	to_bottom_left
	to_left
	to_top_left
}

pub struct GradientStop {
pub:
	color Color
	pos   f32 // 0.0 to 1.0 (0% to 100%)
}

pub struct Gradient {
pub:
	stops     []GradientStop // packed to 5 stops for shader upload
	type      GradientType      = .linear
	direction GradientDirection = .to_bottom // CSS default
	angle     ?f32 // Optional explicit angle (degrees), overrides direction
}

pub struct ColorPickerStyle {
pub:
	color              Color     = color_interior_dark
	color_hover        Color     = color_hover_dark
	color_border       Color     = color_border_dark
	color_border_focus Color     = color_select_dark
	padding            Padding   = padding_small
	size_border        f32       = size_border
	radius             f32       = radius_medium
	sv_size            f32       = 200
	slider_height      f32       = 24
	indicator_size     f32       = 16
	text_style         TextStyle = text_style_dark
}

pub struct ButtonStyle {
pub:
	color              Color   = color_interior_dark
	color_hover        Color   = color_hover_dark
	color_focus        Color   = color_active_dark
	color_click        Color   = color_active_dark
	color_border       Color   = color_border_dark
	color_border_focus Color   = color_select_dark
	padding            Padding = padding_button
	padding_border     Padding = padding_none
	size_border        f32     = size_border
	radius             f32     = radius_medium
	radius_border      f32     = radius_medium
	blur_radius        f32
	shadow             &BoxShadow = unsafe { nil }
	gradient           &Gradient  = unsafe { nil }
}

pub struct ContainerStyle {
pub:
	color           Color   = color_transparent
	color_border    Color   = color_transparent
	padding         Padding = padding_medium
	radius          f32     = radius_medium
	blur_radius     f32
	spacing         f32        = spacing_medium
	shadow          &BoxShadow = unsafe { nil }
	gradient        &Gradient  = unsafe { nil }
	border_gradient &Gradient  = unsafe { nil }
	size_border     f32        = size_border
}

pub struct DatePickerStyle {
pub:
	hide_today_indicator     bool
	monday_first_day_of_week bool
	show_adjacent_months     bool
	cell_spacing             f32 = 3
	weekdays_len             DatePickerWeekdayLen
	color                    Color      = color_interior_dark
	color_hover              Color      = color_hover_dark
	color_focus              Color      = color_focus_dark
	color_click              Color      = color_active_dark
	color_border             Color      = color_border_dark
	color_border_focus       Color      = color_select_dark
	color_select             Color      = color_select_dark
	padding                  Padding    = padding_none
	size_border              f32        = size_border
	radius                   f32        = radius_medium
	radius_border            f32        = radius_medium
	shadow                   &BoxShadow = unsafe { nil }
	text_style               TextStyle  = text_style_dark
}

pub struct DialogStyle {
pub:
	color              Color   = color_panel_dark
	color_border       Color   = color_border_dark
	color_border_focus Color   = color_select_dark
	padding            Padding = padding_large
	size_border        f32     = size_border
	radius             f32     = radius_medium
	radius_border      f32     = radius_medium
	blur_radius        f32
	shadow             &BoxShadow      = unsafe { nil }
	align_buttons      HorizontalAlign = .center
	title_text_style   TextStyle       = TextStyle{
		...text_style_dark
		size: size_text_large
	}
	text_style         TextStyle = text_style_dark
}

pub struct ExpandPanelStyle {
pub:
	color              Color      = color_panel_dark
	color_hover        Color      = color_hover_dark
	color_focus        Color      = color_focus_dark
	color_click        Color      = color_active_dark
	color_border       Color      = color_border_dark
	color_border_focus Color      = color_select_dark
	padding            Padding    = padding_one
	size_border        f32        = size_border
	radius             f32        = radius_medium
	radius_border      f32        = radius_medium
	shadow             &BoxShadow = unsafe { nil }
}

pub struct InputStyle {
pub:
	color              Color      = color_interior_dark
	color_hover        Color      = color_hover_dark
	color_focus        Color      = color_active_dark
	color_click        Color      = color_active_dark
	color_border       Color      = color_border_dark
	color_border_focus Color      = color_select_dark
	padding            Padding    = padding_small
	padding_border     Padding    = padding_none
	size_border        f32        = size_border
	radius             f32        = radius_medium
	radius_border      f32        = radius_medium
	shadow             &BoxShadow = unsafe { nil }
	text_style         TextStyle  = text_style_dark
	placeholder_style  TextStyle  = TextStyle{
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
	color              Color      = color_interior_dark
	color_hover        Color      = color_hover_dark
	color_focus        Color      = color_focus_dark
	color_border       Color      = color_border_dark
	color_border_focus Color      = color_select_dark
	color_select       Color      = color_select_dark
	padding            Padding    = padding_button
	size_border        f32        = size_border
	radius             f32        = radius_medium
	radius_border      f32        = radius_medium
	shadow             &BoxShadow = unsafe { nil }
	text_style         TextStyle  = text_style_dark
	subheading_style   TextStyle  = text_style_dark
}

pub struct DataGridStyle {
pub:
	color_background    Color     = color_interior_dark
	color_header        Color     = color_panel_dark
	color_header_hover  Color     = color_hover_dark
	color_filter        Color     = color_interior_dark
	color_quick_filter  Color     = color_panel_dark
	color_row_hover     Color     = color_hover_dark
	color_row_alt       Color     = color_transparent
	color_row_selected  Color     = color_select_dark
	color_border        Color     = color_border_dark
	color_resize_handle Color     = color_border_dark
	color_resize_active Color     = color_select_dark
	padding_cell        Padding   = padding_two_five
	padding_header      Padding   = padding_two_five
	padding_filter      Padding   = padding_none
	size_border         f32       = size_border
	radius              f32       = radius_small
	text_style          TextStyle = text_style_dark
	text_style_header   TextStyle = TextStyle{
		...text_style_dark
		typeface: .bold
	}
	text_style_filter   TextStyle = text_style_dark
}

pub struct MenubarStyle {
pub:
	width_submenu_min   f32        = 50
	width_submenu_max   f32        = 200
	color               Color      = color_interior_dark
	color_hover         Color      = color_hover_dark
	color_focus         Color      = color_focus_dark
	color_border        Color      = color_border_dark
	color_border_focus  Color      = color_select_dark
	color_select        Color      = color_select_dark
	padding             Padding    = padding_small
	padding_menu_item   Padding    = padding_two_five
	padding_submenu     Padding    = padding_small
	padding_subtitle    Padding    = padding_two_five
	size_border         f32        = size_border
	radius              f32        = radius_small
	radius_border       f32        = radius_border
	radius_submenu      f32        = radius_small
	radius_menu_item    f32        = radius_small
	shadow              &BoxShadow = unsafe { nil }
	spacing             f32        = gui_theme.spacing_medium
	spacing_submenu     f32        = 1
	text_style          TextStyle  = text_style_dark
	text_style_subtitle TextStyle  = TextStyle{
		...text_style_dark
		size: size_text_small
	}
}

pub struct ProgressBarStyle {
pub:
	size            f32       = size_progress_bar
	padding         Padding   = padding_medium
	size_border     f32       = size_border
	radius          f32       = radius_medium
	color           Color     = color_interior_dark
	color_bar       Color     = color_active_dark
	color_border    Color     = color_border_dark
	text_show       bool      = true
	text_background Color     = color_transparent
	text_padding    Padding   = padding_two_five
	text_style      TextStyle = text_style_dark
}

pub struct RadioStyle {
pub:
	size               f32       = size_text_medium // dedicated size property
	color              Color     = color_interior_dark
	color_hover        Color     = color_hover_dark
	color_focus        Color     = color_select_dark
	color_click        Color     = color_active_dark
	color_border       Color     = color_border_dark
	color_border_focus Color     = color_select_dark
	color_select       Color     = color_select_dark
	color_unselect     Color     = color_transparent
	padding            Padding   = pad_all(4)
	size_border        f32       = f32(2.0)
	text_style         TextStyle = text_style_dark
}

pub struct RangeSliderStyle {
pub:
	size               f32        = 7
	thumb_size         f32        = 15
	color              Color      = color_interior_dark
	color_click        Color      = color_select_dark
	color_thumb        Color      = color_active_dark
	color_left         Color      = color_active_dark
	color_focus        Color      = color_focus_dark
	color_hover        Color      = color_hover_dark
	color_border       Color      = color_border_dark
	color_border_focus Color      = color_select_dark
	padding            Padding    = padding_none
	size_border        f32        = size_border
	radius             f32        = radius_small
	radius_border      f32        = radius_small
	shadow             &BoxShadow = unsafe { nil }
}

pub struct RectangleStyle {
pub:
	color           Color = color_transparent
	color_border    Color = color_border_dark
	radius          f32   = radius_medium
	blur_radius     f32
	shadow          &BoxShadow = unsafe { nil }
	gradient        &Gradient  = unsafe { nil }
	border_gradient &Gradient  = unsafe { nil }
	size_border     f32        = size_border
}

pub struct SplitterStyle {
pub:
	handle_size         f32   = 9
	drag_step           f32   = 0.02
	drag_step_large     f32   = 0.10
	color_handle        Color = color_interior_dark
	color_handle_hover  Color = color_hover_dark
	color_handle_active Color = color_active_dark
	color_handle_border Color = color_border_dark
	color_grip          Color = color_select_dark
	color_button        Color = color_interior_dark
	color_button_hover  Color = color_hover_dark
	color_button_active Color = color_active_dark
	color_button_icon   Color = color_text_dark
	size_border         f32   = size_border
	radius              f32   = radius_small
	radius_border       f32   = radius_small
}

pub struct ScrollbarStyle {
pub:
	size             f32   = 7
	min_thumb_size   f32   = 20 // minimum thumb size in pixels
	color_thumb      Color = color_active_dark
	color_background Color = color_transparent
	radius           f32   = radius_small
	radius_thumb     f32   = radius_small
	gap_edge         f32   = 3
	gap_end          f32   = 2
}

pub struct SelectStyle {
pub:
	min_width          f32        = 75
	max_width          f32        = 200
	color              Color      = color_interior_dark
	color_hover        Color      = color_hover_dark
	color_focus        Color      = color_interior_dark
	color_click        Color      = color_active_dark
	color_border       Color      = color_border_dark
	color_border_focus Color      = color_select_dark
	color_select       Color      = color_select_dark
	padding            Padding    = padding_small
	size_border        f32        = size_border
	radius             f32        = radius_medium
	radius_border      f32        = radius_medium
	shadow             &BoxShadow = unsafe { nil }
	text_style         TextStyle  = text_style_dark
	subheading_style   TextStyle  = text_style_dark
	placeholder_style  TextStyle  = TextStyle{
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
	size_width         f32        = 36 // dedicated width
	size_height        f32        = 22 // dedicated height
	color              Color      = color_interior_dark
	color_click        Color      = color_interior_dark
	color_focus        Color      = color_focus_dark
	color_hover        Color      = color_hover_dark
	color_border       Color      = color_border_dark
	color_border_focus Color      = color_select_dark
	color_select       Color      = color_select_dark
	color_unselect     Color      = color_active_dark
	padding            Padding    = padding_three
	size_border        f32        = size_border
	radius             f32        = radius_large * 2
	radius_border      f32        = radius_large * 2
	shadow             &BoxShadow = unsafe { nil }
	text_style         TextStyle  = text_style_dark
}

pub struct TabStyle {
pub:
	color                  Color   = color_panel_dark
	color_border           Color   = color_border_dark
	color_header           Color   = color_transparent
	color_header_border    Color   = color_transparent
	color_content          Color   = color_panel_dark
	color_content_border   Color   = color_border_dark
	color_tab              Color   = color_interior_dark
	color_tab_hover        Color   = color_hover_dark
	color_tab_focus        Color   = color_focus_dark
	color_tab_click        Color   = color_active_dark
	color_tab_selected     Color   = color_select_dark
	color_tab_disabled     Color   = color_panel_dark
	color_tab_border       Color   = color_border_dark
	color_tab_border_focus Color   = color_select_dark
	padding                Padding = padding_none
	padding_header         Padding = padding_none
	padding_content        Padding = padding_medium
	padding_tab            Padding = padding_small
	size_border            f32     = size_border
	size_header_border     f32
	size_content_border    f32       = size_border
	size_tab_border        f32       = size_border
	radius                 f32       = radius_medium
	radius_header          f32       = radius_small
	radius_content         f32       = radius_medium
	radius_tab             f32       = radius_small
	radius_tab_border      f32       = radius_small
	spacing                f32       = spacing_small
	spacing_header         f32       = spacing_small
	text_style             TextStyle = text_style_dark
	text_style_selected    TextStyle = TextStyle{
		...text_style_dark
		typeface: .bold
	}
	text_style_disabled    TextStyle = TextStyle{
		...text_style_dark
		color: Color{
			r: text_style_dark.color.r
			g: text_style_dark.color.g
			b: text_style_dark.color.b
			a: 130
		}
	}
}

@[minify]
pub struct TextStyle {
pub:
	family           string
	color            Color
	bg_color         Color = color_transparent
	size             f32   = size_text_medium
	typeface         vglyph.Typeface // .regular, .bold, .italic, .bold_italic
	line_spacing     f32
	letter_spacing   f32
	align            TextAlignment = .left
	underline        bool
	strikethrough    bool
	rotation_radians f32
	affine_transform ?vglyph.AffineTransform
	// features is a pointer to font features (OpenType features and variation axes).
	features     &vglyph.FontFeatures   = unsafe { nil }
	gradient     &vglyph.GradientConfig = unsafe { nil }
	stroke_width f32
	stroke_color Color = color_transparent
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
		style:    vglyph.TextStyle{
			font_name:      ts.family
			color:          ts.color.to_gx_color()
			size:           ts.size
			features:       ts.features
			underline:      ts.underline
			strikethrough:  ts.strikethrough
			typeface:       ts.typeface
			letter_spacing: ts.letter_spacing
			stroke_width:   ts.stroke_width
			stroke_color:   ts.stroke_color.to_gx_color()
		}
		block:    vglyph.BlockStyle{
			align: match ts.align {
				.left { vglyph.Alignment.left }
				.center { vglyph.Alignment.center }
				.right { vglyph.Alignment.right }
			}
		}
		gradient: ts.gradient
	}
}

@[inline]
fn affine_is_identity(transform vglyph.AffineTransform) bool {
	return transform.xx == 1.0 && transform.xy == 0.0 && transform.yx == 0.0 && transform.yy == 1.0
		&& transform.x0 == 0.0 && transform.y0 == 0.0
}

pub fn (ts TextStyle) has_text_transform() bool {
	if transform := ts.affine_transform {
		return !affine_is_identity(transform)
	}
	return ts.rotation_radians != 0
}

pub fn (ts TextStyle) effective_text_transform() vglyph.AffineTransform {
	if transform := ts.affine_transform {
		return transform
	}
	if ts.rotation_radians != 0 {
		return vglyph.affine_rotation(ts.rotation_radians)
	}
	return vglyph.affine_identity()
}

pub struct ToggleStyle {
pub:
	color              Color      = color_interior_dark
	color_border       Color      = color_border_dark
	color_border_focus Color      = color_select_dark
	color_click        Color      = color_interior_dark
	color_focus        Color      = color_active_dark
	color_hover        Color      = color_hover_dark
	color_select       Color      = color_interior_dark
	padding            Padding    = padding(1, 1, 1, 2)
	size_border        f32        = size_border
	radius             f32        = radius_small
	radius_border      f32        = radius_small
	shadow             &BoxShadow = unsafe { nil }
	text_style         TextStyle  = text_style_icon_dark
	text_style_label   TextStyle  = text_style_dark
}

pub struct TooltipStyle {
pub:
	delay              time.Duration = 500 * time.millisecond
	color              Color         = color_interior_dark
	color_hover        Color         = color_hover_dark
	color_focus        Color         = color_active_dark
	color_click        Color         = color_active_dark
	color_border       Color         = color_border_dark
	color_border_focus Color         = color_select_dark
	padding            Padding       = padding_small
	size_border        f32           = size_border
	radius             f32           = radius_small
	radius_border      f32           = radius_small
	shadow             &BoxShadow    = unsafe { nil }
	text_style         TextStyle     = text_style_dark
}

pub struct TreeStyle {
pub:
	indent             f32 = 25
	spacing            f32
	color              Color   = color_transparent
	color_hover        Color   = color_hover_dark
	color_focus        Color   = color_focus_dark
	color_border       Color   = color_transparent
	color_border_focus Color   = color_select_dark
	padding            Padding = padding_none
	size_border        f32     = size_border
	radius             f32     = radius_medium
	blur_radius        f32
	shadow             &BoxShadow = unsafe { nil }
	text_style         TextStyle  = text_style_dark
	text_style_icon    TextStyle  = TextStyle{
		...text_style_icon_dark
		family: font_file_icon
		size:   size_text_small
	}
}
