# Components

v-gui provides 28+ UI components built from three primitives: containers,
text, and images. This reference covers all available components.

## Component Categories

### Containers
Organize and position child views.

- **[row](containers.md#row)** - Horizontal stacking
- **[column](containers.md#column)** - Vertical stacking  
- **[canvas](containers.md#canvas)** - Free-form positioning
- **[container](containers.md#container)** - Generic scrollable container

### Text and Images
Display content.

- **[text](text-and-images.md#text)** - Text rendering
- **[image](text-and-images.md#image)** - Image display
- **[rtf](text-and-images.md#rtf)** - Rich text (attributed strings)

### Input Controls
Capture user input.

- **[input](inputs.md#input)** - Text input field
- **[input_date](inputs.md#input-date)** - Date input
- **[select](inputs.md#select)** - Dropdown selection

### Buttons and Toggles
Interactive controls.

- **[button](buttons.md#button)** - Clickable button
- **[toggle](buttons.md#toggle)** - On/off switch
- **[switch](buttons.md#switch)** - Toggle switch variant
- **[radio](buttons.md#radio)** - Single option selection
- **[radio_button_group](buttons.md#radio-button-group)** - Grouped radio
  buttons

### Pickers and Sliders
Value selection.

- **[date_picker](pickers-and-sliders.md#date-picker)** - Date selection
  calendar
- **[range_slider](pickers-and-sliders.md#range-slider)** - Numeric range
  selection

### Lists and Tables
Data display.

- **[listbox](lists-and-tables.md#listbox)** - Scrollable item list
- **[table](lists-and-tables.md#table)** - Tabular data
- **[tree](lists-and-tables.md#tree)** - Hierarchical data

### Menus
Navigation.

- **[menu](menus.md#menu)** - Context menu
- **[menu_item](menus.md#menu-item)** - Individual menu entry
- **[menubar](menus.md#menubar)** - Application menu bar

### Dialogs and Panels
Overlays and expandable content.

- **[dialog](dialogs-and-panels.md#dialog)** - Modal dialog
- **[expand_panel](dialogs-and-panels.md#expand-panel)** - Collapsible
  panel
- **[tooltip](dialogs-and-panels.md#tooltip)** - Hover hint

### Indicators
Status display.

- **[progress_bar](indicators.md#progress-bar)** - Progress indication
- **[pulsar](indicators.md#pulsar)** - Loading indicator
- **[scrollbar](indicators.md#scrollbar)** - Scroll position

## Quick Reference Table

| Component | Category | Interactive | Container | Source File |
|-----------|----------|-------------|-----------|-------------|
| row | Container | No | Yes | view_container.v |
| column | Container | No | Yes | view_container.v |
| canvas | Container | No | Yes | view_container.v |
| container | Container | No | Yes | view_container.v |
| text | Content | No | No | view_text.v |
| image | Content | No | No | view_image.v |
| rtf | Content | No | No | view_rtf.v |
| input | Input | Yes | No | view_input.v |
| input_date | Input | Yes | No | view_input_date.v |
| select | Input | Yes | No | view_select.v |
| button | Button | Yes | Yes | view_button.v |
| toggle | Button | Yes | No | view_toggle.v |
| switch | Button | Yes | No | view_switch.v |
| radio | Button | Yes | No | view_radio.v |
| radio_button_group | Button | Yes | Yes | view_radio_button_group.v |
| date_picker | Picker | Yes | Yes | view_date_picker.v |
| range_slider | Picker | Yes | No | view_range_slider.v |
| listbox | List | Yes | Yes | view_listbox.v |
| table | List | Yes | Yes | view_table.v |
| tree | List | Yes | Yes | view_tree.v |
| menu | Menu | Yes | Yes | view_menu.v |
| menu_item | Menu | Yes | No | view_menu_item.v |
| menubar | Menu | Yes | Yes | view_menubar.v |
| dialog | Overlay | Yes | Yes | view_dialog.v |
| expand_panel | Panel | Yes | Yes | view_expand_panel.v |
| tooltip | Overlay | No | Yes | view_tooltip.v |
| progress_bar | Indicator | No | No | view_progress_bar.v |
| pulsar | Indicator | No | No | view_pulsar.v |
| scrollbar | Indicator | Yes | No | view_scrollbar.v |

## Common Properties

Most components share these properties:

### Layout
- `width`, `height` - Dimensions in logical pixels
- `sizing` - Sizing mode (fit/fill/fixed)
- `h_align`, `v_align` - Alignment

### Styling
- `style` - Component-specific style struct
- `color` - Primary color
- `padding` - Inner margin
- `radius` - Corner radius

### Interaction
- `disabled` - Disable interaction
- `invisible` - Hide component
- `id_focus` - Focus order for keyboard navigation

### Events
- `on_click` - Click handler
- `on_key_down`, `on_key_up` - Keyboard handlers
- Component-specific handlers (e.g., `on_text_changed` for input)

## Usage Patterns

### Creating Components

All components are created via factory functions:

```v
import gui

gui.button(
	content:  [gui.text(text: 'Click Me')]
	on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		println('Clicked!')
	}
)
```

### Nesting Components

Containers hold other components:

```v
import gui

gui.column(
	content: [
		gui.text(text: 'Header'),
		gui.row(
			content: [
				gui.button(content: [gui.text(text: 'OK')]),
				gui.button(content: [gui.text(text: 'Cancel')]),
			]
		),
	]
)
```

### Styling Components

Override component styles:

```v
import gui

gui.button(
	content: [gui.text(text: 'Primary')]
	style:   gui.ButtonStyle{
		...gui.theme().button_style
		color_background: gui.rgb(0, 120, 255)
	}
)
```

## Related Topics

- **[Views](../core/views.md)** - View system fundamentals
- **[Layout](../core/layout.md)** - Layout principles
- **[Themes](../core/themes.md)** - Component styling
- **[Events](../core/events.md)** - Event handling
