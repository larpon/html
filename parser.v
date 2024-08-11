// Copyright(C) 2019-2021 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module html

import debug
import token
import tokenizer

const default_chunk_size = 512

pub const void_html4 = ['area', 'base', 'br', 'col', 'hr', 'img', 'input', 'link', 'meta', 'param']
pub const void_xhtml = void_html4
pub const void_html5 = ['area', 'base', 'br', 'col', 'hr', 'img', 'input', 'link', 'meta', 'param',
	'source', 'command', 'keygen'] // command [obsolete]
// keygen [deprecated]

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
	mut chunk_size := html.default_chunk_size
	mut s := ''
	mut pos := 0
	for chunks_left > 0 {
		s = ''
		if chunk_size > chunks_left {
			chunk_size = chunks_left
		}
		debug.info(@MOD + '.' + @STRUCT + '.' + @FN, 'input slice from ${pos} to ${pos + chunk_size} (${chunk_size}). Left: ${chunks_left} Total: ${input.len}')
		s = input[pos..pos + chunk_size]
		pos += chunk_size

		debug.info(@MOD + '.' + @STRUCT + '.' + @FN, 'feeding tokenizer: ${s}')
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

pub fn (mut p Parser) raw() string {
	mut htm := ''
	for i in 0 .. p.tnzr.queued() {
		tok := p.tnzr.token_at(i)
		htm += '${tok.lit}'
	}
	return htm
}

pub fn (mut p Parser) dmp() {
	for p.tnzr.queued() > 0 {
		tok := p.tnzr.pop()
		eprintln('${tok}')
	}
}
