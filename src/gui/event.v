module gui

import gg
import sokol.sapp

fn from_gg_event(e &gg.Event) &Event {
	return &Event{
		frame_count:        e.frame_count
		typ:                e.typ
		key_code:           KeyCode(e.key_code)
		char_code:          e.char_code
		key_repeat:         e.key_repeat
		modifiers:          e.modifiers
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

pub struct Event {
pub mut:
	frame_count        u64
	typ                sapp.EventType
	key_code           KeyCode
	char_code          u32
	key_repeat         bool
	modifiers          u32
	mouse_button       MouseButton
	mouse_x            f32
	mouse_y            f32
	mouse_dx           f32
	mouse_dy           f32
	scroll_x           f32
	scroll_y           f32
	num_touches        int
	touches            [8]TouchPoint
	window_width       int
	window_height      int
	framebuffer_width  int
	framebuffer_height int
}

pub enum EventType {
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

pub enum MouseButton {
	invalid = -1
	left    = 0
	right   = 1
	middle  = 2
}

pub enum MouseCursor {
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

pub enum Modifier {
	shift = 1 //(1<<0)
	ctrl  = 2 //(1<<1)
	alt   = 4 //(1<<2)
	super = 8 //(1<<3)
	lmb   = 0x100
	rmb   = 0x200
	mmb   = 0x400
}

pub enum KeyCode {
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
pub enum TouchToolType {
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
