module svg

// SvgColor represents a 32-bit color in sRGB format.
// Equivalent to gui.Color but defined independently to
// avoid circular dependency between gui and gui.svg.
pub struct SvgColor {
pub mut:
	r u8
	g u8
	b u8
	a u8 = 255
}

// Sentinel: attribute not specified, inherit from parent.
pub const color_inherit = SvgColor{255, 0, 255, 1}

// Sentinel: explicit 'none', don't render.
pub const color_transparent = SvgColor{0, 0, 0, 0}

// Default fill when nothing specified.
const color_black = SvgColor{0, 0, 0, 255}

// SVG named color lookup table.
const string_colors = {
	'blue':                 SvgColor{0, 0, 255, 255}
	'red':                  SvgColor{255, 0, 0, 255}
	'green':                SvgColor{0, 128, 0, 255}
	'yellow':               SvgColor{255, 255, 0, 255}
	'orange':               SvgColor{255, 165, 0, 255}
	'purple':               SvgColor{128, 0, 128, 255}
	'black':                SvgColor{0, 0, 0, 255}
	'gray':                 SvgColor{128, 128, 128, 255}
	'grey':                 SvgColor{128, 128, 128, 255}
	'indigo':               SvgColor{75, 0, 130, 255}
	'pink':                 SvgColor{255, 192, 203, 255}
	'violet':               SvgColor{238, 130, 238, 255}
	'white':                SvgColor{255, 255, 255, 255}
	'cornflower_blue':      SvgColor{100, 149, 237, 255}
	'royal_blue':           SvgColor{65, 105, 225, 255}
	'dark_blue':            SvgColor{0, 0, 139, 255}
	'dark_gray':            SvgColor{169, 169, 169, 255}
	'dark_green':           SvgColor{0, 100, 0, 255}
	'dark_red':             SvgColor{139, 0, 0, 255}
	'light_blue':           SvgColor{173, 216, 230, 255}
	'light_gray':           SvgColor{211, 211, 211, 255}
	'light_green':          SvgColor{144, 238, 144, 255}
	'light_red':            SvgColor{255, 204, 203, 255}
	'cyan':                 SvgColor{0, 255, 255, 255}
	'magenta':              SvgColor{255, 0, 255, 255}
	// Extended SVG named colors
	'aliceblue':            SvgColor{240, 248, 255, 255}
	'antiquewhite':         SvgColor{250, 235, 215, 255}
	'aqua':                 SvgColor{0, 255, 255, 255}
	'aquamarine':           SvgColor{127, 255, 212, 255}
	'azure':                SvgColor{240, 255, 255, 255}
	'beige':                SvgColor{245, 245, 220, 255}
	'bisque':               SvgColor{255, 228, 196, 255}
	'blanchedalmond':       SvgColor{255, 235, 205, 255}
	'blueviolet':           SvgColor{138, 43, 226, 255}
	'brown':                SvgColor{165, 42, 42, 255}
	'burlywood':            SvgColor{222, 184, 135, 255}
	'cadetblue':            SvgColor{95, 158, 160, 255}
	'chartreuse':           SvgColor{127, 255, 0, 255}
	'chocolate':            SvgColor{210, 105, 30, 255}
	'coral':                SvgColor{255, 127, 80, 255}
	'cornflowerblue':       SvgColor{100, 149, 237, 255}
	'cornsilk':             SvgColor{255, 248, 220, 255}
	'crimson':              SvgColor{220, 20, 60, 255}
	'darkblue':             SvgColor{0, 0, 139, 255}
	'darkcyan':             SvgColor{0, 139, 139, 255}
	'darkgoldenrod':        SvgColor{184, 134, 11, 255}
	'darkgray':             SvgColor{169, 169, 169, 255}
	'darkgreen':            SvgColor{0, 100, 0, 255}
	'darkgrey':             SvgColor{169, 169, 169, 255}
	'darkkhaki':            SvgColor{189, 183, 107, 255}
	'darkmagenta':          SvgColor{139, 0, 139, 255}
	'darkolivegreen':       SvgColor{85, 107, 47, 255}
	'darkorange':           SvgColor{255, 140, 0, 255}
	'darkorchid':           SvgColor{153, 50, 204, 255}
	'darkred':              SvgColor{139, 0, 0, 255}
	'darksalmon':           SvgColor{233, 150, 122, 255}
	'darkseagreen':         SvgColor{143, 188, 143, 255}
	'darkslateblue':        SvgColor{72, 61, 139, 255}
	'darkslategray':        SvgColor{47, 79, 79, 255}
	'darkslategrey':        SvgColor{47, 79, 79, 255}
	'darkturquoise':        SvgColor{0, 206, 209, 255}
	'darkviolet':           SvgColor{148, 0, 211, 255}
	'deeppink':             SvgColor{255, 20, 147, 255}
	'deepskyblue':          SvgColor{0, 191, 255, 255}
	'dimgray':              SvgColor{105, 105, 105, 255}
	'dimgrey':              SvgColor{105, 105, 105, 255}
	'dodgerblue':           SvgColor{30, 144, 255, 255}
	'firebrick':            SvgColor{178, 34, 34, 255}
	'floralwhite':          SvgColor{255, 250, 240, 255}
	'forestgreen':          SvgColor{34, 139, 34, 255}
	'fuchsia':              SvgColor{255, 0, 255, 255}
	'gainsboro':            SvgColor{220, 220, 220, 255}
	'ghostwhite':           SvgColor{248, 248, 255, 255}
	'gold':                 SvgColor{255, 215, 0, 255}
	'goldenrod':            SvgColor{218, 165, 32, 255}
	'greenyellow':          SvgColor{173, 255, 47, 255}
	'honeydew':             SvgColor{240, 255, 240, 255}
	'hotpink':              SvgColor{255, 105, 180, 255}
	'indianred':            SvgColor{205, 92, 92, 255}
	'ivory':                SvgColor{255, 255, 240, 255}
	'khaki':                SvgColor{240, 230, 140, 255}
	'lavender':             SvgColor{230, 230, 250, 255}
	'lavenderblush':        SvgColor{255, 240, 245, 255}
	'lawngreen':            SvgColor{124, 252, 0, 255}
	'lemonchiffon':         SvgColor{255, 250, 205, 255}
	'lightblue':            SvgColor{173, 216, 230, 255}
	'lightcoral':           SvgColor{240, 128, 128, 255}
	'lightcyan':            SvgColor{224, 255, 255, 255}
	'lightgoldenrodyellow': SvgColor{250, 250, 210, 255}
	'lightgray':            SvgColor{211, 211, 211, 255}
	'lightgreen':           SvgColor{144, 238, 144, 255}
	'lightgrey':            SvgColor{211, 211, 211, 255}
	'lightpink':            SvgColor{255, 182, 193, 255}
	'lightsalmon':          SvgColor{255, 160, 122, 255}
	'lightseagreen':        SvgColor{32, 178, 170, 255}
	'lightskyblue':         SvgColor{135, 206, 250, 255}
	'lightslategray':       SvgColor{119, 136, 153, 255}
	'lightslategrey':       SvgColor{119, 136, 153, 255}
	'lightsteelblue':       SvgColor{176, 196, 222, 255}
	'lightyellow':          SvgColor{255, 255, 224, 255}
	'lime':                 SvgColor{0, 255, 0, 255}
	'limegreen':            SvgColor{50, 205, 50, 255}
	'linen':                SvgColor{250, 240, 230, 255}
	'maroon':               SvgColor{128, 0, 0, 255}
	'mediumaquamarine':     SvgColor{102, 205, 170, 255}
	'mediumblue':           SvgColor{0, 0, 205, 255}
	'mediumorchid':         SvgColor{186, 85, 211, 255}
	'mediumpurple':         SvgColor{147, 111, 219, 255}
	'mediumseagreen':       SvgColor{60, 179, 113, 255}
	'mediumslateblue':      SvgColor{123, 104, 238, 255}
	'mediumspringgreen':    SvgColor{0, 250, 154, 255}
	'mediumturquoise':      SvgColor{72, 209, 204, 255}
	'mediumvioletred':      SvgColor{199, 21, 133, 255}
	'midnightblue':         SvgColor{25, 25, 112, 255}
	'mintcream':            SvgColor{245, 255, 250, 255}
	'mistyrose':            SvgColor{255, 228, 225, 255}
	'moccasin':             SvgColor{255, 228, 181, 255}
	'navajowhite':          SvgColor{255, 222, 173, 255}
	'navy':                 SvgColor{0, 0, 128, 255}
	'oldlace':              SvgColor{253, 245, 230, 255}
	'olive':                SvgColor{128, 128, 0, 255}
	'olivedrab':            SvgColor{107, 142, 35, 255}
	'orangered':            SvgColor{255, 69, 0, 255}
	'orchid':               SvgColor{218, 112, 214, 255}
	'palegoldenrod':        SvgColor{238, 232, 170, 255}
	'palegreen':            SvgColor{152, 251, 152, 255}
	'paleturquoise':        SvgColor{175, 238, 238, 255}
	'palevioletred':        SvgColor{219, 112, 147, 255}
	'papayawhip':           SvgColor{255, 239, 213, 255}
	'peachpuff':            SvgColor{255, 218, 185, 255}
	'peru':                 SvgColor{205, 133, 63, 255}
	'plum':                 SvgColor{221, 160, 221, 255}
	'powderblue':           SvgColor{176, 224, 230, 255}
	'rebeccapurple':        SvgColor{102, 51, 153, 255}
	'rosybrown':            SvgColor{188, 143, 143, 255}
	'royalblue':            SvgColor{65, 105, 225, 255}
	'saddlebrown':          SvgColor{139, 69, 19, 255}
	'salmon':               SvgColor{250, 128, 114, 255}
	'sandybrown':           SvgColor{244, 164, 96, 255}
	'seagreen':             SvgColor{46, 139, 87, 255}
	'seashell':             SvgColor{255, 245, 238, 255}
	'sienna':               SvgColor{160, 82, 45, 255}
	'silver':               SvgColor{192, 192, 192, 255}
	'skyblue':              SvgColor{135, 206, 235, 255}
	'slateblue':            SvgColor{106, 90, 205, 255}
	'slategray':            SvgColor{112, 128, 144, 255}
	'slategrey':            SvgColor{112, 128, 144, 255}
	'snow':                 SvgColor{255, 250, 250, 255}
	'springgreen':          SvgColor{0, 255, 127, 255}
	'steelblue':            SvgColor{70, 130, 180, 255}
	'tan':                  SvgColor{210, 180, 140, 255}
	'teal':                 SvgColor{0, 128, 128, 255}
	'thistle':              SvgColor{216, 191, 216, 255}
	'tomato':               SvgColor{255, 99, 71, 255}
	'turquoise':            SvgColor{64, 224, 208, 255}
	'wheat':                SvgColor{245, 222, 179, 255}
	'whitesmoke':           SvgColor{245, 245, 245, 255}
	'yellowgreen':          SvgColor{154, 205, 50, 255}
}

// color_from_string returns an SvgColor for a named SVG color,
// or zero-value (transparent black) if not found.
fn color_from_string(s string) SvgColor {
	return string_colors[s]
}

// f32_abs returns absolute value.
@[inline]
fn f32_abs(x f32) f32 {
	return if x < 0 { -x } else { x }
}
