module gui

import rand

// ---------------- Embedded Corpora ----------------

const lorem_corpora = {
	'lorem':  lorem_corpus
	'poe':    poe_corpus
	'darwin': darwin_corpus
	'bard':   shakespeare_corpus
}

const lorem_corpus = '
lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua Ut enim ad minim veniam quis
nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat
Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore
eu fugiat nulla pariatur Excepteur sint occaecat cupidatat non proident sunt
in culpa qui officia deserunt mollit anim id est laborum
'

const poe_corpus = '
once upon a midnight dreary while I pondered weak and weary
over many a quaint and curious volume of forgotten lore
while I nodded nearly napping suddenly there came a tapping
as of someone gently rapping at my chamber door
'

const darwin_corpus = '
when we look to the individuals of the same variety or sub variety of our
older cultivated plants and animals one of the first points which strikes
us is that they generally differ much more from each other than do the
individuals of any one species or variety in a state of nature
'

const shakespeare_corpus = '
to be or not to be that is the question
all the worlds a stage and all the men and women merely players
the lady doth protest too much methinks
a rose by any other name would smell as sweet
et tu brute
if music be the food of love play on
now is the winter of our discontent
we are such stuff as dreams are made on
brevity is the soul of wit
some are born great some achieve greatness and some have greatness thrust upon them
cry havoc and let slip the dogs of war
all that glisters is not gold
the fault dear brutus is not in our stars but in ourselves
to thine own self be true
lord what fools these mortals be
shall i compare thee to a summers day
'

// ---------------- Seed Phrases ----------------

const lorem_seed_phrases = [
	'in the beginning',
	'once upon a time',
	'it was the first',
	'when we consider',
	'there was a moment',
]

// ---------------- Text Generation ----------------

// LoremCfg
// - `corpus_name` random if not specified
// - `seed_text`   random if not specified
// - `rng_seed`    random if not specified
@[params]
pub struct LoremCfg {
pub:
	words_per_sentence      int = 10
	sentences_per_paragraph int = 5
	paragraphs              int = 3
	markov_order            int = 2
	corpus_name             string
	seed_text               string
	rng_seed                int
}

// lorem_generate - pseudo-random text using a Markov chain built from
// one of several embedded corpora. It produces structured output in the
// form of paragraphs and sentences, with configurable parameters for:
//
// - Markov order (n-gram size)
// - Words per sentence
// - Sentences per paragraph
// - Paragraph count
// - Optional seed phrases and RNG seed
// - Optional corpus selection
//
pub fn lorem_generate(cfg LoremCfg) string {
	if cfg.rng_seed != 0 {
		rand.seed([u32(cfg.rng_seed)])
	}

	seed := match cfg.seed_text != '' {
		true { cfg.seed_text }
		else { lorem_random_seed_phrase() }
	}

	corpus := lorem_select_corpus(cfg.corpus_name)
	tokens := lorem_tokenize(corpus)

	if tokens.len <= cfg.markov_order {
		eprintln('corpus too small for selected order')
		return ''
	}

	model := lorem_build_markov(tokens, cfg.markov_order)

	mut state := lorem_tokenize(seed)
	if state.len < cfg.markov_order {
		start := rand.intn(tokens.len - cfg.markov_order) or { 0 }
		state = tokens[start..start + cfg.markov_order].clone()
	}

	mut out := []string{}

	for pi in 0 .. cfg.paragraphs {
		if pi != 0 {
			out << '\n\n'
		}
		sentences := lorem_vary(cfg.sentences_per_paragraph, 1)

		for si in 0 .. sentences {
			if si != 0 {
				out << ' '
			}
			words := lorem_vary(cfg.words_per_sentence, 3)
			mut sentence := []string{}

			for _ in 0 .. words {
				key := state.join('\u0001')
				nexts := model[key] or {
					start := rand.intn(tokens.len - cfg.markov_order) or { 0 }
					state = tokens[start..start + cfg.markov_order].clone()
					continue
				}

				next := nexts[rand.intn(nexts.len) or { 0 }]
				sentence << next

				state = state[1..].clone()
				state << next
			}

			if sentence.len > 0 {
				out << sentence.join(' ').capitalize()
				out << '.'
			}
		}
	}

	return out.join('')
}

// ---------------- Utilities ----------------

fn lorem_vary(base int, min int) int {
	delta := int(f32(base) * 0.2)
	if delta == 0 {
		return base
	}
	offset := rand.intn(delta * 2 + 1) or { 0 } - delta
	val := base + offset
	return if val < min { min } else { val }
}

fn lorem_select_corpus(name string) string {
	if name != '' {
		if corpus := lorem_corpora[name] {
			return corpus
		}
		eprintln('unknown corpus: ${name}')
		exit(1)
	}

	keys := lorem_corpora.keys()
	key := keys[rand.intn(keys.len) or { 0 }]
	return lorem_corpora[key]
}

fn lorem_random_seed_phrase() string {
	return lorem_seed_phrases[rand.intn(lorem_seed_phrases.len) or { 0 }]
}

fn lorem_tokenize(text string) []string {
	return text
		.replace_each(['\n', ' ', '\t', ' '])
		.split(' ')
		.filter(it.len > 0)
}

fn lorem_build_markov(tokens []string, order int) map[string][]string {
	mut model := map[string][]string{}
	for i in 0 .. tokens.len - order {
		key := tokens[i..i + order].join('\u0001')
		model[key] << tokens[i + order]
	}
	return model
}
