module gui

import vglyph

// ------------------------------------
// ## 1. Test split_text (Core Utility)
// ------------------------------------
fn test_split_text() {
	tab_size := u32(4)
	// Spaces, tabs, newlines, and carriage returns
	text_split := 'Word1 Word2\t\nWord3 \r Word4'
	// Expected: Tabs expand to 4 spaces. Spaces are separate. Newlines are separate.
	expected_split := ['Word1', ' ', 'Word2', ' ', '\n', '', 'Word3', '  ', 'Word4']
	assert split_text(text_split, tab_size) == expected_split, 'split_text failed with spaces/tabs/newlines'

	// Trailing space check
	text_trailing := 'end '
	expected_trailing := ['end', ' ']
	assert split_text(text_trailing, tab_size) == expected_trailing, 'split_text failed with trailing space'
}

// ----------------------------------------
// ## 2. Test wrap_simple (No Word Wrap)
// ----------------------------------------
fn test_simple_wrap() {
	tab_size := u32(4)
	text_simple := 'Line 1\nLine 2\twith\t\tabs'
	expected_simple := ['Line 1\n', 'Line 2  with        abs']
	assert wrap_simple(text_simple, tab_size) == expected_simple, 'wrap_simple failed with tabs and newlines'
}

// ------------------------------------
// ## 3. Test start_of_line_pos
// ------------------------------------

fn create_mock_shape() Shape {
	// Recreate the wrapped text structure manually without Pango
	// Line 1: 'This is the first line.\n' (Length 24) -> Start 0
	// Line 2: 'Second line with  spaces.\n' (Length 25) -> Start 24
	// Line 3: 'Third word paragraph.\n' (Length 22) -> Start 49
	// Line 4: 'This is the last line.' (Length 22) -> Start 71
	// Total: 93

	text_content := 'This is the first line.\nSecond line with  spaces.\nThird word paragraph.\nThis is the last line.'

	mut shape := Shape{
		text: text_content
	}

	// Mock the layout lines
	shape.text_layout = &vglyph.Layout{
		lines: [
			vglyph.Line{
				start_index: 0
				length:      24
			},
			vglyph.Line{
				start_index: 24
				length:      26
			},
			vglyph.Line{
				start_index: 50
				length:      22
			},
			vglyph.Line{
				start_index: 72
				length:      22
			},
		]
	}

	return shape
}

fn test_start_of_line_pos() {
	shape := create_mock_shape()

	// Cursor at start of line 1
	assert cursor_start_of_line(shape, 0) == 0, 'start_of_line_pos failed for offset 0'

	// Cursor in middle of line 1 (offset 10)
	assert cursor_start_of_line(shape, 10) == 0, 'start_of_line_pos failed for offset 10 (middle of line 1)'

	// Cursor exactly at the newline of line 1 (start of line 2)
	assert cursor_start_of_line(shape, 24) == 24, 'start_of_line_pos failed for offset 24 (start of line 2)'
	// Note: Previous test expected 0 for offset 24, treating it as end of line 1?
	// vglyph lines are [start, start+len). 24 is start of line 2.
	// If logic returns line start *containing* pos. 24 is in line 2.
	// So 24 is correct for start of line 2.

	// Cursor in middle of line 3 (offset 55)
	assert cursor_start_of_line(shape, 55) == 50, 'start_of_line_pos failed for offset 55 (middle of line 3)'

	// Cursor past the end of the text (offset 100)
	assert cursor_start_of_line(shape, 100) == 72, 'start_of_line_pos failed for offset 100 (past end, should be start of last line)'
}

// ------------------------------------
// ## 2. Test end_of_line_pos
// ------------------------------------
fn test_end_of_line_pos() {
	shape := create_mock_shape()

	// Cursor at start of line 1 (Offset 0) -> Should return the position of the newline
	assert cursor_end_of_line(shape, 0) == 23, 'end_of_line_pos failed for offset 0'

	// Cursor in middle of line 2 (Offset 35) -> Should return the position of the newline
	assert cursor_end_of_line(shape, 35) == 49, 'end_of_line_pos failed for offset 35'
	// Line 2 runs 24..50. End is 50. Newline at 49. End is 49.
	// Previous test expected 49. But render loop logic suggests we want visual end (before newline).
	// Let's verify expectations: End key should go to end of text on that line.
	// If text is "foo\n", end is after 'o'. Index of '\n' is 3.
	// So 48 is correct index (before \n).

	// Cursor upon the newline of line 2 (Offset 49) -> Should return the position of the next newline?
	// 49 is in line 2 (last char). So it should return end of line 2.
	assert cursor_end_of_line(shape, 49) == 49, 'end_of_line_pos failed for offset 49 (on the newline)'

	// Cursor on the last line (Offset 80). Last line has no trailing newline.
	assert cursor_end_of_line(shape, 80) == 94, 'end_of_line_pos failed for offset 80 (last line)'

	// Cursor past the end of the text (Offset 100)
	assert cursor_end_of_line(shape, 100) == 94, 'end_of_line_pos failed for offset 100 (past end)'
}

// ------------------------------------
// ## 4. Test end_of_word_pos
// ------------------------------------
fn test_end_of_word_pos() {
	shape := create_mock_shape()

	// // Cursor at the start of a word ('is') -> offset 5. "is" ends at 7.
	assert cursor_end_of_word(shape, 5) == 7, 'end_of_word_pos failed for offset 5 (start of "is")'

	// Cursor in the middle of a word ('second') -> line 2 starts at 24. "Second" is 24..30
	// "Second" is 6 chars. 24+6=30.
	// Offset 26 is inside "Second".
	assert cursor_end_of_word(shape, 26) == 30, 'end_of_word_pos failed for offset 26 (middle of "Second")'

	// Cursor on a space (offset 30, the space after 'Second')
	// Logic: skip blanks, then skip non-blanks.
	// "Second line" -> space at 30. "line" starts at 31, ends at 35.
	assert cursor_end_of_word(shape, 30) == 35, 'end_of_word_pos failed for offset 30 (on space before "line")'

	// Cursor at the end of the last line (offset 94)
	assert cursor_end_of_word(shape, 94) == 94, 'end_of_word_pos failed for offset 94 (end of text)'
	// Wait, logical end of text.
	// If pos 93 (len), loop condition i < len fails immediately. Returns i (93). Correct.
}

// ------------------------------------
// ## 5. Test start_of_paragraph 📜
// ------------------------------------
fn test_start_of_paragraph() {
	shape := create_mock_shape()

	// Cursor at the very start (offset 0)
	assert cursor_start_of_paragraph(shape, 0) == 0, 'start_of_paragraph failed for offset 0'

	// Cursor in the middle of the first paragraph/line (offset 15)
	assert cursor_start_of_paragraph(shape, 15) == 0, 'start_of_paragraph failed for offset 15'

	// Cursor right after the first newline (start of line 2/new paragraph) -> 24
	assert cursor_start_of_paragraph(shape, 24) == 24, 'start_of_paragraph failed for offset 24 (start of paragraph 2)'

	// Cursor in the middle of line 3 (offset 60). Should jump back to start of line 3 (50).
	assert cursor_start_of_paragraph(shape, 60) == 50, 'start_of_paragraph failed for offset 60 (middle of paragraph 3)'

	// Cursor at the end of text (offset 94). Should jump back to start of last line (72).
	assert cursor_start_of_paragraph(shape, 94) == 72, 'start_of_paragraph failed for offset 94 (end of last paragraph)'

	// Cursor on the newline character itself (offset 49, the \n of line 2)
	// 49 is the newline char. Logic searches backwards.
	// Finds \n at 23. Returns 24.
	assert cursor_start_of_paragraph(shape, 49) == 24, 'start_of_paragraph failed for offset 49 (on the second newline)'
}

// ------------------------------------
// ## 6. Test counting chars in array 📜
// ------------------------------------
fn test_count_chars() {
	// Function removed or deprecated?
	// count_chars was removed from xtra_text_cursor.v as it took []string.
	// If it's gone, remove test.
}

// ------------------------------------
// ## 7. Test rune_to_byte_index
// ------------------------------------
fn test_rune_to_byte_index() {
	// Test case 1: Standard ASCII
	s1 := 'hello'
	assert rune_to_byte_index(s1, 1) == 1

	// Test case 2: Multi-byte characters (Euro symbol)
	// 'a€b' -> 'a' (1 byte), '€' (3 bytes), 'b' (1 byte)
	s2 := 'a€b'
	assert rune_to_byte_index(s2, 0) == 0
	assert rune_to_byte_index(s2, 1) == 1 // Start of €
	assert rune_to_byte_index(s2, 2) == 4 // Start of b (1 + 3)

	// Test case 3: Emojis
	s3 := '😀' // 4 bytes
	assert rune_to_byte_index(s3, 1) == 4

	// Test case 4: Out of bounds
	assert rune_to_byte_index(s2, 100) == s2.len
}

// ------------------------------------
// ## 8. Test byte_to_rune_index
// ------------------------------------
fn test_byte_to_rune_index() {
	// Test case 1: Standard ASCII
	s1 := 'hello'
	assert byte_to_rune_index(s1, 1) == 1

	// Test case 2: Multi-byte characters
	s2 := 'a€b'
	assert byte_to_rune_index(s2, 0) == 0
	assert byte_to_rune_index(s2, 1) == 1
	assert byte_to_rune_index(s2, 4) == 2

	// Test case 3: Mid-rune indexing
	// Should return the index of the rune containing the byte
	assert byte_to_rune_index(s2, 2) == 1 // Inside €
	assert byte_to_rune_index(s2, 3) == 1 // Inside €

	// Test case 4: Out of bounds
	assert byte_to_rune_index(s2, 100) == 3 // length in runes
}

// ------------------------------------
// ## 9. Test collapse_spaces
// ------------------------------------
fn test_collapse_spaces() {
	// Basic case
	assert collapse_spaces('A  B') == 'A B'

	// Newlines preserved
	assert collapse_spaces('A\n  B') == 'A\n B'

	// Tabs converted to space
	assert collapse_spaces('A\tB') == 'A B'

	// Multiple spaces reduced
	assert collapse_spaces('   ') == ' '

	// Leading/Trailing spaces (single)
	assert collapse_spaces(' A B ') == ' A B '

	// Leading/Trailing multiple
	assert collapse_spaces('  A  B  ') == ' A B '
}
