---------------------
# 4 Rows and Columns
---------------------

The two primary building blocks in Gui are `rows` and `columns`. Rows
stack their children horizontally, left-to-right and columns stack their
children top-to-bottom. From these two containers the entirety of the
predefined views (commonly called widgets) are constructed. Predefined
views are compositions. Here's the layout for Button.

``` v
pub fn button(cfg ButtonCfg) View {
    return row(
        id:           cfg.id
        id_focus:     cfg.id_focus
        color:        cfg.color_border
        padding:      cfg.padding_border
        fill:         cfg.fill_border
        radius:       cfg.radius_border
        width:        cfg.width
        height:       cfg.height
        disabled:     cfg.disabled
        invisible:    cfg.invisible
        min_width:    cfg.min_width
        max_width:    cfg.max_width
        min_height:   cfg.min_height
        max_height:   cfg.max_height
        sizing:       cfg.sizing
        cfg:          &cfg
        on_click:     cfg.on_click
        on_char:      cfg.on_char_button
        amend_layout: cfg.amend_layout
        content:      [
            row(
                sizing:  fill_fill
                h_align: cfg.h_align
                v_align: cfg.v_align
                padding: cfg.padding
                radius:  cfg.radius
                fill:    cfg.fill
                color:   cfg.color
                content: cfg.content
            ),
        ]
    )
}
```

A button is two nested rows. The outer row defines a border and the
inner row is the content interior. Granted, there are many options, but
it is common to set only a few options and use the default values for
the others. The takeaway here is there is nothing special about the
`button` view that ships with Gui. Make your own if it suits your needs.

Rows and columns have many options available. To list a few:

- Focusable
- Scrollable
- Floatable
- Sizable (fill, fit and fixed)
- Alignable
- Can be colored, outlined, or fillable
- Can have radius corners
- Can have text embedded in the border (group box)

Focus is when a row or column can receive keyboard input. You can't type
in a row or column so why is this needed? Styling. Oftentimes, the color
of a row or column, particularly when used as a border, is modified
based on the focus state.

Enable scrolling by setting the `id_scroll` member to a non-zero value.
Content that extends past the boundaries of the row (or column) are
hidden until scrolled into view. When scrolling, scrollbars can
optionally be enabled. One or both can be shown. Scrollbars can be
hidden when content fits entirely within the container. Scrollbars can
be made visible only when hovering over the scrollbar region. Scrollbars
are floating views and be placed over or beside content as desired.

Floating is particularly powerful. It allows drawing over other content.
Menus are a good example of this. The menu code in Gui is just a
composition of rows and columns (and text). The submenus are columns
that float below or next to their parent item. The tricky part is the
mouse handling. The drawing part is straightforward.

Content can be aligned start, center, and end. Start and end are
typically left and right but can change based on localization. Columns
can align content top, middle, and bottom.

Row and column are transparent by default. Change the color if desired.
By default, the color is drawn as an outline. Set `fill` to true to fill
the interior with color.

The corners of a row or container can be square or round. The roundness
of a corner is determined by the `radius` property.

Text can be embedded in the outline of a row or column, near the
top-left corner. This style of container is typically called a group
box. Set the `text` property to enable this feature.

If you browse the code, other than `text` and `image`, you'll find the
predefined views are compositions of rows and columns. It's rectangles
within rectangles all-the-way down!
