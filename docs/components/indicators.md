# Indicators

Display progress and status.

## progress_bar

Visual progress indicator.

### Basic Usage

```v
import gui

struct App_16 {
pub mut:
	progress f32 = 0.5
}

fn view(window &gui.Window) gui.View {
	app := window.state[App_16]()
	return gui.progress_bar(
		percent: app.progress // 0.0 to 1.0
	)
}
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `progress` | `f32` | Progress value (0-1) |
| `indeterminate` | `bool` | Unknown progress mode |
| `width` | `f32` | Bar width |

### Indeterminate Progress

For tasks with unknown duration:

```oksyntax
gui.progress_bar(
	indeterminate: true
	width:         300
)
```

### With Label

```oksyntax
import gui

gui.column(
	spacing: 5
	content: [
		gui.text(text: 'Loading: ${int(progress * 100)}%'),
		gui.progress_bar(percent: progress),
	]
)
```

## pulsar

Loading spinner animation.

### Basic Usage

```oksyntax
import gui

window.pulsar(
	size: 40
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `size` | `f32` | Spinner diameter |
| `color` | `Color` | Spinner color |

### Centered Loading

```oksyntax
gui.column(
	h_align: .center
	v_align: .middle
	content: [
		gui.pulsar(size: 60),
		gui.text(text: 'Loading...'),
	]
)
```

## scrollbar

Scroll position indicator.

### Basic Usage

Scrollbars are automatically added to scrollable containers:

```oksyntax
gui.container(
	id_scroll:  1
	width:      300
	height:     400
	content:    [large_content]
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `position` | `f32` | Scroll position (0-1) |
| `size` | `f32` | Scrollbar size |
| `visible` | `bool` | Always visible vs auto-hide |

## Common Patterns

### File Upload Progress

```v
import gui

struct App_17 {
pub mut:
	upload_progress f32
	file_name       string
}

fn upload_view(window &gui.Window) gui.View {
	app := window.state[App_17]()
	return gui.column(
		spacing: 10
		content: [
			gui.text(text: 'Uploading: ${app.file_name}'),
			gui.progress_bar(percent: app.upload_progress),
			gui.text(text: '${int(app.upload_progress * 100)}%'),
		]
	)
}
```

### Loading Overlay

```oksyntax
if is_loading {
	gui.column(
		h_align: .center
		v_align: .middle
		fill:    true
		color:   gui.rgba(0, 0, 0, 128) // Semi-transparent
		content: [
			gui.pulsar(size: 60),
			gui.text(
				text:       'Please wait...'
				text_style: gui.TextStyle{
					...gui.theme().text_style
					color: gui.rgb(255, 255, 255)
				}
			),
		]
	)
} else {
	main_content()
}
```

### Step Progress

```v
import gui

struct App_18 {
pub mut:
	current_step int
	total_steps  int = 5
}

fn wizard_view(window &gui.Window) gui.View {
	app := window.state[App_18]()
	progress := f32(app.current_step) / f32(app.total_steps)
	return gui.column(
		spacing: 15
		content: [
			gui.text(text: 'Step ${app.current_step} of ${app.total_steps}'),
			gui.progress_bar(percent: progress),
		]
	)
}
```

### Infinite Loading

```oksyntax
gui.row(
	spacing: 10
	content: [
		gui.pulsar(size: 20),
		gui.text(text: 'Fetching data...'),
	]
)
```

## Related Topics

- **[State Management](../core/state-management.md)** - Progress tracking
- **[Containers](containers.md)** - Scrollable containers
- **[Themes](../core/themes.md)** - Progress bar styling
