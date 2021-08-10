// Copyright(C) 2019-2021 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module html

import debug
import token
import tokenizer

const (
	default_chunk_size = 512
)

const (
	void_html4 = ['area', 'base', 'br', 'col', 'hr', 'img', 'input', 'link', 'meta', 'param']
	void_xhtml = void_html4
	void_html5 = ['area', 'base', 'br', 'col', 'hr', 'img', 'input', 'link', 'meta', 'param',
		'source', 'command', 'keygen']
		// command [obsolete]
		// keygen [deprecated]
)

pub fn new_parser() &Parser {
	mut parser := &Parser{}
	parser.reset()
	return parser
}

pub struct Parser {
mut:
	tnzr tokenizer.Tokenizer
}

pub fn (mut p Parser) reset() {
	p.tnzr.reset()
}

pub fn (mut p Parser) parse_bytes(bytes []byte) {
	p.parse_string(bytes.bytestr())
}

pub fn (mut p Parser) parse_string(input string) {
	mut chunks_left := input.len
	mut chunk_size := default_chunk_size
	mut s := ''
	mut pos := 0
	for chunks_left > 0 {
		s = ''
		if chunk_size > chunks_left {
			chunk_size = chunks_left
		}
		debug.info(@MOD + '.' + @STRUCT + '.' + @FN, 'input slice from $pos to ${pos + chunk_size} ($chunk_size). Left: $chunks_left Total: $input.len')
		s = input[pos..pos + chunk_size]
		pos += chunk_size

		debug.info(@MOD + '.' + @STRUCT + '.' + @FN, 'feeding tokenizer: $s')
		p.tnzr.feed(s)

		chunks_left -= chunk_size
	}
}

pub fn (mut p Parser) end() {
	p.tnzr.end()
}

pub fn (mut p Parser) tokens() []token.Token {
	mut tokens := []token.Token{}
	for i in 0 .. p.tnzr.queued() {
		tokens << p.tnzr.token_at(i)
	}
	return tokens
}

pub fn (mut p Parser) raw_pretty() string {
	mut indent := 0
	mut indt := ''
	mut html := ''
	for i in 0 .. p.tnzr.queued() {
		tok := p.tnzr.token_at(i)

		indt = ''
		for _ in 0 .. indent {
			indt += '\t'
		}

		if tok.kind == .tag_start {
			indent++
			if tok.lit.ends_with('/>') {
				indent--
			} else if tok.kind == .comment {
				indent--
			} else {
				name := tok.lit.to_lower().all_before(' ').trim_left('<')
				if name in void_html5 {
					indent--
				}
			}
		}

		if tok.kind == .cdata {
			mut cdata := tok.lit.trim('\n')
			cdata = cdata.trim_space()
			cdata = cdata.trim('\t')
			if cdata.len > 0 {
				if cdata.len <= default_chunk_size {
					cdata_lines := cdata.split('\n')
					mut trimmed := ''
					for cdata_line in cdata_lines {
						trimmed = cdata_line //.trim_left(' ')
						html += '$indt$trimmed\n'
					}
				} else {
					// TODO Can currently be a very slow and memory expensive operation.
					// ... Especially in debug builds
					html += '$indt$cdata\n'
				}
			}
		} else {
			if tok.kind == .tag_end {
				indent--
				name := tok.lit.to_lower().all_before(' ').trim_left('<')
				if name in void_html5 && tok.lit.to_lower().starts_with('</') {
					indent++
				}
				indt = indt.all_after('\t')
			}
			html += '$indt$tok.lit.to_lower()\n'
		}
	}
	return html
}

pub fn (mut p Parser) raw() string {
	mut html := ''
	for i in 0 .. p.tnzr.queued() {
		tok := p.tnzr.token_at(i)
		html += '$tok.lit'
	}
	return html
}

pub fn (mut p Parser) dmp() {
	for p.tnzr.queued() > 0 {
		tok := p.tnzr.pop()
		eprintln('$tok')
	}
}
