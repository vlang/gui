Markdown Parser Upgrade Plan

Goal

Upgrade parser to handle all features in examples/markdown.v without faulting.
Phases 1-3 fully implemented; rest as placeholders.

Decisions

- Tables: Render as monospace text block
- Bold+italic: Bold font + italic flag (synthetic)
- Scope: Phases 1-3 full, Phases 4-6 placeholder only

Critical Files

- xtra_markdown.v - Core parser (block + inline parsing)
- view_markdown.v - MarkdownStyle struct, block rendering
- _markdown_test.v - Existing tests, add new test cases

Phase 1: Defensive Parsing (No Crashes)

1.1 Escape Characters (\*literal\*)

- parse_inline(): Check for \ at start of loop, skip next char and add literally

1.2 Reference Link Defense ([text][ref])

- parse_inline(): After finding ], if next char not (, treat as literal text

1.3 Footnote Defense ([^1])

- parse_inline(): If [ followed by ^, skip link parsing, render as literal

1.4 Abbreviation Defense (*[ABBR]:)

- markdown_to_blocks(): Detect *[ at line start, treat as metadata (skip/ignore for now)

1.5 Table Recognition

- markdown_to_blocks(): Detect lines with |, treat as preformatted/code for now

1.6 Definition List Recognition (: Definition)

- markdown_to_blocks(): Detect : at line start, treat as regular paragraph for now

Phase 2: Inline Formatting Extensions

2.1 Underscore Italic/Bold (_text_, __text__)

- parse_inline(): Add handlers mirroring * patterns

2.2 Bold+Italic (***text***)

- parse_inline(): Check triple *** before double **
- Style: Use bold weight + italic flag (synthetic italic on bold font)

Phase 3: Block Enhancements

3.1 Nested Blockquotes (> > text)

- markdown_to_blocks(): Count > depth, store in block
- Add blockquote_depth int to MarkdownBlock
- View: Increase left margin per depth

3.2 Multi-Paragraph Blockquotes

- markdown_to_blocks(): Don't break on blank > lines within quote

3.3 Autolinks (<https://url>)

- parse_inline(): Detect <url> or <email> pattern, create link run

Phase 4: Tables (Placeholder Only)

- Add is_table bool to MarkdownBlock
- Detect table lines (start with | or separator row |---|)
- Collect raw lines, render as monospace text block

Phase 5: Reference Features (Future)

- Reference links: Two-pass parsing with definitions map
- Footnotes: Collect definitions, render markers inline
- Abbreviations: Collect definitions, apply as text expansion

Phase 6: Definition Lists (Future)

- Detect term + : Definition pattern
- Render with indented definitions under bold terms

Verification

1. Run v test _markdown_test.v after each phase
2. Run v run examples/markdown.v to visually verify
3. Add new tests for each feature
