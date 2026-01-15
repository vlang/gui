# Pickers and Sliders

Value selection controls for dates and numeric ranges.

## date_picker

Calendar widget for date selection.

### Basic Usage

```oksyntax
gui.date_picker(
	date:      selected_date
	on_change: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		app.selected_date = e.date
	}
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `date` | `time.Time` | Selected date |
| `min_date` | `time.Time` | Earliest selectable date |
| `max_date` | `time.Time` | Latest selectable date |
| `on_change` | `fn` | Date change handler |

### Date Constraints

Limit selectable date range:

```oksyntax
gui.date_picker(
	date:      booking_date
	min_date:  time.now()
	max_date:  time.now().add_days(90)
	on_change: handle_date_change
)
```

### Use Cases

- Appointment booking
- Event scheduling
- Date filtering
- Birth date input

## range_slider

Slider for selecting numeric values or ranges.

### Basic Usage (Single Value)

```oksyntax
gui.range_slider(
	min:       0
	max:       100
	value:     volume
	on_change: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		app.volume = e.value
	}
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `min` | `f32` | Minimum value |
| `max` | `f32` | Maximum value |
| `value` | `f32` | Current value (single) |
| `range_start` | `f32` | Range start (range mode) |
| `range_end` | `f32` | Range end (range mode) |
| `step` | `f32` | Value increment |
| `on_change` | `fn` | Value change handler |

### Range Mode

Select a range between two values:

```oksyntax
gui.range_slider(
	min:         0
	max:         1000
	range_start: price_min
	range_end:   price_max
	on_change:   fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		app.price_min = e.range_start
		app.price_max = e.range_end
	}
)
```

### Step Increments

Snap to specific values:

```oksyntax
gui.range_slider(
	min:   0
	max:   10
	step:  0.5  // Values: 0, 0.5, 1, 1.5, ...
	value: rating
)
```

### With Label

```v
import gui

gui.column(
	spacing: 5
	content: [
		gui.text(text: 'Volume: ${volume}%'),
		gui.range_slider(
			min:   0
			max:   100
			value: volume
		),
	]
)
```

## Common Patterns

### Volume Control

```v
import gui

struct App {
pub mut:
	volume int = 50
}

fn volume_control(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.row(
		spacing: 10
		content: [
			gui.text(text: gui.icon_volume, text_style: gui.theme().icon3),
			gui.range_slider(
				min:       0
				max:       100
				value:     f32(app.volume)
				on_change: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.volume = int(e.value)
				}
			),
			gui.text(text: '${app.volume}%'),
		]
	)
}
```

### Price Range Filter

```oksyntax
gui.column(
	spacing: 10
	content: [
		gui.text(text: 'Price Range: \$${price_min} - \$${price_max}'),
		gui.range_slider(
			min:         0
			max:         1000
			range_start: price_min
			range_end:   price_max
		),
	]
)
```

### Date Range Picker

```oksyntax
gui.column(
	spacing: 15
	content: [
		gui.column(
			spacing: 5
			content: [
				gui.text(text: 'Start Date'),
				gui.date_picker(date: start_date),
			]
		),
		gui.column(
			spacing: 5
			content: [
				gui.text(text: 'End Date'),
				gui.date_picker(date: end_date),
			]
		),
	]
)
```

### Rating Slider

```oksyntax
gui.column(
	spacing: 5
	content: [
		gui.text(text: 'Rating: ${rating} / 5'),
		gui.range_slider(
			min:   0
			max:   5
			step:  0.5
			value: rating
		),
	]
)
```

### Brightness Control

```oksyntax
gui.column(
	spacing: 5
	content: [
		gui.row(content: [
			gui.text(text: 'Brightness'),
			gui.text(text: '${int(brightness * 100)}%'),
		]),
		gui.range_slider(
			min:   0
			max:   1
			step:  0.01
			value: brightness
		),
	]
)
```

## Related Topics

- **[Inputs](inputs.md)** - Text input controls
- **[State Management](../core/state-management.md)** - Managing values
- **[Events](../core/events.md)** - Change event handling
