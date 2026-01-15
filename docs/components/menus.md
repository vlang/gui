# Menus

Application and context menus.

## menu

Context menu with items and submenus.

### Basic Usage

```oksyntax
gui.menu(
	items: [
		gui.menu_item(label: 'Copy', on_click: handle_copy),
		gui.menu_item(label: 'Paste', on_click: handle_paste),
		gui.menu_item(label: 'Delete', on_click: handle_delete),
	]
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `items` | `[]View` | Menu items |
| `float` | `bool` | Float over content |
| `visible` | `bool` | Show/hide menu |

### With Submenus

```oksyntax
gui.menu(
	items: [
		gui.menu_item(
			label:   'File'
			submenu: gui.menu(items: [
				gui.menu_item(label: 'New'),
				gui.menu_item(label: 'Open'),
			])
		),
	]
)
```

## menu_item

Individual menu entry.

### Basic Usage

```oksyntax
gui.menu_item(
	label:    'Save'
	shortcut: 'Ctrl+S'
	on_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		save_document()
	}
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `label` | `string` | Item label |
| `shortcut` | `string` | Keyboard shortcut |
| `icon` | `string` | Icon glyph |
| `disabled` | `bool` | Disable item |
| `checked` | `bool` | Checkmark state |
| `on_click` | `fn` | Click handler |

### With Icon

```oksyntax
gui.menu_item(
	icon:     gui.icon_save
	label:    'Save'
	shortcut: 'Ctrl+S'
)
```

### Separator

```oksyntax
gui.menu_item(separator: true)
```

## menubar

Application menu bar.

### Basic Usage

```oksyntax
gui.menubar(
	items: [
		gui.menu_item(
			label:   'File'
			submenu: file_menu
		),
		gui.menu_item(
			label:   'Edit'
			submenu: edit_menu
		),
	]
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `items` | `[]View` | Top-level menu items |

## Common Patterns

### Context Menu

```oksyntax
gui.menu(
	float:   true
	visible: show_context_menu
	items:   [
		gui.menu_item(label: 'Cut', shortcut: 'Ctrl+X'),
		gui.menu_item(label: 'Copy', shortcut: 'Ctrl+C'),
		gui.menu_item(label: 'Paste', shortcut: 'Ctrl+V'),
		gui.menu_item(separator: true),
		gui.menu_item(label: 'Delete'),
	]
)
```

### Application Menu Bar

```oksyntax
gui.menubar(
	items: [
		gui.menu_item(
			label:   'File'
			submenu: gui.menu(items: [
				gui.menu_item(label: 'New', shortcut: 'Ctrl+N'),
				gui.menu_item(label: 'Open', shortcut: 'Ctrl+O'),
				gui.menu_item(separator: true),
				gui.menu_item(label: 'Exit'),
			])
		),
		gui.menu_item(
			label:   'Edit'
			submenu: gui.menu(items: [
				gui.menu_item(label: 'Undo', shortcut: 'Ctrl+Z'),
				gui.menu_item(label: 'Redo', shortcut: 'Ctrl+Y'),
			])
		),
	]
)
```

## Related Topics

- **[Events](../core/events.md)** - Menu event handling
- **[Containers](containers.md)** - Floating menus
