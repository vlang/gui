module gui

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

fn wrapped_text_tests() []string {
	// The text simulates the output of a wrapping function.
	// Newlines are included as the last character of a line string.
	return [
		'This is the first line.\n', // Length: 24 (23 + 1)
		'Second line with  spaces.\n', // Length: 25 (24 + 1)
		'Third word paragraph.\n', // Length: 22 (21 + 1)
		'This is the last line.', // Length: 22
	]

	// Total character length: 24 + 25 + 22 + 22 = 93
	// Line 1 ends at offset 24
	// Line 2 ends at offset 49
	// Line 3 ends at offset 71
	// Line 4 ends at offset 93
}

// ------------------------------------
// ## 3. Test start_of_line_pos
// ------------------------------------
fn test_start_of_line_pos() {
	wrapped_text := wrapped_text_tests()

	// Cursor at start of line 1
	assert cursor_start_of_line(wrapped_text, 0) == 0, 'start_of_line_pos failed for offset 0'

	// Cursor in middle of line 1 (offset 10)
	assert cursor_start_of_line(wrapped_text, 10) == 0, 'start_of_line_pos failed for offset 10 (middle of line 1)'

	// Cursor exactly at the newline of line 1 (start of line 2)
	assert cursor_start_of_line(wrapped_text, 24) == 0, 'start_of_line_pos failed for offset 0 (start of line 2)'

	// Cursor in middle of line 3 (offset 55)
	assert cursor_start_of_line(wrapped_text, 55) == 50, 'start_of_line_pos failed for offset 55 (middle of line 3)'

	// Cursor past the end of the text (offset 100)
	assert cursor_start_of_line(wrapped_text, 100) == 94, 'start_of_line_pos failed for offset 100 (past end)'
}

// ------------------------------------
// ## 2. Test end_of_line_pos
// ------------------------------------
fn test_end_of_line_pos() {
	wrapped_text := wrapped_text_tests()

	// Cursor at start of line 1 (Offset 0) -> Should return the position of the newline
	assert cursor_end_of_line(wrapped_text, 0) == 23, 'end_of_line_pos failed for offset 0'

	// Cursor in middle of line 2 (Offset 35) -> Should return the position of the newline
	assert cursor_end_of_line(wrapped_text, 35) == 49, 'end_of_line_pos failed for offset 35'

	// Cursor on the newline of line 2 (Offset 48) -> Should return the position of the next newline
	assert cursor_end_of_line(wrapped_text, 48) == 49, 'end_of_line_pos failed for offset 48 (on the newline)'

	// Cursor on the last line (Offset 80). Last line has no trailing newline.
	assert cursor_end_of_line(wrapped_text, 80) == 94, 'end_of_line_pos failed for offset 80 (last line)'

	// Cursor past the end of the text (Offset 100)
	assert cursor_end_of_line(wrapped_text, 100) == 94, 'end_of_line_pos failed for offset 100 (past end)'
}

// ------------------------------------
// ## 4. Test end_of_word_pos
// ------------------------------------
fn test_end_of_word_pos() {
	wrapped_text := wrapped_text_tests()

	// // Cursor at the start of a word ('is')
	assert cursor_end_of_word(wrapped_text, 5) == 7, 'end_of_word_pos failed for offset 5 (start of "is")'

	// Cursor in the middle of a word ('second')
	assert cursor_end_of_word(wrapped_text, 26) == 30, 'end_of_word_pos failed for offset 26 (middle of "Second")'

	// Cursor on a space (offset 30, the space after 'Second')
	assert cursor_end_of_word(wrapped_text, 30) == 35, 'end_of_word_pos failed for offset 30 (on space before "line")'

	// Cursor at the end of the last line (offset 93)
	assert cursor_end_of_word(wrapped_text, 93) == 94, 'end_of_word_pos failed for offset 93 (end of text)'
}

// ------------------------------------
// ## 5. Test start_of_paragraph 📜
// ------------------------------------
fn test_start_of_paragraph() {
	wrapped_text := wrapped_text_tests()

	// Cursor at the very start (offset 0)
	assert cursor_start_of_paragraph(wrapped_text, 0) == 0, 'start_of_paragraph failed for offset 0'

	// Cursor in the middle of the first paragraph/line (offset 15)
	assert cursor_start_of_paragraph(wrapped_text, 15) == 0, 'start_of_paragraph failed for offset 15'

	// Cursor right after the first newline (start of line 2/new paragraph)
	assert cursor_start_of_paragraph(wrapped_text, 24) == 0, 'start_of_paragraph failed for offset 24 (start of paragraph 2)'

	// Cursor in the middle of line 3 (offset 60). Should jump back to start of line 3 (49).
	assert cursor_start_of_paragraph(wrapped_text, 60) == 25, 'start_of_paragraph failed for offset 60 (middle of paragraph 3)'

	// Cursor at the end of text (offset 93). Should jump back to start of last line (71).
	assert cursor_start_of_paragraph(wrapped_text, 93) == 45, 'start_of_paragraph failed for offset 93 (end of last paragraph)'

	// Cursor on the newline character itself (offset 48, the \n of line 2)
	assert cursor_start_of_paragraph(wrapped_text, 48) == 0, 'start_of_paragraph failed for offset 48 (on the second newline)'
}

// ------------------------------------
// ## 6. Test counting chars in array 📜
// ------------------------------------
fn test_count_chars() {
	// Test empty array
	assert count_chars([]) == 0

	// Test single empty string
	assert count_chars(['']) == 0

	// Test single string with ASCII characters
	assert count_chars(['hello']) == 5

	// Test multiple strings
	assert count_chars(['hello', 'world']) == 10

	// Test strings with spaces
	assert count_chars(['hello ', 'world']) == 11

	// Test strings with newlines
	assert count_chars(['hello\n', 'world']) == 11

	// Test strings with tabs
	assert count_chars(['hello\t', 'world']) == 11

	// Test strings with UTF-8 characters
	assert count_chars(['café']) == 4
	assert count_chars(['hello', 'wörld']) == 10

	// Test mixed content
	assert count_chars(['', 'test', '', 'data']) == 8
}
