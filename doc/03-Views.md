----------
# 3 Views
----------

A view is the only UI building block. Every checkbox, menu, button, etc.
is a view. Interestingly, there are only three basic types of views,
containers text and images. Everything else is either a container, text,
image or a combination thereof.

Containers, as the name implies contain content. What kind of content?
Containers, text or images. If this definition sounds recursive it is
because it is. More precisely, a container is a rectangular region that
can hold other containers, text or images.

Containers have an axis of `top-to-bottom` or `left-to-right` or none.
Containers with an axis of `top-to-bottom` are called `columns`. The
`left-to-right` containers are called rows. Containers with no defined
axis are called `canvas`.

Rows and columns are the primary building blocks. A row will stack its
content horizontally while a column stacks its content vertically. Rows
and columns have many properties that define how they look and respond
to user events. For now, the only three I\'ll discuss are `padding`,
`spacing`, and `sizing`.

Padding is simply the margin of space inside the row or column. Padding
has four parts, top, right, bottom, and left. The order here is the same
as CSS used in browsers. Another way to think about padding is as the
space around the content of the container.

Spacing is the space between the container\'s contents. For rows, it is
the horizontal space between the container\'s content items. For
columns, it is the vertical space between content items.

```
      Container (row)
    +---------------------------------------------+
    |                 Padding Top                 |
    |   +----------------+   +----------------+   |
    | P |                |   |                | P |
    | a |                |   |                | a |
    | d |                | S |                | d |
    | d |                | p |                | d |
    | i |                | a |                | i |
    | n |   child view   | c |   child view   | n |
    | g |                | i |                | g |
    |   |                | n |                |   |
    | L |                | g |                | R |
    | e |                |   |                | i |
    | f |                |   |                | g |
    | t |                |   |                | h |
    |   +----------------+   +----------------+ t |
    |                Padding Bottom               |
    +---------------------------------------------+
```

Sizing is perhaps the most challenging to understand. There are three
types of sizing, `fit`, `fill` and `fixed`. Fit sizing sized the
container to the size of its contents. Fill sizing attempts to grow or
shrink a container to fill its parent container. Fixed sizing does not
change the size of the container. Sizing can occur horizontally and
vertically. The code for Sizing is:

``` v
// SizingType describes the three sizing modes of GUI
pub enum SizingType as u8 {
    fit   // element fits to content
    fill  // element fills to parent (grows or shrinks)
    fixed // element unchanged
}

// Sizing describes how the shape is sized horizontally and vertically.
pub struct Sizing {
pub:
    width  SizingType
    height SizingType
}
```

There are nine different combinations possible. For convenience, Gui
provides constants:

```v oksyntax
pub const fit_fit = Sizing{.fit, .fit}
pub const fit_fill = Sizing{.fit, .fill}
pub const fit_fixed = Sizing{.fit, .fixed}

pub const fixed_fit = Sizing{.fixed, .fit}
pub const fixed_fill = Sizing{.fixed, .fill}
pub const fixed_fixed = Sizing{.fixed, .fixed}

pub const fill_fit = Sizing{.fill, .fit}
pub const fill_fill = Sizing{.fill, .fill}
pub const fill_fixed = Sizing{.fill, .fixed}
```

For a deeper dive into containers, see the next chapter.

## Text

Text is also a view in Gui. It does not function as a container. If
you\'re wondering why plain text is a separate view type it is because
text is complicated. Text can flow forward, backward, and up and down.
It can have one or more lines and is selectable. It varies in width
depending on the family, size, and decorations. In other words, it is a
giant pain-in-the-pants to lay it out correctly. It is also
computationally the most expensive to calculate.

Text can be wrapped. Gui uses a simple word break algorithm. If the text
is too long, it overflows its container. One way to remedy this is to
enable scrolling in the parent container. Another option is to enable
clipping on the parent container.

Gui does its best to keep text simple and predictable. Other UI
frameworks may have different text components for labels, multiline
text, and text boxes. In Gui, there is only the `text` view. It\'s the
all-in-one component for displaying text.

## Images

Image is the simplist view. Image simply rectangular region that
displays an image.

## Other Views

When you look at the list of views you\'ll see many more than three. As
mentioned earlier, they are combinations of the three. For instance, a
button is `row` (border) that contains a `row` (button body) that
contains `text`. Button is even more interesting in that a button is
itself a container. As such, it can other views (e.g. progress bar).

# GUI Views Documentation

This documentation covers the various view components available in the GUI library. 
Each view provides specific functionality for building user interfaces.

## General Usage Notes

- All views support common properties like `id`, `visible`, `enabled`, and `style`
- Event handlers (like `onclick`, `onchange`) are typically functions that handle user interactions
- Styling can be applied through CSS-like properties or theme systems
- Views can be composed together to create complex user interfaces
- Most views support accessibility features through ARIA attributes and keyboard navigation

This documentation provides an overview of all available GUI view components. 
Each view can be customized extensively through its configuration options to meet 
specific application requirements.

## Button View 

### Description
The Button view provides interactive buttons that users can click to trigger actions.

### Configuration Options
- **text**: The text displayed on the button
- **icon**: Optional icon to display alongside text
- **enabled**: Whether the button is clickable (default: true)
- **style**: Visual styling options (primary, secondary, danger, etc.)
- **size**: Button size (small, medium, large)

### Example Usage
```v
button := Button{
    text: 'Save'
    enabled: true
    style: .primary
    onclick: save_document
}
```


## Container View 

### Description
A container view that holds and organizes other views. Provides layout management and grouping functionality.

### Configuration Options
- **children**: Array of child views
- **layout**: Layout type (vertical, horizontal, grid)
- **padding**: Internal spacing
- **background_color**: Container background
- **border**: Border styling options

### Example Usage
```v
container := Container{
    layout: .vertical
    padding: Padding{10, 10, 10, 10}
    children: [button1, text_field, button2]
}
```


## Date Picker View 

### Description
Provides a calendar interface for selecting dates with dropdown or popup functionality.

### Configuration Options
- **selected_date**: Currently selected date
- **min_date**: Minimum selectable date
- **max_date**: Maximum selectable date
- **format**: Date display format
- **show_time**: Whether to include time selection

### Example Usage
```v
date_picker := DatePicker{
    selected_date: time.now()
    format: 'YYYY-MM-DD'
    show_time: false
    onchange: handle_date_change
}
```


## Dialog View 

### Description
Modal dialog windows for displaying information or collecting user input.

### Configuration Options
- **title**: Dialog window title
- **content**: Main dialog content
- **buttons**: Array of dialog buttons
- **modal**: Whether dialog blocks interaction with parent
- **closable**: Whether dialog can be closed by user

### Example Usage
```v
dialog := Dialog{
    title: 'Confirm Action'
    content: 'Are you sure you want to delete this item?'
    buttons: [ok_button, cancel_button]
    modal: true
}
```


## Expand Panel View 

### Description
Collapsible panel that can show/hide content with expand/collapse animations.

### Configuration Options
- **title**: Panel header text
- **expanded**: Whether panel starts expanded
- **content**: The collapsible content
- **animate**: Enable expand/collapse animations
- **header_style**: Styling for the header area

### Example Usage
```v
panel := ExpandPanel{
    title: 'Advanced Settings'
    expanded: false
    content: settings_container
    animate: true
}
```


## Image View 

### Description
Displays images with various scaling and positioning options.

### Configuration Options
- **src**: Image source (file path or URL)
- **width**: Image display width
- **height**: Image display height
- **scale_mode**: How image scales (fit, fill, stretch, center)
- **alt_text**: Alternative text for accessibility

### Example Usage
```v
image := Image{
    src: 'assets/logo.png'
    width: 200
    height: 100
    scale_mode: .fit
    alt_text: 'Company Logo'
}
```


## Input View 

### Description
Text input field for single-line text entry.

### Configuration Options
- **text**: Current input text
- **placeholder**: Placeholder text when empty
- **max_length**: Maximum character limit
- **readonly**: Whether input is read-only
- **password**: Whether to hide input text
- **validation**: Input validation rules

### Example Usage
```v
input := Input{
    placeholder: 'Enter your name'
    max_length: 50
    text: user.name
    onchange: update_name
}
```


## Date Input View 

### Description
Specialized input field for date entry with built-in validation.

### Configuration Options
- **value**: Current date value
- **format**: Date input format
- **min_date**: Minimum allowed date
- **max_date**: Maximum allowed date
- **required**: Whether input is required

### Example Usage
```v
date_input := InputDate{
    value: user.birth_date
    format: 'MM/DD/YYYY'
    required: true
    onchange: update_birth_date
}
```


## Listbox View 

### Description
Scrollable list of selectable items.

### Configuration Options
- **items**: Array of list items
- **selected_index**: Currently selected item index
- **multi_select**: Allow multiple selections
- **item_height**: Height of each list item
- **show_scrollbar**: Whether to show scrollbar

### Example Usage
```v
listbox := Listbox{
    items: ['Item 1', 'Item 2', 'Item 3']
    selected_index: 0
    multi_select: false
    onselect: handle_selection
}
```


## Menu View 

### Description
Context menu or popup menu with menu items.

### Configuration Options
- **items**: Array of menu items
- **position**: Menu position (absolute coordinates)
- **direction**: Menu expansion direction
- **auto_close**: Close menu when item selected

### Example Usage
```v
menu := Menu{
    items: [save_item, load_item, exit_item]
    auto_close: true
    position: Point{x: 100, y: 200}
}
```


## Menu Item View 

### Description
Individual item within a menu with text, icon, and action.

### Configuration Options
- **text**: Menu item text
- **icon**: Optional menu item icon
- **enabled**: Whether item is clickable
- **shortcut**: Keyboard shortcut display
- **separator**: Whether item is a separator line

### Example Usage
```v
menu_item := MenuItem{
    text: 'Save File'
    icon: 'save'
    shortcut: 'Ctrl+S'
    onclick: save_file
}
```


## Menu Bar View 

### Description
Horizontal menu bar typically placed at the top of windows.

### Configuration Options
- **menus**: Array of top-level menus
- **height**: Menu bar height
- **background**: Menu bar background styling
- **text_color**: Text color for menu titles

### Example Usage
```v
menubar := MenuBar{
    menus: [file_menu, edit_menu, view_menu]
    height: 30
    background: theme.menu_bg
}
```


## Progress Bar View 

### Description
Visual indicator showing progress of a task or operation.

### Configuration Options
- **value**: Current progress value (0-100)
- **min**: Minimum value
- **max**: Maximum value
- **indeterminate**: Show indefinite progress animation
- **show_text**: Display percentage text
- **color**: Progress bar color

### Example Usage
```v
progress := ProgressBar{
    value: 45
    max: 100
    show_text: true
    color: theme.primary
}
```


## Radio View 

### Description
Individual radio button for single selection from a group.

### Configuration Options
- **selected**: Whether this radio is selected
- **text**: Radio button label text
- **group**: Radio button group identifier
- **enabled**: Whether radio is clickable

### Example Usage
```v
radio := Radio{
    text: 'Option A'
    group: 'choices'
    selected: false
    onchange: handle_radio_change
}
```


## Radio Button Group View 

### Description
Container managing a group of mutually exclusive radio buttons.

### Configuration Options
- **options**: Array of radio button options
- **selected_index**: Index of currently selected option
- **orientation**: Layout orientation (horizontal/vertical)
- **spacing**: Space between radio buttons

### Example Usage
```v
radio_group := RadioButtonGroup{
    options: ['Small', 'Medium', 'Large']
    selected_index: 1
    orientation: .horizontal
    onchange: handle_size_change
}
```


## Range Slider View 

### Description
Slider control for selecting numeric values within a range.

### Configuration Options
- **min**: Minimum slider value
- **max**: Maximum slider value
- **value**: Current slider value
- **step**: Value increment step
- **show_value**: Display current value
- **orientation**: Horizontal or vertical

### Example Usage
```v
slider := RangeSlider{
    min: 0
    max: 100
    value: 50
    step: 5
    show_value: true
    onchange: update_volume
}
```


## Rectangle View 

### Description
Simple rectangular shape for visual elements and spacing.

### Configuration Options
- **width**: Rectangle width
- **height**: Rectangle height
- **color**: Fill color
- **border_color**: Border color
- **border_width**: Border thickness
- **corner_radius**: Rounded corner radius

### Example Usage
```v
rect := Rectangle{
    width: 200
    height: 100
    color: Color{255, 0, 0, 255}
    corner_radius: 10
}
```


## RTF View 

### Description
Rich Text Format viewer for displaying formatted text with styling.

### Configuration Options
- **content**: RTF formatted text content
- **editable**: Whether text can be edited
- **word_wrap**: Enable text wrapping
- **font_family**: Default font family
- **font_size**: Default font size

### Example Usage
```v
rtf := RTF{
    content: formatted_text
    editable: false
    word_wrap: true
    font_size: 12
}
```


## Scrollbar View 

### Description
Scrollbar control for scrolling through content areas.

### Configuration Options
- **orientation**: Horizontal or vertical scrollbar
- **position**: Current scroll position
- **page_size**: Size of visible area
- **total_size**: Total scrollable content size
- **auto_hide**: Hide when not needed

### Example Usage
```v
scrollbar := Scrollbar{
    orientation: .vertical
    position: 0
    page_size: 300
    total_size: 1000
    onscroll: handle_scroll
}
```


## Select View 

### Description
Dropdown selection control for choosing from predefined options.

### Configuration Options
- **options**: Array of selectable options
- **selected_index**: Currently selected option index
- **placeholder**: Text shown when no selection
- **searchable**: Enable option searching
- **max_height**: Maximum dropdown height

### Example Usage
```v
select := Select{
    options: ['Red', 'Green', 'Blue']
    selected_index: -1
    placeholder: 'Choose a color'
    onchange: handle_color_change
}
```


## Switch View 

### Description
Toggle switch control for binary on/off states.

### Configuration Options
- **enabled**: Current switch state (on/off)
- **text**: Optional label text
- **size**: Switch size (small, medium, large)
- **color**: Switch color when enabled
- **disabled**: Whether switch is interactive

### Example Usage
```v
switch := Switch{
    enabled: user.notifications
    text: 'Enable Notifications'
    color: theme.primary
    onchange: toggle_notifications
}
```


## Table View 

### Description
Data table with rows and columns for displaying structured data.

### Configuration Options
- **columns**: Table column definitions
- **rows**: Table row data
- **sortable**: Enable column sorting
- **selectable**: Allow row selection
- **pagination**: Enable pagination controls
- **row_height**: Height of table rows

### Example Usage
```v
table := Table{
    columns: [name_col, email_col, status_col]
    rows: user_data
    sortable: true
    selectable: true
    onselect: handle_row_select
}
```


## Text View 

### Description
Static text display with formatting options.

### Configuration Options
- **text**: Text content to display
- **font_family**: Font family name
- **font_size**: Text size in pixels
- **color**: Text color
- **alignment**: Text alignment (left, center, right)
- **mode**: Enable different types of text wrapping

### Example Usage
```v
text := Text{
    text: 'Welcome to the application'
    font_size: 16
    color: theme.text_primary
    alignment: .center
}
```


## Throbber View 

### Description
Animated loading indicator to show ongoing operations.

### Configuration Options
- **active**: Whether throbber is spinning
- **size**: Throbber diameter
- **color**: Throbber color
- **speed**: Animation speed
- **style**: Throbber style (spinner, dots, bars)

### Example Usage
```v
throbber := Throbber{
    active: is_loading
    size: 32
    color: theme.primary
    style: .spinner
}
```


## Toggle View 

### Description
Toggle button that switches between two states with visual feedback.

### Configuration Options
- **toggled**: Current toggle state
- **text_on**: Text when toggled on
- **text_off**: Text when toggled off
- **icon_on**: Icon when toggled on
- **icon_off**: Icon when toggled off

### Example Usage
```v
toggle := Toggle{
    toggled: dark_mode_enabled
    text_on: 'Dark Mode'
    text_off: 'Light Mode'
    onchange: toggle_theme
}
```


## Tooltip View 

### Description
Contextual help popup that appears on hover or focus.

### Configuration Options
- **text**: Tooltip text content
- **position**: Tooltip position relative to target
- **delay**: Show delay in milliseconds
- **duration**: Auto-hide duration
- **arrow**: Show pointing arrow

### Example Usage
```v
tooltip := Tooltip{
    text: 'Click to save your changes'
    position: .bottom
    delay: 500
    arrow: true
}
```


## Tree View 

### Description
Hierarchical tree control for displaying nested data structures.

### Configuration Options
- **nodes**: Root tree nodes
- **expanded**: Set of expanded node IDs
- **selected**: Currently selected node ID
- **show_root**: Whether to show root node
- **indent_size**: Child node indentation
- **node_height**: Height of tree nodes

### Example Usage
```v
tree := Tree{
    nodes: file_tree_data
    show_root: false
    indent_size: 20
    onselect: handle_node_select
    onexpand: handle_node_expand
}
```

