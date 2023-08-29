// Copyright(C) 2019-2021 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module html

import os
import token

pub fn parse_file(path string) []token.Token {
	mut p := new_parser()
	parse(mut p, path)
	return p.tokens()
}

pub fn parse(mut p Parser, input string) {
	if input == '' {
		panic(@MOD + '.' + @STRUCT + '.' + @FN + '`input` is empty')
	}

	mut s := ''

	if os.is_file(input) {
		file_size := os.file_size(input)
		if file_size == 0 {
			panic(@MOD + '.' + @STRUCT + '.' + @FN + '"${input}" is 0 in size')
		}
		s = os.read_file(input) or { panic(err) }
	} else {
		s = input
	}

	p.reset()

	p.parse_string(s)

	/*
	// TODO once rune is ready - allow for parsing in rune chunks
	mut f := os.open_file(input, 'r') or { panic(err) }
	mut chunks_left := fs
	mut chunk_size := 4*1024

	mut ba := []byte{}

	mut pos := 0
	for chunks_left > 0 {
		ba.clear()
		if chunk_size > chunks_left {
			chunk_size = chunks_left
		}
		ba = f.read_bytes_at(chunk_size, pos)
		pos += chunk_size

		p.parse_bytes(ba)

		chunks_left -= chunk_size
		//println('Read: '+chunk_size.str()+' Left: '+chunks_left.str()+'Pos: '+pos.str())
	}
	f.close()
	*/

	p.end()
}

pub fn parse_string(mut p Parser, html_input string) {
	if html_input == '' {
		panic(@MOD + '.' + @STRUCT + '.' + @FN + '`html_input` is empty')
	}
	p.reset()
	p.parse_string(html_input)
	p.end()
}

pub fn beautify(html_string string) string {
	mut p := new_parser()
	parse_string(mut p, html_string)

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
						html += '${indt}${trimmed}\n'
					}
				} else {
					// TODO Can currently be a very slow and memory expensive operation.
					// ... Especially in debug builds
					html += '${indt}${cdata}\n'
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
			html += '${indt}${tok.lit.to_lower()}\n'
		}
	}
	return html.trim('\n') + '\n'
}
