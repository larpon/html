// Copyright(C) 2019-2021 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module html

import os

pub fn parse_file(path string) {
	mut p := html.new_parser()
	parse(mut p, path)
}

pub fn parse(mut p Parser, path string) {
	if path == '' {
		panic(@MOD + '.' + @STRUCT + '.' + @FN + '`path` is empty')
	}

	file_size := os.file_size(path)
	if file_size == 0 {
		panic(@MOD + '.' + @STRUCT + '.' + @FN + '"${path}" is 0 in size')
	}

	p.reset()

	s := os.read_file(path) or { panic(err) }

	p.parse_string(s)

	/*
	// TODO once rune is ready - allow for parsing in rune chunks
	mut f := os.open_file(path, 'r') or { panic(err) }
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
