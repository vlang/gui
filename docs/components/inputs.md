# Input Controls

Capture user text and selection input.

## input

Single-line or multi-line text input field.

### Basic Usage

```v
import gui

struct App {
pub mut:
	name string
}

fn view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.input(
		text:            app.name
		placeholder:     'Enter name'
		on_text_changed: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[App]()
			app.name = e.text
		}
	)
}
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `text` | `string` | Current text value |
| `placeholder` | `string` | Hint when empty |
| `placeholder_active` | `bool` | Show placeholder when focused |
| `is_password` | `bool` | Hide text (password mode) |
| `multiline` | `bool` | Multi-line input |
| `max_len` | `int` | Maximum character count |
| `on_text_changed` | `fn` | Text change handler |

### Placeholder Text

Show hints when input is empty:

```oksyntax
gui.input(
	placeholder: 'Search...'
	text:        search_query
)
```

### Password Input

Hide sensitive text:

```oksyntax
gui.input(
	placeholder: 'Password'
	is_password: true
	text:        password
)
```

### Multi-line Input

Text area for longer content:

```oksyntax
gui.input(
	multiline:   true
	width:       400
	height:      200
	placeholder: 'Enter description...'
	text:        description
)
```

### Character Limit

Restrict input length:

```oksyntax
gui.input(
	max_len:     50
	placeholder: 'Max 50 characters'
	text:        bio
)
```

### Event Handling

Respond to text changes:

```oksyntax
gui.input(
	on_text_changed: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		app.search_query = e.text
		// Trigger search with new query
	}
)
```

## input_date

Date input with calendar picker.

### Basic Usage

```oksyntax
gui.input_date(
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

### Date Range

Limit selectable dates:

```oksyntax
gui.input_date(
	min_date: time.parse('2024-01-01')!
	max_date: time.parse('2024-12-31')!
	date:     current_date
)
```

## select

Dropdown selection list.

### Basic Usage

```v
import gui

struct App {
pub mut:
	country string
}

fn view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.select(
		options:   ['USA', 'Canada', 'Mexico', 'UK']
		selected:  app.country
		on_change: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
			mut app := w.state[App]()
			app.country = e.selected
		}
	)
}
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `options` | `[]string` | Selectable items |
| `selected` | `string` | Currently selected item |
| `placeholder` | `string` | Text when nothing selected |
| `on_change` | `fn` | Selection change handler |

### With Placeholder

```oksyntax
gui.select(
	options:     ['Small', 'Medium', 'Large', 'X-Large']
	placeholder: 'Select size...'
	selected:    selected_size
)
```

## Common Patterns

### Form with Validation

```v
import gui

struct App {
pub mut:
	email string
	valid bool
}

fn is_valid_email(email string) bool {
	return email.contains('@') && email.contains('.')
}

fn form_view(window &gui.Window) gui.View {
	app := window.state[App]()
	return gui.column(
		content: [
			gui.input(
				text:            app.email
				placeholder:     'Email'
				on_text_changed: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
					mut app := w.state[App]()
					app.email = e.text
					app.valid = is_valid_email(e.text)
				}
			),
			if !app.valid {
				gui.text(
					text:       'Invalid email'
					text_style: gui.TextStyle{
						...gui.theme().text_style
						color: gui.rgb(255, 59, 48)
					}
				)
			} else {
				gui.text(text: '')
			},
		]
	)
}
```

### Search Input with Icon

```oksyntax
gui.row(
	content: [
		gui.text(text: gui.icon_search, text_style: gui.theme().icon3),
		gui.input(
			placeholder: 'Search...'
			text:        search_query
		),
	]
)
```

### Settings Form

```oksyntax
gui.column(
	spacing: 15
	content: [
		gui.text(text: 'Profile Settings', text_style: gui.theme().b2),
		gui.input(placeholder: 'Name', text: name),
		gui.input(placeholder: 'Email', text: email),
		gui.select(
			placeholder: 'Country'
			options:     countries
			selected:    country
		),
		gui.input(
			multiline:   true
			height:      100
			placeholder: 'Bio'
			text:        bio
		),
	]
)
```

### Labeled Input

```v
import gui

gui.column(
	spacing: 5
	content: [
		gui.text(text: 'Username:', text_style: gui.theme().n4),
		gui.input(text: username),
	]
)
```

## Related Topics

- **[Events](../core/events.md)** - Event handling
- **[State Management](../core/state-management.md)** - Form state
- **[Buttons](buttons.md)** - Submit buttons
