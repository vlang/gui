# Layout Types

Layout configuration types and sizing modes.

## Sizing

Enum for sizing modes:

```oksyntax
pub enum Sizing {
	fit    // Size to content
	fill   // Fill available space
	fixed  // Use specified dimension
}
```

## Sizing Constants

Pre-defined sizing combinations (width × height):

```oksyntax
pub const (
	fit_fit       = Sizing{width: .fit, height: .fit}
	fit_fill      = Sizing{width: .fit, height: .fill}
	fit_fixed     = Sizing{width: .fit, height: .fixed}
	fixed_fit     = Sizing{width: .fixed, height: .fit}
	fixed_fill    = Sizing{width: .fixed, height: .fill}
	fixed_fixed   = Sizing{width: .fixed, height: .fixed}
	fill_fit      = Sizing{width: .fill, height: .fit}
	fill_fill     = Sizing{width: .fill, height: .fill}
	fill_fixed    = Sizing{width: .fill, height: .fixed}
)
```

See [Sizing & Alignment](../core/sizing-alignment.md) for usage details.

## Alignment

Horizontal alignment:

```oksyntax
pub enum HAlign {
	left
	center
	right
}
```

Vertical alignment:

```oksyntax
pub enum VAlign {
	top
	middle
	bottom
}
```

## Padding

Inner margin specification:

```oksyntax
pub struct Padding {
pub:
	top    f32
	right  f32
	bottom f32
	left   f32
}
```

### Padding Constants

```oksyntax
pub const (
	padding_none   = Padding{0, 0, 0, 0}
	padding_one    = Padding{1, 1, 1, 1}
	padding_two    = Padding{2, 2, 2, 2}
	padding_small  = Padding{5, 5, 5, 5}
	padding_medium = Padding{10, 10, 10, 10}
	padding_large  = Padding{15, 15, 15, 15}
)
```

## Layout

Layout node with position and size information:

```oksyntax
pub struct Layout {
pub mut:
	shape    &Shape
	parent   &Layout
	children []Layout
}
```

## Shape

Geometric properties of a layout node:

```oksyntax
pub struct Shape {
pub mut:
	x      f32  // X position
	y      f32  // Y position
	width  f32  // Width
	height f32  // Height
	color  Color
	radius f32  // Corner radius
	// ...additional properties
}
```

## View

Base view type (interface):

```oksyntax
pub type View = RowCfg | ColumnCfg | TextCfg | ImageCfg | ButtonCfg | ...
```

All component configuration structs implement the View interface.

## Common View Properties

Most view configuration structs include:

```oksyntax
struct ViewCfg {
pub:
	id           string
	width        f32
	height       f32
	min_width    f32
	max_width    f32
	min_height   f32
	max_height   f32
	sizing       Sizing
	h_align      HAlign
	v_align      VAlign
	padding      Padding
	disabled     bool
	invisible    bool
	id_focus     int
	focus_skip   bool
}
```

## ScrollMode

Scroll direction restriction:

```oksyntax
pub enum ScrollMode {
	both
	vertical_only
	horizontal_only
}
```

## Related Topics

- **[Sizing & Alignment](../core/sizing-alignment.md)** - Sizing usage
- **[Layout](../core/layout.md)** - Layout algorithm
- **[Views](../core/views.md)** - View composition
