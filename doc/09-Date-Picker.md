# 9 Date Picker

The `date_picker` view provides a calendar-based UI for selecting one or
more dates. It includes month navigation, an optional year/month picker,
weekday labels in different formats, and rich constraints to allow or
disallow specific days, months, years, or exact dates.

- Widget: `date_picker`
- Config: `DatePickerCfg`
- Enums: `DatePickerWeekdays`, `DatePickerMonths`,
  `DatePickerWeekdayLen`
- Callback: `on_select([]time.Time, mut Event, mut Window)`

## Quick start

```v
import gui
import time

mut window := gui.Window{}

// inside your main view function
window.date_picker(
	id:        'dob'
	dates:     [time.now()] // initial selection(s)
	on_select: fn (times []time.Time, mut _ gui.Event, mut _ gui.Window) {
		// handle selection(s)
		// times is a list; when select_multiple is false, it has 1 item
	}
)
```

## `date_picker`

Creates a date-picker view from the given `DatePickerCfg`.

```oksyntax
fn (mut window gui.Window) date_picker(cfg gui.DatePickerCfg) gui.View
```

The widget renders:

- Controls row: current month/year button (opens year/month picker), previous and
  next month buttons
- Body: either the month grid (calendar) or the year/month picker when toggled

## `DatePickerCfg`

Configures the `date_picker` view.

```v
import gui
import time

struct DatePickerCfg {
	id    string      // required; unique among date pickers
	dates []time.Time // required; initial/current selection(s)

	// Constraints (any that are non-empty will be enforced)
	allowed_weekdays []gui.DatePickerWeekdays // allowed days of week
	allowed_months   []gui.DatePickerMonths   // allowed months
	allowed_years    []int                    // allowed years
	allowed_dates    []time.Time              // allow only these exact dates

	// Selection
	select_multiple bool // select multiple dates by toggling

	// Appearance & behavior
	weekdays_len       gui.DatePickerWeekdayLen = gui_theme.date_picker_style.weekdays_len
	text_style         gui.TextStyle            = gui_theme.date_picker_style.text_style
	color              gui.Color                = gui_theme.date_picker_style.color
	color_hover        gui.Color                = gui_theme.date_picker_style.color_hover
	color_focus        gui.Color                = gui_theme.date_picker_style.color_focus
	color_click        gui.Color                = gui_theme.date_picker_style.color_click
	color_border       gui.Color                = gui_theme.date_picker_style.color_border
	color_border_focus gui.Color                = gui_theme.date_picker_style.color_border_focus
	color_select       gui.Color                = gui_theme.date_picker_style.color_select
	padding            gui.Padding              = gui_theme.date_picker_style.padding
	padding_border     gui.Padding              = gui_theme.date_picker_style.padding_border
	cell_spacing       f32                      = gui_theme.date_picker_style.cell_spacing
	radius             f32                      = gui_theme.date_picker_style.radius
	radius_border      f32                      = gui_theme.date_picker_style.radius_border
	fill               bool                     = gui_theme.date_picker_style.fill
	fill_border        bool                     = gui_theme.date_picker_style.fill_border

	// Calendar UI behavior
	hide_today_indicator     bool = gui_theme.date_picker_style.hide_today_indicator
	monday_first_day_of_week bool = gui_theme.date_picker_style.monday_first_day_of_week
	show_adjacent_months     bool = gui_theme.date_picker_style.show_adjacent_months

	// Scrolling id for the year-month picker
	id_scroll u32 = u32(459342148)

	// General
	disabled  bool
	invisible bool

	// Callback
	on_select fn ([]time.Time, mut gui.Event, mut gui.Window) = unsafe { nil }
}
```

Notes:

- `dates` represents the active selection(s). When `select_multiple` is `false` (default),  
  only the first element is used.
- When `show_adjacent_months` is `true`, days from previous/next months are displayed as
  empty or grayed cells to keep a 6-row grid consistent.
- The current day gets a border indicator unless `hide_today_indicator` is `true`.
- The month/year display button toggles a year--month picker where you can jump
  across years and months quickly.

## Enums

### `DatePickerWeekdays`

```v
enum DatePickerWeekdays as u8 {
	monday = 1
	tuesday
	wednesday
	thursday
	friday
	saturday
	sunday
}
```

Used by `allowed_weekdays` to limit selectable days of week.

### `DatePickerMonths`

```v
enum DatePickerMonths as u16 {
	january = 1
	february
	march
	april
	may
	june
	july
	august
	september
	october
	november
	december
}
```

Used by `allowed_months` and in the year--month picker.

### `DatePickerWeekdayLen`

```v
enum DatePickerWeekdayLen as u8 {
	one_letter   // e.g. S, M, T, W, T, F, S
	three_letter // e.g. Sun, Mon, Tue, ...
	full         // e.g. Sunday, Monday, ...
}
```

Controls how weekday labels are rendered in the header.

## Events

- `on_select(times, mut e, mut w)` --- called when the user selects a
  date.
  - `times` contains the current selection(s) as normalized `time.Time`
    values (day/month/year only).
  - For single selection (`select_multiple: false`), use `times[0]`.
  - Set `e.is_handled = true` if you fully handle the event.

Example:

```v
import gui
import time

mut window := gui.Window{}

window.date_picker(
	id:        'birthday'
	dates:     [time.new(day: 1, month: 1, year: 2000)]
	on_select: fn (times []time.Time, mut e gui.Event, mut _ gui.Window) {
		println('Selected: ${times}')
		e.is_handled = true
	}
)
```

## Constraints and disabling

The picker computes whether a cell is disabled based on these fields
(first matching rule applies, and any mismatch disables the date):

- `allowed_weekdays`: only these weekdays are enabled.
- `allowed_months`: only these months are enabled. Applies both to the
  month grid and to the year--month picker buttons.
- `allowed_years`: only these years are enabled in the year--month
  picker and for the current view.
- `allowed_dates`: only these exact dates are enabled; everything else
  is disabled.

If none of the `allowed_*` lists are provided, all dates in the current
month are enabled.

## Layout and sizing

- The widget is wrapped in a border container: `fill_border`,
  `color_border`, `padding_border`, `radius_border` control its
  appearance.
- The interior uses `fill`, `color`, `padding`, and `radius`.
- Cell size is derived from `text_style` and `weekdays_len` to ensure
  labels fit, with spacing controlled by `cell_spacing`.
- The year--month picker preserves the overall width/height calculated
  from the calendar view so that toggling pickers does not change the
  widget size.
- Alignment and sizing can be controlled by embedding the picker inside
  `row`/`column` containers like any other view.

## Styling

The date picker inherits its defaults from
`gui_theme.date_picker_style`. You can override colors, text style,
padding, and radii via `DatePickerCfg` fields.

Common overrides:

```v
import gui
import time

mut window := gui.Window{}

window.date_picker(
	id:                       'custom'
	dates:                    [time.now()]
	color_select:             gui.rgb(52, 120, 246)
	weekdays_len:             .three_letter
	monday_first_day_of_week: true
)
```

## Multiple selection

Enable `select_multiple: true` to allow toggling any number of dates.
Clicking a selected date will remove it from the selection.

```v
import gui
import time

mut window := gui.Window{}

window.date_picker(
	id:              'multi'
	dates:           [time.now()]
	select_multiple: true
	on_select:       fn (times []time.Time, mut _ gui.Event, mut _ gui.Window) {
		println('Selected dates: ${times}')
	}
)
```

## Practical examples

- Basic single-date picker:

```v
import gui
import time

mut window := gui.Window{}

window.date_picker(id: 'dp1', dates: [time.now()])
```

- Only allow weekdays (Mon--Fri), show adjacent month day numbers, and
  start weeks on Monday:

```v
import gui
import time

mut window := gui.Window{}

window.date_picker(
	id:                       'work'
	dates:                    [time.now()]
	allowed_weekdays:         [.monday, .tuesday, .wednesday, .thursday, .friday]
	show_adjacent_months:     true
	monday_first_day_of_week: true
)
```

- Year/month constraints and exact allowed dates:

```v
import gui
import time

mut window := gui.Window{}
now := time.now()

window.date_picker(
	id:             'limited'
	dates:          [now]
	allowed_months: [.june, .july, .august]
	allowed_years:  [now.year, now.year + 1]
	allowed_dates:  [time.new(day: 1, month: now.month, year: now.year)]
)
```

## Related examples

- `examples/date_picker_options.v` --- interactive demo showing all
  options
- `examples/date_time.v` --- showcases date/time input integration

## Related source

- `view_date_picker.v` --- `date_picker`, `DatePickerCfg`,
  `DatePickerWeekdays`, `DatePickerMonths`, `DatePickerWeekdayLen`
- `view_input_date.v` --- input field that uses the date picker
- `view_button.v`, `view_container.v` --- building blocks used by the
  picker
- `layout.v` --- layout engine used for size/positioning