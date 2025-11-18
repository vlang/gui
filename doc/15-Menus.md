# 15 Menus and Menubars

Menus are a fundamental component for navigation and actions in many
applications. Gui provides a flexible system for creating horizontal
menubars (like at the top of an application window) and vertical context
menus (pop-up menus).

Both types of menus are built from the same core components:

- `menubar()`: Creates a horizontal menu bar.
- `menu()`: Creates a vertical menu, often used for context menus or
  submenus.
- `MenubarCfg`: The configuration struct for both `menubar` and `menu`.
- `MenuItemCfg`: The configuration for a single item within a menu.

See also: `examples/menu_demo.v` and `examples/context_menu_demo.v` for
runnable examples.

## Menubars

A `menubar` is a horizontal row of menu items. Each top-level item can
have a dropdown submenu.

### `menubar()`

This function creates the menubar view. It takes a `MenubarCfg`.

```v
import gui

mut window := gui.window(width: 300, height: 300)

window.menubar(
	id_focus: 1 // required for state tracking
	items:    [
		gui.menu_submenu('file', 'File', [
			gui.menu_item_text('new', 'New'),
			gui.menu_item_text('open', 'Open'),
			gui.menu_separator(),
			gui.menu_item_text('exit', 'Exit'),
		]),
		gui.menu_submenu('edit', 'Edit', [
			gui.menu_item_text('cut', 'Cut'),
			gui.menu_item_text('copy', 'Copy'),
			gui.menu_item_text('paste', 'Paste'),
		]),
	]
	action:   fn (id string, mut e gui.Event, mut w gui.Window) {
		// handle clicks for all menu items here
		println('Menu item clicked: ${id}')
	}
)
```

## Context Menu

A vertical `menu` is ideal for context menus that appear on right-click
or other actions. It is also built using `MenubarCfg`, but it renders as
a single column.

### `menu()`

This function creates a vertical menu view. It is often used with the
`float` property to appear as an overlay.

```v
import gui

window := gui.window(width: 300, height: 300)

window.menu(
	id_focus:     2
	float:        true
	float_anchor: .top_left
	items:        [
		gui.menu_item_text('action1', 'Perform Action 1'),
		gui.menu_item_text('action2', 'Perform Action 2'),
	]
	action:       fn (id string, mut e gui.Event, mut w gui.Window) {
		// ...
	}
)
```

## `MenubarCfg`

This struct configures both `menubar` and `menu` views.

Key fields:
- `id_focus u32`: **Required**. A unique, non-zero ID used to track the
  focus and selection state of this menu system.
- `items []MenuItemCfg`: The list of menu items to display.
- `action fn (string, mut Event, mut Window)`: A global callback for all
  menu item clicks within this menubar. It receives the `id` of the
  clicked item. This is called *after* any item-specific action.
- Styling fields: `color`, `color_border`, `color_select`, `padding`,
  `radius`, `text_style`, etc. These control the appearance of the menu
  and its items, and default to the theme's `menubar_style`.

## `MenuItemCfg`

This struct configures an individual item within a menu.

Key fields:
- `id string`: **Required**. A unique identifier for the menu item. This
  is passed to the action callbacks.
- `text string`: The text to display for the item.
- `submenu []MenuItemCfg`: A list of child menu items to display in a
  submenu when this item is hovered or clicked.
- `action fn (&MenuItemCfg, mut Event, mut Window)`: A callback specific
  to this menu item. It is called before the main `MenubarCfg.action`.
- `separator bool`: If `true`, this item is rendered as a horizontal
  line.
- `disabled bool`: If `true`, the item is visible but not interactive.
- `custom_view ?View`: Allows you to render any custom view as the menu
  item's content, instead of simple text.

## Menu Item Helpers

To simplify creating common menu items, Gui provides several helper
functions that return a `MenuItemCfg`.

### `menu_item_text()`

Creates a standard, clickable text item.

```v
import gui

gui.menu_item_text('save', 'Save File')
```

### `menu_submenu()`

Creates an item that opens a submenu. It automatically adds a `›` arrow
symbol to indicate the presence of a submenu.

```v
import gui

gui.menu_submenu('export', 'Export As', [
	gui.menu_item_text('export_pdf', 'PDF'),
	gui.menu_item_text('export_png', 'PNG'),
])
```

### `menu_separator()`

Creates a horizontal separator line. It uses a special internal ID.

```v
import gui

gui.menu_separator()
```

### `menu_subtitle()`

Creates a non-interactive, disabled text item, often used as a heading
within a menu. It uses a special internal ID and can be styled
differently via the theme.

```v
import gui

gui.menu_subtitle('Alignment')
```

## Interaction Model

### Clicks

When a menu item is clicked:
1.  The item-specific `action` (on `MenuItemCfg`) is called, if present.
2.  The global `action` (on `MenubarCfg`) is called.
3.  If the item has no submenu, the entire menu structure is closed and
    loses focus.
4.  If the item has a submenu, it remains open, and the submenu is
    displayed.

### Hover

- In a horizontal `menubar`, hovering over a top-level item with a
  submenu will open that submenu if another one is already open.
- In a vertical `menu`, hovering over an item with a submenu will open
  it.
- Moving the mouse off a submenu and back to its parent item will keep
  the parent menu open.

### State Management

The state of which menu and items are open or selected is managed
internally by Gui using the `id_focus` you provide to `MenubarCfg`. When
a menu is active, it "has focus," which allows hover-highlighting and
keyboard navigation. Clicking outside the menu removes focus and closes
it.

## Styling

The appearance of menus and menubars is controlled by
`gui_theme.menubar_style`. You can override these settings globally by
creating a new theme, or per-instance by setting the style properties in
`MenubarCfg`.

Key style properties on `MenubarCfg`:
- `color`, `color_border`, `color_select`
- `padding`, `padding_border`, `padding_menu_item`, `padding_submenu`
- `radius`, `radius_border`, `radius_menu_item`
- `text_style`, `text_style_subtitle`

Example of a custom-styled menu:

```v
import gui

window := gui.window(width: 300, height: 300)

window.menu(
	id_focus:       3
	color:          gui.rgb(40, 40, 40)
	color_select:   gui.rgb(0, 120, 215)
	color_border:   gui.rgb(80, 80, 80)
	radius:         4
	padding_border: gui.pad_all(1)
	items:          [
		gui.menu_item_text('copy', 'Copy'),
		gui.menu_item_text('paste', 'Paste'),
	]
	action:         fn (id string, mut e gui.Event, mut w gui.Window) {}
)
```

## See Also

- `05-Themes-Styles.md` --- Details on colors, padding, and styling.
- `08-Container-View.md` --- Understanding floating containers.
- `examples/menu_demo.v`
- `examples/context_menu_demo.v`