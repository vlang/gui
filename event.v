module gui

import gg

const bsp_char = 0x08
const del_char = 0x7F
const space_char = 0x20
const escape_char = 0x1B
const lf_char = 0x0A
const cr_char = 0x0D
const cmd_a = 0x61
const cmd_c = 0x63
const cmd_v = 0x76
const cmd_x = 0x78
const cmd_z = 0x7A
const ctrl_a = 0x01
const ctrl_c = 0x03
const ctrl_v = 0x16
const ctrl_x = 0x18
const ctrl_z = 0x1A

fn from_gg_event(e &gg.Event) &Event {
	return &Event{
		frame_count:        e.frame_count
		typ:                EventType(e.typ)
		key_code:           KeyCode(e.key_code)
		char_code:          e.char_code
		key_repeat:         e.key_repeat
		modifiers:          unsafe { Modifier(e.modifiers) }
		mouse_button:       MouseButton(e.mouse_button)
		mouse_x:            e.mouse_x
		mouse_y:            e.mouse_y
		mouse_dx:           e.mouse_dx
		mouse_dy:           e.mouse_dy
		scroll_x:           e.scroll_x
		scroll_y:           e.scroll_y
		num_touches:        e.num_touches
		touches:            e.touches.map(fn (tp gg.TouchPoint) TouchPoint {
			return from_gg_touchpoint(tp)
		})
		window_width:       e.window_width
		window_height:      e.window_height
		framebuffer_width:  e.framebuffer_width
		framebuffer_height: e.framebuffer_height
	}
}

fn event_relative_to(shape &Shape, e &Event) &Event {
	return &Event{
		...e
		touches: e.touches // runtime mem error otherwise
		mouse_x: e.mouse_x - shape.x
		mouse_y: e.mouse_y - shape.y
	}
}

@[minify]
pub struct Event {
pub mut:
	touches            [8]TouchPoint
	frame_count        u64
	mouse_x            f32
	mouse_y            f32
	mouse_dx           f32
	mouse_dy           f32
	scroll_x           f32
	scroll_y           f32
	modifiers          Modifier
	char_code          u32
	num_touches        int
	window_width       int
	window_height      int
	framebuffer_width  int
	framebuffer_height int
	typ                EventType
	key_code           KeyCode
	mouse_button       MouseButton
	key_repeat         bool
	is_handled         bool
}

pub enum EventType as u8 {
	invalid
	key_down
	key_up
	char
	mouse_down
	mouse_up
	mouse_scroll
	mouse_move
	mouse_enter
	mouse_leave
	touches_began
	touches_moved
	touches_ended
	touches_cancelled
	resized
	iconified
	restored
	focused
	unfocused
	suspended
	resumed
	quit_requested
	clipboard_pasted
	files_dropped
	num
}

pub enum MouseButton as u16 {
	left    = 0
	right   = 1
	middle  = 2
	invalid = 256
}

pub enum MouseCursor as u8 {
	default       = C.SAPP_MOUSECURSOR_DEFAULT
	arrow         = C.SAPP_MOUSECURSOR_ARROW
	ibeam         = C.SAPP_MOUSECURSOR_IBEAM
	crosshair     = C.SAPP_MOUSECURSOR_CROSSHAIR
	pointing_hand = C.SAPP_MOUSECURSOR_POINTING_HAND
	resize_ew     = C.SAPP_MOUSECURSOR_RESIZE_EW
	resize_ns     = C.SAPP_MOUSECURSOR_RESIZE_NS
	resize_nwse   = C.SAPP_MOUSECURSOR_RESIZE_NWSE
	resize_nesw   = C.SAPP_MOUSECURSOR_RESIZE_NESW
	resize_all    = C.SAPP_MOUSECURSOR_RESIZE_ALL
	not_allowed   = C.SAPP_MOUSECURSOR_NOT_ALLOWED
}

pub enum Modifier as u32 {
	none           = 0
	shift          = 1 //(1<<0)
	ctrl           = 2 //(1<<1)
	alt            = 4 //(1<<2)
	super          = 8 //(1<<3)
	lmb            = 0x100
	rmb            = 0x200
	mmb            = 0x400
	ctrl_shift     = 2 | 1
	ctrl_alt       = 2 | 4
	ctrl_alt_shift = 2 | 4 | 1
	ctrl_super     = 2 | 8
	alt_shift      = 4 | 1
	alt_super      = 4 | 8
	super_shift    = 8 | 1
}

// has checks if the current modifier bitmask contains the specified modifier.
pub fn (m Modifier) has(modifier Modifier) bool {
	return u32(m) & u32(modifier) > 0 || m == modifier // .none case
}

// has_any checks if the current modifier bitmask contains at least one of the specified modifiers.
pub fn (m Modifier) has_any(modifiers ...Modifier) bool {
	return modifiers.any(u32(m) & u32(it) > 0 || m == it) // .none case
}

pub enum KeyCode as u16 {
	invalid       = 0
	space         = 32
	apostrophe    = 39 //'
	comma         = 44 //,
	minus         = 45 //-
	period        = 46 //.
	slash         = 47 ///
	_0            = 48
	_1            = 49
	_2            = 50
	_3            = 51
	_4            = 52
	_5            = 53
	_6            = 54
	_7            = 55
	_8            = 56
	_9            = 57
	semicolon     = 59 //;
	equal         = 61 //=
	a             = 65
	b             = 66
	c             = 67
	d             = 68
	e             = 69
	f             = 70
	g             = 71
	h             = 72
	i             = 73
	j             = 74
	k             = 75
	l             = 76
	m             = 77
	n             = 78
	o             = 79
	p             = 80
	q             = 81
	r             = 82
	s             = 83
	t             = 84
	u             = 85
	v             = 86
	w             = 87
	x             = 88
	y             = 89
	z             = 90
	left_bracket  = 91  //[
	backslash     = 92  //\
	right_bracket = 93  //]
	grave_accent  = 96  //`
	world_1       = 161 // non-us #1
	world_2       = 162 // non-us #2
	escape        = 256
	enter         = 257
	tab           = 258
	backspace     = 259
	insert        = 260
	delete        = 261
	right         = 262
	left          = 263
	down          = 264
	up            = 265
	page_up       = 266
	page_down     = 267
	home          = 268
	end           = 269
	caps_lock     = 280
	scroll_lock   = 281
	num_lock      = 282
	print_screen  = 283
	pause         = 284
	f1            = 290
	f2            = 291
	f3            = 292
	f4            = 293
	f5            = 294
	f6            = 295
	f7            = 296
	f8            = 297
	f9            = 298
	f10           = 299
	f11           = 300
	f12           = 301
	f13           = 302
	f14           = 303
	f15           = 304
	f16           = 305
	f17           = 306
	f18           = 307
	f19           = 308
	f20           = 309
	f21           = 310
	f22           = 311
	f23           = 312
	f24           = 313
	f25           = 314
	kp_0          = 320
	kp_1          = 321
	kp_2          = 322
	kp_3          = 323
	kp_4          = 324
	kp_5          = 325
	kp_6          = 326
	kp_7          = 327
	kp_8          = 328
	kp_9          = 329
	kp_decimal    = 330
	kp_divide     = 331
	kp_multiply   = 332
	kp_subtract   = 333
	kp_add        = 334
	kp_enter      = 335
	kp_equal      = 336
	left_shift    = 340
	left_control  = 341
	left_alt      = 342
	left_super    = 343
	right_shift   = 344
	right_control = 345
	right_alt     = 346
	right_super   = 347
	menu          = 348
}

// TouchToolType is an Android specific 'tool type' enum for touch events.
// This lets the application check what type of input device was used for touch events.
// NOTE: the values must remain in sync with the corresponding Android SDK type, so don't change those.
// See https://developer.android.com/reference/android/view/MotionEvent#TOOL_TYPE_UNKNOWN
pub enum TouchToolType as u8 {
	unknown
	finger
	stylus
	mouse
	eraser
	palm
}

pub struct TouchPoint {
pub:
	identifier       u64
	pos_x            f32
	pos_y            f32
	android_tooltype TouchToolType
	changed          bool
}

fn from_gg_touchpoint(tp &gg.TouchPoint) TouchPoint {
	return TouchPoint{
		identifier:       tp.identifier
		pos_x:            tp.pos_x
		pos_y:            tp.pos_y
		android_tooltype: TouchToolType(tp.android_tooltype)
		changed:          tp.changed
	}
}

pub fn (e &Event) str() string {
	return 'Event{
	frame_count: ${e.frame_count}
	typ: ${e.typ}
	key_code: ${e.key_code}
	char_code: ${e.char_code}
	key_repeat: ${e.key_repeat}
	modifiers: ${e.modifiers}
	mouse_button: ${e.mouse_button}
	mouse_x: ${e.mouse_x}
	mouse_y: ${e.mouse_y}
	mouse_dx: ${e.mouse_dx}
	mouse_dy: ${e.mouse_dy}
	scroll_x: ${e.scroll_x}
	scroll_y: ${e.scroll_y}
	num_touches: ${e.num_touches}
	window_width: ${e.window_width}
	window_height: ${e.window_height}
	framebuffer_width: ${e.framebuffer_width}
	framebuffer_height: ${e.framebuffer_height}
	is_handled: ${e.is_handled}
}'
}

// spacebar_to_click creates an on_char handler that fires on_click when
// spacebar is pressed. Enables keyboard activation for clickable elements.
fn spacebar_to_click(on_click fn (&Layout, mut Event, mut Window)) fn (&Layout, mut Event, mut Window) {
	if on_click == unsafe { nil } {
		return fn (_ &Layout, mut _ Event, mut _ Window) {}
	}
	return fn [on_click] (layout &Layout, mut e Event, mut w Window) {
		if e.char_code == ` ` {
			on_click(layout, mut e, mut w)
			e.is_handled = true
		}
	}
}

// left_click_only wraps a click handler to only fire on left mouse button.
fn left_click_only(on_click fn (&Layout, mut Event, mut Window)) fn (&Layout, mut Event, mut Window) {
	if on_click == unsafe { nil } {
		return on_click
	}
	return fn [on_click] (layout &Layout, mut e Event, mut w Window) {
		if e.mouse_button == .left {
			on_click(layout, mut e, mut w)
		}
	}
}
