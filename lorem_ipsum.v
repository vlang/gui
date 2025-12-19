module gui

import rand
import strings

// LoremCfg defines parameters controlling the generated text.
@[params]
pub struct LoremCfg {
pub:
	paragraphs              int = 3
	words_per_sentence      int = 12 // varies ±20%
	sentences_per_paragraph int = 5  // varies ±20%
	commas_per_sentence     int = 2  // varies ±20%
	seed                    int // seed for random generator
}

// lorem_generate generates Lorem Ipsum–style text using the supplied
// configuration. It creates paragraphs with sentences containing random words
// from a predefined Latin word list. The generated text includes varied
// punctuation (commas, semicolons, em-dashes) and sentence endings (periods,
// ellipses) to create natural-looking placeholder text. The
// `words_per_sentence` and `sentences_per_paragraph` parameters are randomly
// varied by ±20% to create natural variation, while `paragraphs` is used
// exactly as specified. The `commas_per_sentence` parameter serves as a
// baseline density that may vary in actual output. [LoremCfg](#LoremCfg)
pub fn lorem_generate(cfg LoremCfg) string {
	lorem_words := (
		'lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor ' +
		'incididunt ut labore et dolore magna aliqua enim ad minim veniam quis nostrud ' +
		'exercitation ullamco laboris nisi aliquip ex ea').split(' ')

	comma_marks := ['‚', ';']
	sentence_marks := ['.', '…', '!', '?']

	if cfg.seed != 0 {
		rand.seed([u32(cfg.seed), u32(cfg.seed ^ 0x9e3779b9)])
	}

	mut out := strings.new_builder(2048)

	for p in 0 .. cfg.paragraphs {
		sentence_count := lorem_vary(cfg.sentences_per_paragraph)

		for _ in 0 .. sentence_count {
			word_count := lorem_vary(cfg.words_per_sentence)

			expected_breaks := match cfg.words_per_sentence > 0 {
				true { (word_count * cfg.commas_per_sentence) / cfg.words_per_sentence }
				else { 0 }
			}
			mut inserted_breaks := 0
			mut last_had_splitter := false
			min_dash_offset := 2

			for wc in 0 .. word_count {
				word := lorem_words[rand.intn(lorem_words.len) or { 0 }]

				if wc == 0 {
					out.write_string(lorem_capitalize(word))
				} else {
					out.write_string(' ')
					out.write_string(word)
				}

				is_last := wc == word_count - 1

				// ---- Clause splitters (comma, semicolon, em-dash)
				if !is_last && inserted_breaks < expected_breaks
					&& (wc + 1) * expected_breaks / word_count > inserted_breaks {
					// Decide splitter strength
					use_strong := rand.intn(6) or { 0 } == 0

					if use_strong {
						// Prefer semicolon; em-dash only if safely away from edges
						match wc >= min_dash_offset && wc < word_count - 1 - min_dash_offset {
							true { out.write_string('—') }
							else { out.write_string(';') }
						}
					} else {
						out.write_string(comma_marks[rand.intn(comma_marks.len) or { 0 }])
					}

					inserted_breaks++
					last_had_splitter = true
					continue
				}

				last_had_splitter = false

				// ---- Sentence terminator (only on last word)
				if is_last {
					match last_had_splitter {
						true {
							out.write_string('.')
						}
						else {
							idx := rand.intn(sentence_marks.len) or { 0 }
							out.write_string(sentence_marks[idx])
						}
					}
				}
			}

			out.write_string(' ')
		}

		if p < cfg.paragraphs - 1 {
			out.write_string('\n\n')
		}
	}

	return out.str()
}

// lorem_vary returns a value randomly varied around a base (±20%, minimum 1).
fn lorem_vary(base int) int {
	if base <= 1 {
		return 1
	}
	delta := base / 5
	r := rand.intn(delta * 2 + 1) or { 0 }
	return lorem_clamp(base + r - delta, 1, 10_000)
}

// lorem_capitalize capitalizes the first character of a word.
fn lorem_capitalize(s string) string {
	if s.len == 0 {
		return s
	}
	return s[..1].to_upper() + s[1..]
}

// lorem_clamp constrains a value between min and max.
fn lorem_clamp(v int, min int, max int) int {
	if v < min {
		return min
	}
	if v > max {
		return max
	}
	return v
}
