import gui

// Markdown View Demo
// ==================
// Demonstrates rendering markdown as styled rich text.

const markdown_source = r"# Markdown Sample Document

This document demonstrates all common Markdown elements. Use it as a
reference for syntax or as a test file for rendering engines.

## Text Formatting

Regular paragraph text flows naturally across multiple lines. When you
write content in Markdown, you don't need to worry about line breaks
within a paragraph---the renderer handles text wrapping automatically.
This makes it easy to write long-form content without constantly
thinking about formatting.

Here's another paragraph to show separation. Paragraphs are separated by
blank lines. You can use **bold text** for emphasis, *italic text* for
subtle emphasis, or ***bold and italic*** together. You can also use
~~strikethrough~~ for deleted content and `inline code` for technical
terms or commands.

### Alternative Emphasis Syntax

You can also use underscores: *italic with underscores* and **bold with
underscores**. Most people prefer asterisks, but both work identically
in standard Markdown parsers.

## Lists

### Unordered Lists

- The first item in this unordered list contains enough text to
  demonstrate how list items wrap when they exceed the typical line
  length of most editors and viewers, which is usually around 80 to 120
  characters depending on your settings.
- Second item with a shorter description but still meaningful content.
- Third item that also spans multiple lines when rendered in a narrow
  viewport, showing how Markdown handles long list content gracefully
  without breaking the visual hierarchy of the document.
  - Nested item underneath the third item, demonstrating that you can
    create hierarchical structures within your lists by indenting with
    two spaces or a tab.
  - Another nested item with substantial content to show that nested
    items also wrap properly when they contain lengthy descriptions or
    explanations that exceed the available width.
    - Deeply nested item showing three levels of nesting, which is about
      as deep as you typically want to go for readability purposes.
- Fourth item back at the root level.

### Ordered Lists

1.  First ordered item with extensive explanatory text that wraps across
    multiple lines, demonstrating that numbered lists behave the same
    way as bulleted lists when it comes to handling long content within
    individual items.
2.  Second ordered item that continues the numbering sequence
    automatically, regardless of what number you actually type in the
    source Markdown.
3.  Third item with enough content to wrap, ensuring that the visual
    presentation remains clean and readable even when individual list
    items contain paragraph-length descriptions or instructions.
    1.  Nested numbered item showing that you can create sub-lists
        within ordered lists as well, maintaining proper indentation and
        numbering throughout the hierarchy.
    2.  Another nested numbered item with additional explanatory
        content.
4.  Fourth item returning to the main list level.

### Task Lists

- [x] Completed task that has been marked as done by placing an 'x'
  inside the brackets.
- [x] Another finished task demonstrating the checked state, which
  renders as a filled checkbox in most Markdown viewers and platforms
  that support this extension.
- [ ] Incomplete task waiting to be done, shown with empty brackets that
  render as an unchecked checkbox in compatible viewers.
- [ ] Another pending task with a longer description that explains what
  needs to be accomplished, demonstrating that task list items can also
  contain substantial amounts of text that wrap naturally.

## Blockquotes

> This is a blockquote containing a substantial amount of text that
> spans multiple lines. Blockquotes are commonly used for citing
> external sources, highlighting important information, or setting apart
> quoted material from the main body of your document. They create
> visual distinction through indentation and styling.
>
> You can include multiple paragraphs within a single blockquote by
> continuing to use the greater-than symbol at the start of each line.
> This second paragraph is still part of the same blockquote.
>
> > Nested blockquotes are also possible, allowing you to show quoted
> > material within quoted material---useful for email threads or forum
> > discussions where multiple levels of response exist.

## Code

### Inline Code

Use `console.log()` for debugging in JavaScript, or run
`pip install package-name` to install Python packages.

### Code Blocks

``` javascript
// JavaScript example with syntax highlighting
function calculateTotal(items) {
    return items
        .filter(item => item.active)
        .reduce((sum, item) => sum + item.price * item.quantity, 0);
}

const cart = [
    { name: 'Widget', price: 25.00, quantity: 2, active: true },
    { name: 'Gadget', price: 49.99, quantity: 1, active: true },
    { name: 'Removed Item', price: 10.00, quantity: 1, active: false }
];

console.log(`Total: $${calculateTotal(cart).toFixed(2)}`);
```

``` python
# Python example demonstrating classes
class ShoppingCart:
    def __init__(self):
        self.items = []
    
    def add_item(self, name, price, quantity=1):
        self.items.append({
            'name': name,
            'price': price,
            'quantity': quantity
        })
    
    def total(self):
        return sum(item['price'] * item['quantity'] for item in self.items)
```

## Links and Images

### Links

Here's a [link to OpenAI](https://openai.com) inline in text. You can
also use [reference-style links](https://example.com 'Example Website')
that define the URL elsewhere in the document, which keeps paragraphs
cleaner when you have many links.

Autolinks work for URLs: <https://www.github.com> and email addresses:
<email@example.com>.

### Images

![Placeholder image description](../assets/logo.jpg)

*Caption: Images can have alt text for accessibility and optional
titles.*

## Tables

| Feature     | Basic Markdown |  Extended Markdown | Notes                              |
|-------------|----------------|--------------------|------------------------------------|
| Headers     |       ✓        |                  ✓ | Six levels available (h1-h6)       |
| Emphasis    |       ✓        |                  ✓ | Bold, italic, and combinations     |
| Lists       |       ✓        |                  ✓ | Ordered, unordered, and nested     |
| Task Lists  |       ✗        |                  ✓ | GitHub Flavored Markdown extension |
| Tables      |       ✗        |                  ✓ | Alignment options with colons      |
| Footnotes   |       ✗        |                  ✓ | Not universally supported          |
 
*Table columns can be left-aligned, center-aligned, or right-aligned
using colons in the separator row.*

## Horizontal Rules

Content above the horizontal rule.

------------------------------------------------------------------------

Content below the horizontal rule. You can create horizontal rules with
three or more hyphens, asterisks, or underscores.

------------------------------------------------------------------------

Another section after a different style of horizontal rule.

## Advanced Elements

### Footnotes

Here's a sentence with a footnote[^1] and here's another one[^2].

### Definition Lists

Term 1
:   Definition for the first term, which can be quite detailed and span
    multiple lines if necessary to fully explain the concept being
    defined.

Term 2
:   Primary definition for the second term.
:   Alternative definition showing that terms can have multiple
    definitions.

### Abbreviations

The HTML specification is maintained by the W3C. HTMLX is not the same as HTML.

*[HTML]: Hyper Text Markup Language
*[W3C]: World Wide Web Consortium

## Escaping Characters

Use backslashes to display literal characters that would otherwise be
interpreted as Markdown:

\*This text is surrounded by literal asterisks\*

\# This is not a heading

## Conclusion

This document has covered all the common Markdown elements you're likely
to encounter or need in everyday writing. Different Markdown processors
may support additional features or have slight variations in syntax, so
always test your content in the target environment.

For more information, consult the [CommonMark
Specification](https://commonmark.org/) or the documentation for your
specific Markdown processor.

[^1]: This is the first footnote, providing additional context or
    citation information.

[^2]: This is a longer footnote with multiple paragraphs.

    Indent subsequent paragraphs to include them in the footnote.
"

fn main() {
	mut window := gui.window(
		width:   500
		height:  600
		title:   'Markdown View'
		on_init: fn (mut w gui.Window) {
			w.update_view(main_view)
		}
	)
	window.set_theme(gui.theme_dark_bordered)
	window.run()
}

fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()

	// Custom style with code block background color
	custom_style := gui.MarkdownStyle{
		code_block_bg: gui.rgb(40, 44, 52)
	}

	return gui.column(
		width:     w
		height:    h
		sizing:    gui.fixed_fixed
		padding:   gui.theme().padding_large
		id_focus:  1
		id_scroll: 1
		content:   [
			window.markdown(
				source:      markdown_source
				style:       custom_style
				mode:        .wrap
				color:       gui.theme().color_panel
				size_border: 1
				radius:      gui.theme().radius_medium
				padding:     gui.theme().padding_medium
			),
		]
	)
}
