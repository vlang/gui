# 3 Views

A view is the fundamental UI building block in Gui. Every checkbox,
menu, button, and panel you see is a view. Despite the variety, there
are only three primitive view types:

- containers
- text
- images

Everything else is a composition of these three.

## Containers

Containers hold other views. More precisely, a container is a
rectangular region that can contain other containers, text, or images.

Containers may have an axis:

- `top-to-bottom` → a column
- `left-to-right` → a row
- no axis → a canvas (free-form positioning)

Rows and columns are the primary layout building blocks. A row stacks
its children horizontally; a column stacks them vertically. Containers
have many properties that define appearance and behavior. Three
essentials to understand early are `padding`, `spacing`, and `sizing`.

### Padding

Padding is the inner margin of a container. It has four sides: top,
right, bottom, and left (same order as CSS). You can think of padding as
the space between the container’s border and its content.

### Spacing

Spacing is the gap between the container’s children. For rows, spacing
is horizontal; for columns, spacing is vertical.

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

### Sizing

Sizing controls how a view determines its width and height. There are
three sizing modes:

- `fit` — size to the content
- `fill` — grow or shrink to fill the parent
- `fixed` — do not change size

Sizing is specified independently for the horizontal and vertical axes.

```v
// SizingType describes the three sizing modes of Gui
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

There are nine possible combinations of width/height sizing. For
convenience, Gui provides constants:

```oksyntax
pub const fit_fit   = Sizing{ .fit,   .fit }
pub const fit_fill  = Sizing{ .fit,   .fill }
pub const fit_fixed = Sizing{ .fit,   .fixed }

pub const fixed_fit   = Sizing{ .fixed, .fit }
pub const fixed_fill  = Sizing{ .fixed, .fill }
pub const fixed_fixed = Sizing{ .fixed, .fixed }

pub const fill_fit   = Sizing{ .fill,  .fit }
pub const fill_fill  = Sizing{ .fill,  .fill }
pub const fill_fixed = Sizing{ .fill,  .fixed }
```

For a deeper dive into containers (rows and columns), see the next
chapter.

## Text

`text` is a view. It is not a container. Text is its own primitive
because text layout is complex: it can run left-to-right or
right-to-left, wrap to multiple lines, be selectable, and its measured
size depends on font family, size, and decoration. Text layout is also
one of the more computationally expensive parts of UI.

Wrapping uses a simple word‑break algorithm. If text is too long, it
will overflow its container. Common remedies include:

- enabling scrolling in the parent container
- enabling clipping on the parent container

Gui aims to keep text predictable. Many UI frameworks split labels,
multi-line text, and input labels into different widgets; in Gui there
is just the `text` view for displaying text.

## Images

`image` is the simplest view. It is a rectangular region that displays a
bitmap or texture.

## Other views (compositions)

When you look at the list of predefined views you’ll see more than three
names, but they are all compositions of the primitives. For example, a
button is composed of rows: an outer `row` (border/background) that
contains an inner `row` (button body) that contains `text`. A button is
also a container, so it can hold other views (e.g., a progress bar next
to the label).

## See also

- 04-Rows-Columns.md — rows and columns in detail
- 05-Themes-Styles.md — colors, borders, radii, theme variables
- 07-Buttons.md — how buttons are composed from rows and text