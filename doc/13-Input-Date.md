# 13 Input Date

The `input_date` view combines an `input` field with a `date_picker` to
create a user-friendly date entry component. It displays the selected
date in the input field and shows a calendar for selection when the user
clicks the calendar icon.

- Widget: `input_date`
- Config: `InputDateCfg`
- Callback: `on_select([]time.Time, mut Event, mut Window)`

## Quick start

Here's how to create a simple date input field:

```v
import gui
import time

struct App {
mut:
	appointment time.Time // initial time.Time value from your app state
}

mut app := App{}
mut window := gui.window(title: 'hello')

// inside your main view function
window.input_date(
	id:        'appointment_date'
	date:      app.appointment // initial time.Time value from your app state
	on_select: fn (times []time.Time, mut _ gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		if times.len > 0 {
			app.appointment = times[0]
		}
	}
)
```

## `input_date`

This function creates the date input view. It internally manages the
visibility of the floating `date_picker`.

``` v
fn (mut window gui.Window) input_date(cfg gui.InputDateCfg) gui.View
```

The view is composed of:

- An `input` view that displays the formatted date.
- A calendar `icon` within the input. - A floating `date_picker` view
  that appears below the input when the icon is clicked.

## `InputDateCfg`

This struct configures the `input_date` view. It shares many properties
with `DatePickerCfg` and `InputCfg`.

``` v
import time

@[heap]
pub struct InputDateCfg {
pub:
	id          string @[required]
	date        time.Time = time.now()
	placeholder string
	on_select   fn ([]time.Time, mut Event, mut Window) = unsafe { nil }
	on_enter    fn (&Layout, mut Event, mut Window)        = unsafe { nil }

	// Date Picker Options
	allowed_weekdays         []DatePickerWeekdays
	allowed_months           []DatePickerMonths
	allowed_years            []int
	allowed_dates            []time.Time
	weekdays_len             DatePickerWeekdayLen = gui_theme.date_picker_style.weekdays_len
	select_multiple          bool
	hide_today_indicator     bool = gui_theme.date_picker_style.hide_today_indicator
	monday_first_day_of_week bool = gui_theme.date_picker_style.monday_first_day_of_week
	show_adjacent_months     bool = gui_theme.date_picker_style.show_adjacent_months

	// Sizing and Layout
	sizing     Sizing
	width      f32
	height     f32
	min_width  f32
	min_height f32
	max_width  f32
	max_height f32

	// Styling
	text_style         TextStyle = gui_theme.date_picker_style.text_style
	placeholder_style  TextStyle = gui_theme.input_style.placeholder_style
	color              Color     = gui_theme.date_picker_style.color
	color_hover        Color     = gui_theme.date_picker_style.color_hover
	color_focus        Color     = gui_theme.date_picker_style.color_focus
	color_click        Color     = gui_theme.date_picker_style.color_click
	color_border       Color     = gui_theme.date_picker_style.color_border
	color_border_focus Color     = gui_theme.date_picker_style.color_border_focus
	color_select       Color     = gui_theme.date_picker_style.color_select
	padding            Padding   = gui_theme.date_picker_style.padding
	padding_border     Padding   = gui_theme.date_picker_style.padding_border
	radius             f32       = gui_theme.date_picker_style.radius
	radius_border      f32       = gui_theme.date_picker_style.radius_border
	fill               bool      = gui_theme.date_picker_style.fill
	fill_border        bool      = gui_theme.date_picker_style.fill_border

	// General
	id_focus  u32
	disabled  bool
	invisible bool
}
```

Key points:

- The `date` field holds the currently selected `time.Time`.
- The `on_select` callback is triggered when a user picks a date from
  the calendar. This is where you should update your application's
  state.
- The `on_enter` callback is tied to the input field, allowing actions
  when the user presses the Enter key.
- Most of the date-picker-specific configurations (like
  `allowed_weekdays`, `select_multiple`, etc.) are passed directly to
  the underlying `date_picker` view.
- Styling properties are inherited from the theme's `input_style` and
  `date_picker_style`.

## Events

- `on_select(times, mut e, mut w)`: Fires when a date is chosen in the
  calendar. `times` is an array of selected `time.Time` values.
- `on_enter(layout, mut e, w)`: Fires when the Enter key is pressed
  while the input field has focus.

## Related Examples

- `examples/date_time.v` --- showcases `input_date` in action.