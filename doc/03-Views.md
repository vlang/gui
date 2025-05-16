# Views

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

Sizing is perhaps the most challenging to understand. There are three
types of sizing, `fit`, `fill` and `fixed`. Fit sizing sized the
container to the size of its contents. Fill sizing attempts to grow or
shrink a container to fill its parent container. Fixed sizing does not
change the size of the container. Sizing can occur horizontally and
vertically. The code for Sizing is:

``` v
// SizingType describes the three sizing modes of GUI
pub enum SizingType {
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

    pub const fit_fit = Sizing{.fit, .fit}
    pub const fit_fill = Sizing{.fit, .fill}
    pub const fit_fixed = Sizing{.fit, .fixed}

    pub const fixed_fit = Sizing{.fixed, .fit}
    pub const fixed_fill = Sizing{.fixed, .fill}
    pub const fixed_fixed = Sizing{.fixed, .fixed}

    pub const fill_fit = Sizing{.fill, .fit}
    pub const fill_fill = Sizing{.fill, .fill}
    pub const fill_fixed = Sizing{.fill, .fixed}

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
is too long, it overflows its container. One way to remember this is to
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
