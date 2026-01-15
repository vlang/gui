# Lists and Tables

Display collections of data.

## listbox

Scrollable list of selectable items.

### Basic Usage

```oksyntax
gui.listbox(
	items:     ['Item 1', 'Item 2', 'Item 3']
	selected:  selected_item
	on_select: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		mut app := w.state[App]()
		app.selected_item = e.selected
	}
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `items` | `[]string` | List items |
| `selected` | `string` | Currently selected item |
| `multi_select` | `bool` | Allow multiple selections |
| `on_select` | `fn` | Selection handler |

## table

Tabular data display.

### Basic Usage

```oksyntax
gui.table(
	headers: ['Name', 'Age', 'Email']
	rows:    [
		['Alice', '25', 'alice@example.com'],
		['Bob', '30', 'bob@example.com'],
	]
	on_row_click: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		println('Row clicked: ${e.row_index}')
	}
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `headers` | `[]string` | Column headers |
| `rows` | `[][]string` | Table data |
| `sortable` | `bool` | Enable column sorting |
| `on_row_click` | `fn` | Row click handler |

## tree

Hierarchical data display.

### Basic Usage

```oksyntax
gui.tree(
	nodes: [
		TreeNode{label: 'Root', children: [
			TreeNode{label: 'Child 1'},
			TreeNode{label: 'Child 2', children: [
				TreeNode{label: 'Grandchild'},
			]},
		]},
	]
	on_select: fn (_ &gui.Layout, mut e gui.Event, mut w gui.Window) {
		println('Selected: ${e.node_label}')
	}
)
```

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `nodes` | `[]TreeNode` | Hierarchical nodes |
| `expanded` | `[]string` | Expanded node IDs |
| `on_select` | `fn` | Selection handler |

## Common Patterns

### File Browser

```oksyntax
gui.column(
	content: [
		gui.text(text: 'Files:', text_style: gui.theme().b3),
		gui.listbox(
			items: files
			height: 300
		),
	]
)
```

### Data Table

```oksyntax
gui.table(
	headers: ['Product', 'Price', 'Stock']
	rows:    products.map(fn (p Product) []string {
		return [p.name, '\$${p.price}', '${p.stock}']
	})
	sortable: true
)
```

### Sidebar Navigation

```oksyntax
gui.tree(
	nodes: [
		TreeNode{
			label:    'Documents'
			children: [
				TreeNode{label: 'Work'},
				TreeNode{label: 'Personal'},
			]
		},
		TreeNode{
			label:    'Photos'
			children: [
				TreeNode{label: '2024'},
			]
		},
	]
)
```

## Related Topics

- **[Containers](containers.md)** - Scrollable containers
- **[State Management](../core/state-management.md)** - Managing data
- **[Events](../core/events.md)** - Selection handling
