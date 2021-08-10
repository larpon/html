// Copyright(C) 2019-2021 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module tokenizer

import debug
import token
import regex

pub const (
	whitespaces = ['\t', '\n', '\r', '\f', ' ']
)

pub enum State {
	initialized
	ready
	error
	feeding
	done
}

enum CDATAMode {
	off
	text
	cdata
	data1
	data2
	data3
}

pub struct Tokenizer {
mut:
	buffer      string //[]byte
	consumed    string
	regex_cache RegexCache = RegexCache{}
	// buffer_pos	int
	//
	pos      int
	line     int
	line_pos int
	//
	queue []token.Token
	state State = .initialized
	//
	in_string bool
	value     string
	//
	in_cdata   bool
	cdata      string
	cdata_mode CDATAMode
}

struct RegexCache {
mut:
	tag_script_start regex.RE = todo_workaround_11119(r'^script.*>') // regex.regex_opt(r'^script.*>') or { panic(err) }
	tag_style_start  regex.RE = todo_workaround_11119(r'^style.*>')
	comment          regex.RE = todo_workaround_11119(r'^!--.*-->')
	tag_any_end      regex.RE = todo_workaround_11119(r'^/.*>')
}

// TODO workaround https://github.com/vlang/v/issues/11119
fn todo_workaround_11119(rex string) regex.RE {
	return regex.regex_opt(rex) or { panic(err) }
}

pub fn (mut rc RegexCache) reset() {
	rc.tag_script_start = regex.regex_opt(r'^script.*>') or { panic(err) }
	rc.tag_style_start = regex.regex_opt(r'^style.*>') or { panic(err) }
	rc.comment = regex.regex_opt(r'^!--.*-->') or { panic(err) }
	rc.tag_any_end = regex.regex_opt(r'^/.*>') or { panic(err) }
}

pub fn (mut t Tokenizer) reset() {
	t.regex_cache.reset()

	t.buffer = ''
	t.consumed = ''
	t.pos = 0
	t.line = 1
	t.line_pos = 1
	t.queue = []token.Token{}
	t.state = .initialized
	t.in_string = false
	t.value = ''
	//
	t.reset_cdata()
}

fn (mut t Tokenizer) reset_cdata() {
	t.in_cdata = false
	t.cdata = ''
	t.cdata_mode = .text
}

fn (mut t Tokenizer) new_cdata_mode(mode CDATAMode) {
	t.cdata = ''
	t.cdata_mode = mode
	t.in_cdata = true
	if mode == .off {
		t.in_cdata = false
	}
	// eprintln(@MOD+' CDATA mode ${t.cdata_mode}')
}

[inline]
fn matches(input string, mut re regex.RE) bool {
	if input.len == 0 {
		return false
	}
	// mut re := regex.regex_opt(regx) or { panic(err) }
	start, _ := re.match_string(input)
	return start >= 0
}

[inline]
fn tmp_matches(input string, regx string) bool {
	mut re := regex.regex_opt(regx) or { panic(err) }
	start, _ := re.match_string(input)
	return start >= 0
}

[inline]
fn preprocess(input string) string {
	if input.len == 0 {
		return input
	}
	mut s := input // bytes.bytestr()
	s = s.replace('\r\n', '\n')
	// s = s.replace('< ', '<')
	// s = s.replace(' >', '>')

	/*
	This will truncate whitespace from many to one.
	mut new := []byte{}
	mut prev := '0'
	for b in s {
		if b.hex() == '20' && b.hex() == prev  {
			continue
		}
		prev = b.hex()
		new << b
	}
	s = new.bytestr()
	*/
	return s //.bytes()
}

[inline]
pub fn (mut t Tokenizer) queued() int {
	return t.queue.len
}

[inline]
pub fn (mut t Tokenizer) pop() token.Token {
	tok := t.queue.first()
	t.queue.delete(0)
	return tok
}

[inline]
pub fn (mut t Tokenizer) token_at(index int) token.Token {
	return t.queue[index]
}

pub fn (mut t Tokenizer) end() {
	t.state = .done
	// TODO
	t.queue << t.new_token(.eof, '')
}

[inline]
fn (mut t Tokenizer) new_token(kind token.Kind, lit string) token.Token {
	/*
	mut pretty := lit
	if lit in ['\t','\n','\r','\f'] {
		pretty = r'\n'
	}
	eprintln('New token: $kind "$pretty"')*/

	return token.Token{
		kind: kind
		lit: lit
		line: t.line
		pos: t.line_pos
	}
}

[inline]
pub fn (mut t Tokenizer) feed(input string) {
	if t.state !in [.ready, .initialized] {
		panic(@MOD + '.' + @STRUCT + '.' + @FN +
			' parser not in "ready" state, but "$t.state". Maybe parsing has ended? Call reset() to reuse the tokenizer.')
	}
	t.state = .feeding

	if input.len > 0 {
		t.buffer += preprocess(input)
	}
	// eprintln('Buffering "${t.buffer}" from "${input}"')
	last_chunk := input.len == 0 // TODO

	mut skip := 0
	mut b := byte(0)
	mut c := ''

	//$if debug { mut skip_buf := '' }

	for t.buffer.len > 0 {
		b = t.buffer[0]
		t.buffer = t.buffer[1..t.buffer.len]

		c = b.ascii_str()

		/*
		if last_chunk {
			eprintln('last_chunk: "$c"')
		}*/

		// TODO tracking of token positions from input is broken
		// can only be done if input is *not* run through preprocess()
		t.line_pos++
		if c == '\n' {
			t.line++
			t.line_pos = 1
		}

		if skip > 0 {
			skip--

			// eprintln('Skipping: "$c"')
			/*$if debug {
				skip_buf += c
				if skip == 0 {
					eprintln('Skipping: "${skip_buf}"')
					skip_buf = ''
				}
			}*/

			continue
		}
		// eprintln('Char: "${c}" buffer (${t.buffer.len}):  "${t.buffer}"')
		// eprintln('Char: "${c}" in buffer (${t.buffer.len})')
		if t.in_cdata {
			if c != '<' && !t.buffer.contains('<') && !t.buffer.contains('-->') {
				raw := c + t.buffer
				t.cdata = t.cdata + raw
				t.line += raw.count('\n')
				t.line_pos += raw.all_after_last('\n').len
				t.buffer = ''
				// eprintln(@MOD+' await data ($c) (CDATA BIG) Remaining: ${t.buffer} (${t.buffer.len})')
				break
			}

			if t.cdata_mode == .text {
				if c == '<' {
					if t.cdata.len > 0 {
						t.queue << t.new_token(.cdata, t.cdata)
					}
					t.new_cdata_mode(.off)
				} else {
					t.cdata += c
					continue
				}
			} else {
				// TODO
				// https://stackoverflow.com/a/14608300/1904615
				if c == '<' {
					if t.buffer.len < 9 {
						t.buffer = c + t.buffer
						// eprintln(@MOD+' await data ($c) (CDATA) Remaining: ${t.buffer} (${t.buffer.len})')
						break
					}
					peek := c + t.buffer[..t.buffer.len]
					// eprintln('CDATA peek: ${peek} data: ${t.cdata}')
					if peek.starts_with('<!--') {
						t.cdata_mode = .data2
					}

					if peek.starts_with('</script>') || peek.starts_with('</style>') {
						if t.cdata.len > 0 {
							t.queue << t.new_token(.cdata, t.cdata)
						}
						mut tag := '</script>'
						if peek.starts_with('</style>') {
							tag = '</style>'
						}
						t.queue << t.new_token(.tag_end, tag)
						t.new_cdata_mode(.text)
						skip = tag.len - 1
						continue
					}
				}
				if c == '-' {
					if t.buffer.len < 3 {
						t.buffer = c + t.buffer
						// eprintln(@MOD+' await data ($c) (CDATA) Remaining: ${t.buffer} (${t.buffer.len})')
						break
					}
					peek := c + t.buffer[..t.buffer.len]
					// eprintln('CDATA peek: ${peek} data: ${t.cdata}')
					if peek.starts_with('-->') {
						t.cdata_mode = .data1
					}
				}
				t.cdata += c
				// eprintln(@MOD+' (CDATA) Collecting: ${c} ${t.cdata.len} ${t.line}')
				continue
			}
		}

		if c == '<' {
			if !t.buffer[0..].contains('>') {
				t.buffer = c + t.buffer
				// eprintln(@MOD+' await data ($c) '(OPEN <) Remaining: ${t.buffer}')
				if last_chunk {
					eprintln(@MOD + '.' + @STRUCT + '.' + @FN +
						' warning skipping unclosed tag. Missing ">"')
				}
				break
			}

			peek := t.buffer[0..].all_before('>') + '>'
			// eprintln(@MOD + '.' + @STRUCT + '.' + @FN+' Peek ($c): "${peek}"')

			if peek.starts_with('!DOCTYPE') {
				t.queue << t.new_token(.doctype, c + peek)
				t.new_cdata_mode(.text)
				skip = peek.len
				continue
			}

			// r'^script.*>' r'^style.*>'
			// if tmp_matches(peek, r'^script.*>') || tmp_matches(peek, r'^style.*>') {
			if matches(peek, mut t.regex_cache.tag_script_start)
				|| matches(peek, mut t.regex_cache.tag_style_start) {
				t.queue << t.new_token(.tag_start, c + peek)

				t.new_cdata_mode(.data1)
				skip = peek.len
				continue
			}
			// HTML comment r'^!--.*-->'
			// if tmp_matches(peek, r'^!--.*-->') {
			if matches(peek, mut t.regex_cache.comment) {
				t.queue << t.new_token(.comment, c + peek)
				t.new_cdata_mode(.text)
				skip = peek.len
				continue
			}
			// Any self-closing tag r'^/.*>'
			// if tmp_matches(peek, r'^/.*>') {
			if matches(peek, mut t.regex_cache.tag_any_end) {
				t.queue << t.new_token(.tag_end, c + peek)
				t.new_cdata_mode(.text)
				skip = peek.len
				continue
			}

			t.queue << t.new_token(.tag_start, c + peek)

			t.new_cdata_mode(.text)
			skip = peek.len
		} else {
			// eprintln('Leaving: ---\n'+t.buffer+'\n---')
			// panic('Cannot parse "'+c+'" in ...'+t.buffer+'...')
			// if pos +1 < t.buffer.len

			if last_chunk {
				ll := t.line + 1
				lpos := t.line_pos + 1
				panic(@MOD + '.' + @STRUCT + '.' + @FN +
					' Cannot parse $ll:$lpos: "$c" in ... "$t.buffer"')
			} else {
				t.buffer = c + t.buffer
				debug.info(@MOD + '.' + @STRUCT + '.' + @FN, 'awaiting data ($c) (END) Remaining: $t.buffer')
			}
			break
		}
	}
	if last_chunk && t.buffer.len > 0 {
		panic(@MOD + '.' + @STRUCT + '.' + @FN + ' remaining data was ignored "$t.buffer"')
	}
	t.state = .ready
}
